#' Get trip speed
#'
#' Returns the speed of each specified `trip_id`, based on the geometry created
#' from either the `shapes` or the `stop_times` file (or both).
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#'   speeds calculated. If `NULL` (the default), the function calculates the
#'   speed of every `trip_id` in the GTFS.
#' @param file The file from which geometries should be generated, either
#'   `shapes` or `stop_times` (geometries are used to calculate the length of a
#'   trip). Defaults to `shapes`.
#' @param unit A string representing the unit in which the speeds are desired.
#'   Either `"km/h"` (the default) or `"m/s"`.
#' @param sort_sequence Ultimately passed to [get_trip_length()], a logical
#'   specifying whether to sort shapes and timetables by `shape_pt_sequence` and
#'   `stop_sequence`, respectively. Speeds calculated from trip trajectories
#'   generated with unordered sequences do not correctly depict the actual trip
#'   speeds. Defaults to `TRUE`. Sorting an already ordered table is cheap. Set
#'   to `FALSE` only if shapes and timetables are known to be ordered.
#'
#' @return A `data.table` containing the duration of each specified trip and the
#'   file from which geometries were generated.
#'
#' @section Details:
#' Please check [get_trip_geometry()] documentation to understand how geometry
#' generation differs depending on the chosen file.
#'
#' Existing `_secs` columns in `stop_times` (e.g. created with
#' [convert_time_to_seconds()]) are used as-is, not recalculated from the time
#' strings.
#'
#' @seealso [get_trip_geometry()]
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
#' trip_speed <- get_trip_speed(
#'   gtfs,
#'   trip_ids,
#'   file = c("shapes", "stop_times")
#' )
#' trip_speed
#'
#' trip_speed <- get_trip_speed(gtfs, trip_ids, unit = "m/s")
#' trip_speed
#'
#' @export
get_trip_speed <- function(gtfs,
                           trip_id = NULL,
                           file = "shapes",
                           unit = "km/h",
                           sort_sequence = TRUE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_names(file, subset.of = c("shapes", "stop_times"))
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = c("km/h", "m/s")),
    combine = "and"
  )
  checkmate::assert_logical(sort_sequence, any.missing = FALSE, len = 1)

  # check if fields and files required to estimate trip duration exist (a bit of
  # an overlap, since these are also checked in a later get_trip_duration call,
  # but it prevents cases where the files required to generate geometries are
  # present but those required to estimate trip duration are not, which would
  # cause errors to be thrown very late)

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time"),
    rep("character", 3)
  )

  length_unit <- ifelse(unit == "km/h", "km", "m")
  trips_length <- get_trip_length(
    gtfs,
    trip_id,
    file,
    length_unit,
    sort_sequence
  )

  # calculate trips' duration
  # - a warning might be raised in get_trip_duration() if a trip in
  # existing_trips doesn't exist in stop_times table. if 'trip_id' is NULL, we
  # don't want to raise that warning, so we remove missing stop_times trips from
  # existing_trips

  existing_trips <- unique(trips_length$trip_id)
  if (is.null(trip_id)) {
    stop_times_trips <- unique(gtfs$stop_times$trip_id)
    existing_trips <- existing_trips[existing_trips %chin% stop_times_trips]
  }

  duration_unit <- data.table::fifelse(unit == "km/h", "h", "s")
  trips_duration <- get_trip_duration(gtfs, existing_trips, duration_unit)

  # join trips_length and trips_duration
  # a trip may be missing from trips_duration and not from trips_length (when
  # stop_times doesn't contain a trip listed in trips_length), but not the other
  # way around (because only trips listed in trips_length have their durations
  # calculated). so we do a right join here, instead of a left join

  trips_speed <- trips_length[trips_duration, on = "trip_id"]

  # calculate speed as length/duration

  trips_speed[, speed := length / duration]

  # remove length and duration columns

  trips_speed[, `:=`(length = NULL, duration = NULL)]

  return(trips_speed[])
}
