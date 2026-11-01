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
#'   One of `"km/h"` (the default), `"m/s"` or `"mph"` (miles per hour).
#' @param sort_sequence Deprecated; do not supply. Timetables and shapes are
#'   now always sorted by `stop_sequence` and `shape_pt_sequence`. Passing
#'   `TRUE` raises a warning, and passing `FALSE` raises an error.
#' @param file Deprecated. Use `method` instead (`file = "stop_times"`
#'   corresponds to `method = "euclidean"`).
#' @inheritParams get_trip_length
#'
#' @return With `by = "trip"`, a `data.table` with the `route_id`, the
#'   `trip_id` and the average `speed` of each trip. With `by = "segment"`, a
#'   `data.table` with the `route_id`, the `trip_id`, the `segment` number, the
#'   `from_stop_id` and `to_stop_id` that delimit the segment and its average
#'   `speed`.
#'
#' @section Details:
#' The speed is the length calculated by [get_trip_length()] divided by the
#' duration calculated by [get_trip_duration()] (with `by = "trip"`) or by
#' [get_trip_segment_duration()] (with `by = "segment"`). Speeds are `NA` when
#' the length is `NA` (e.g. trips not linked to a shape) or when the duration
#' is missing (e.g. blank times at intermediate stops) or not positive. With
#' `by = "trip"`, trips without any arrival or departure time raise the warning
#' of [get_trip_duration()].
#'
#' The `route_id` of each trip comes from the `trips` table, which is required
#' (also with `method = "euclidean"`). Trips not listed in `trips` have an `NA`
#' `route_id`.
#'
#' Existing `_secs` columns in `stop_times` (e.g. created with
#' [convert_time_to_seconds()]) are used as-is, not recalculated from the time
#' strings.
#'
#' `from` and `to` select the trips (or segments) as in [get_trip_length()],
#' from the `departure_time` strings, even if `_secs` columns exist. Times
#' after midnight written as early morning times (e.g. `"00:30:00"` instead of
#' `"24:30:00"`) are first fixed with [fix_overnight_times()], if
#' `stop_sequence` is an integer column, so lengths, durations and the time of
#' day all use the fixed times.
#'
#' @seealso [get_route_speed()], [set_trip_speed()], [set_route_speed()],
#'   [get_trip_length()], [get_trip_duration()], [get_trip_segment_duration()]
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
#' # speed of the trips that depart within a time of day
#' peak_speed <- get_trip_speed(gtfs, from = "07:00:00", to = "09:00:00")
#' head(peak_speed)
#'
#' @export
get_trip_speed <- function(
  gtfs,
  trip_id = NULL,
  method = "shapes",
  by = "trip",
  unit = "km/h",
  sort_sequence,
  file = NULL,
  from = NULL,
  to = NULL
) {
  if (!missing(sort_sequence)) {
    check_deprecated_sort_sequence(
      sort_sequence,
      "get_trip_speed",
      c("stop_sequence", "shape_pt_sequence")
    )
  }

  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(by),
    checkmate::check_names(by, subset.of = c("trip", "segment")),
    combine = "and"
  )
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = names(speed_unit_factors)),
    combine = "and"
  )
  window <- dwell_time_window(from, to)

  # check the fields required to calculate durations before calculating
  # lengths, so errors are not thrown very late

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time"),
    rep("character", 3)
  )
  gtfsio::assert_field_class(
    gtfs,
    "trips",
    c("trip_id", "route_id"),
    rep("character", 2)
  )

  # speeds in mph are calculated in km/h and converted at the end

  length_unit <- ifelse(unit == "m/s", "m", "km")
  duration_unit <- ifelse(unit == "m/s", "s", "h")

  if (!is.null(file)) {
    method <- map_deprecated_file(file, "get_trip_speed")
  }

  # times after midnight written as early morning times are fixed first, so
  # get_trip_length() selects the segments within the time of day from the
  # same times as the durations, and the duration functions don't fix them
  # again. without an integer stop_sequence the times can't be ordered, so
  # they are used as written

  gtfs <- fix_overnight_in_call(gtfs = gtfs, trip_id = trip_id)

  # get_trip_length() keeps only the trips or segments within the time of
  # day, so the durations joined to them below are filtered too

  lengths <- get_trip_length(
    gtfs,
    trip_id,
    method,
    by,
    length_unit,
    from = from,
    to = to
  )

  # retrieve route_id col
  lengths[gtfs$trips, on = "trip_id", route_id := i.route_id]
  data.table::setcolorder(lengths, "route_id")

  if (nrow(lengths) == 0) {
    data.table::setnames(lengths, "length", "speed")
    return(lengths[])
  }

  # durations are calculated only for the trips whose lengths were calculated,
  # so a warning about a trip_id that doesn't exist is raised only once (by
  # get_trip_length()), and only for the trips within the time of day

  duration_trips <- NULL
  if (!is.null(trip_id) || any(is.finite(window))) {
    duration_trips <- unique(lengths$trip_id)
  }

  if (by == "trip") {
    durations <- get_trip_duration(gtfs, duration_trips, duration_unit)
    join_cols <- "trip_id"
  } else {
    durations <- get_trip_segment_duration(gtfs, duration_trips, duration_unit)
    join_cols <- c("trip_id", "segment")
  }

  # left join, so trips whose lengths couldn't be calculated (e.g. trips not
  # linked to a shape) are kept, with NA speeds

  speeds <- durations[lengths, on = join_cols]

  speeds[, speed := length / duration]
  speeds[!is.finite(duration) | duration <= 0, speed := NA_real_]

  if (unit == "mph") {
    speeds[, speed := speed / km_per_mile]
  }

  speeds[, c("length", "duration") := NULL]
  data.table::setcolorder(speeds, setdiff(names(lengths), "length"))

  return(speeds[])
}
