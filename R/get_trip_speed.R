#' Get trip speed
#'
#' Returns the average speed of each specified `trip_id`, either from the first
#' to the last stop of the trip or between each pair of consecutive stops.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#'   speeds calculated. If `NULL` (the default), the function calculates the
#'   speed of every `trip_id` in the GTFS.
#' @template method
#' @param by A string, either `"trip"` (the default) or `"segment"`. `"trip"`
#'   returns the average speed from the first to the last stop of each trip,
#'   while `"segment"` returns the average speed between each pair of
#'   consecutive stops.
#' @param unit A string representing the unit in which the speeds are desired.
#'   Either `"km/h"` (the default) or `"m/s"`.
#' @param sort_sequence A logical specifying whether to sort timetables and
#'   shapes by `stop_sequence` and `shape_pt_sequence`, respectively. Defaults
#'   to `TRUE`. Set to `FALSE` only if these tables are known to be ordered.
#' @param file Deprecated. Use `method` instead (`file = "stop_times"`
#'   corresponds to `method = "euclidean"`).
#'
#' @return With `by = "trip"`, a `data.table` with the `trip_id` and the
#'   average `speed` of each trip. With `by = "segment"`, a `data.table` with
#'   the `trip_id`, the `segment` number, the `from_stop_id` and `to_stop_id`
#'   that delimit the segment and its average `speed`.
#'
#' @section Details:
#' The speed is the length calculated by [get_trip_length()] divided by the
#' duration calculated by [get_trip_duration()] (with `by = "trip"`) or by
#' [get_trip_segment_duration()] (with `by = "segment"`). Speeds are `NA` when
#' the length is `NA` (e.g. trips not linked to a shape) or when the duration
#' is missing (e.g. blank times at intermediate stops) or not positive.
#'
#' Existing `_secs` columns in `stop_times` (e.g. created with
#' [convert_time_to_seconds()]) are used as-is, not recalculated from the time
#' strings.
#'
#' @seealso [get_trip_length()], [get_trip_duration()],
#'   [get_trip_segment_duration()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#'
#' gtfs <- read_gtfs(data_path)
#'
#' trip_speed <- get_trip_speed(gtfs)
#' head(trip_speed)
#'
#' trip_ids <- c("CPTM L07-0", "2002-10-0")
#' trip_speed <- get_trip_speed(gtfs, trip_ids)
#' trip_speed
#'
#' trip_speed <- get_trip_speed(gtfs, trip_ids, method = "euclidean")
#' trip_speed
#'
#' trip_speed <- get_trip_speed(gtfs, trip_ids, unit = "m/s")
#' trip_speed
#'
#' segment_speed <- get_trip_speed(gtfs, "CPTM L07-0", by = "segment")
#' head(segment_speed)
#'
#' @export
get_trip_speed <- function(gtfs,
                           trip_id = NULL,
                           method = "shapes",
                           by = "trip",
                           unit = "km/h",
                           sort_sequence = TRUE,
                           file = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(by),
    checkmate::check_names(by, subset.of = c("trip", "segment")),
    combine = "and"
  )
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = c("km/h", "m/s")),
    combine = "and"
  )
  checkmate::assert_logical(sort_sequence, any.missing = FALSE, len = 1)

  # check the fields required to calculate durations before calculating
  # lengths, so errors are not thrown very late

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time"),
    rep("character", 3)
  )

  length_unit <- ifelse(unit == "km/h", "km", "m")
  duration_unit <- ifelse(unit == "km/h", "h", "s")

  if (!is.null(file)) method <- map_deprecated_file(file, "get_trip_speed")

  lengths <- get_trip_length(
    gtfs,
    trip_id,
    method,
    by,
    length_unit,
    sort_sequence
  )

  if (nrow(lengths) == 0) {
    data.table::setnames(lengths, "length", "speed")
    return(lengths[])
  }

  # durations are calculated only for the trips whose lengths were calculated,
  # so a warning about a trip_id that doesn't exist is raised only once (by
  # get_trip_length())

  duration_trips <- NULL
  if (!is.null(trip_id)) duration_trips <- unique(lengths$trip_id)

  if (by == "trip") {
    durations <- get_trip_duration(gtfs, duration_trips, duration_unit)
    join_cols <- "trip_id"
  } else {
    durations <- get_trip_segment_duration(
      gtfs,
      duration_trips,
      duration_unit,
      sort_sequence
    )
    join_cols <- c("trip_id", "segment")
  }

  # left join, so trips whose lengths couldn't be calculated (e.g. trips not
  # linked to a shape) are kept, with NA speeds

  speeds <- durations[lengths, on = join_cols]

  speeds[, speed := length / duration]
  speeds[!is.finite(duration) | duration <= 0, speed := NA_real_]

  speeds[, c("length", "duration") := NULL]
  data.table::setcolorder(speeds, setdiff(names(lengths), "length"))

  return(speeds[])
}
