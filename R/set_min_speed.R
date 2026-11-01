#' Set trip minimum speed
#'
#' Raises the speed of the specified trips: each part of a trip that is slower
#' than `min_speed` is sped up to `min_speed`, by changing the `arrival_time`
#' and `departure_time` columns in `stop_times`. Parts of the trips that are
#' already faster are left unchanged.
#'
#' @template gtfs
#' @param min_speed A number. The minimum speed allowed, in the unit given by
#'   `unit`.
#' @param route_id A character vector including the `route_id`s whose trips
#'   have their speeds raised. If `route_id`, `trip_id` and `route_type` are
#'   all `NULL` (the default), the speeds of every trip in the GTFS are raised.
#'   `route_id`s not listed in `trips` are ignored, with a warning.
#' @param trip_id A character vector including the `trip_id`s to have their
#'   speeds raised. When given together with `route_id`, the trips of both are
#'   raised.
#' @param first_stop A string. The `stop_id` where the segment whose speeds
#'   are raised starts. If `NULL` (the default), the segment starts at each
#'   trip's first stop.
#' @param last_stop A string. The `stop_id` where the segment ends. If `NULL`
#'   (the default), the segment ends at each trip's last stop.
#' @inheritParams set_max_speed
#'
#' @return A GTFS object with the time columns of its `stop_times` adjusted.
#'
#' @section Details:
#' A span is the part of a trip between two consecutive stops with times;
#' stops with blank times inside it are kept blank. Its speed is its length,
#' calculated by [get_trip_length()] along the trip's shape (or, with a
#' warning, as straight lines between stops if there are no shapes; the
#' `stops` table is required), divided by the time from the departure at its
#' first stop to the arrival at its second. Spans whose length is `NA` (e.g.
#' in trips not linked to a shape) or 0 (e.g. between stops at the same
#' place) are left unchanged.
#'
#' Each span slower than `min_speed` has its duration lowered to its length
#' divided by `min_speed`, rounded down to the whole second (so a very
#' short span may end up with a duration of 0). All the later times of the
#' trip are shifted earlier by the accumulated saved time, so dwell times are
#' kept. Times after midnight written as early morning times (e.g.
#' `"00:30:00"` instead of `"24:30:00"`) are first fixed with
#' [fix_overnight_times()] in every trip, so the returned GTFS has them fixed.
#' Spans whose arrival is still earlier than the previous departure (by 12
#' hours or less) are left unchanged, with a warning. An error is raised if a shift would result
#' in a time earlier than `"00:00:00"`. Only `stop_times` is modified; its
#' existing `_secs` columns are updated to match.
#'
#' With `first_stop` and `last_stop`, matched as in [set_trip_speed()], only
#' the spans between them are raised: times before `first_stop` don't change,
#' and the times at and after `last_stop` are shifted. The given stops must
#' have a time, so that no span crosses them (if only `last_stop` is given,
#' the trip's first stop needs none). Trips that don't visit `first_stop` and
#' then `last_stop`, or have blank times there, are left unchanged, with a
#' warning if they were given in `trip_id` or `route_id`.
#'
#' `from` and `to` are compared with the departure at the segment's first stop
#' (or its arrival, if the departure is blank) as written in `stop_times`
#' (template times, for trips listed in `frequencies`), so use times past
#' `"24:00:00"` for departures after midnight. Trips without a time there are
#' left unchanged.
#'
#' @seealso [set_max_speed()], [set_trip_speed()], [get_trip_speed()]
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
#' # the trip is slower than 20 km/h between some of its stops
#' get_trip_speed(gtfs, "CPTM L07-0", by = "segment")
#'
#' gtfs_raised <- set_min_speed(gtfs, min_speed = 20, trip_id = "CPTM L07-0")
#' get_trip_speed(gtfs_raised, "CPTM L07-0", by = "segment")
#'
#' # the later stops are shifted, so the trip ends earlier
#' get_start_and_end_times(gtfs, trip_id = "CPTM L07-0")
#' get_start_and_end_times(gtfs_raised, trip_id = "CPTM L07-0")
#'
#' # raise the speed only between two stops. the spans before and after them
#' # are not raised
#' gtfs_raised <- set_min_speed(
#'   gtfs,
#'   min_speed = 20,
#'   trip_id = "CPTM L07-0",
#'   first_stop = "18917",
#'   last_stop = "18922"
#' )
#' get_trip_speed(gtfs_raised, "CPTM L07-0", by = "segment")
#'
#' @export
set_min_speed <- function(
  gtfs,
  min_speed,
  unit = "km/h",
  route_id = NULL,
  trip_id = NULL,
  first_stop = NULL,
  last_stop = NULL,
  from = NULL,
  to = NULL,
  route_type = NULL
) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_number(
    min_speed,
    lower = .Machine$double.eps,
    finite = TRUE
  )
  checkmate::assert_character(route_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = names(speed_unit_factors)),
    combine = "and"
  )
  checkmate::assert_string(first_stop, min.chars = 1, null.ok = TRUE)
  checkmate::assert_string(last_stop, min.chars = 1, null.ok = TRUE)
  checkmate::assert_string(from, pattern = time_pattern, null.ok = TRUE)
  checkmate::assert_string(to, pattern = time_pattern, null.ok = TRUE)
  checkmate::assert_integerish(
    route_type,
    min.len = 1,
    any.missing = FALSE,
    null.ok = TRUE
  )

  window <- dwell_time_window(from, to)

  # calculations use km/h

  min_kmh <- min_speed * speed_unit_factors[[unit]]

  return(
    limit_trip_speed(
      gtfs,
      min_kmh,
      "min",
      route_id,
      trip_id,
      first_stop,
      last_stop,
      window,
      route_type
    )
  )
}
