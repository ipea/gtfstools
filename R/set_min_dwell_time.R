#' Set a minimum dwell time
#'
#' Raises the dwell time of each specified `trip_id` at each specified
#' `stop_id` to at least `min_dwell_time`, i.e. makes vehicles stay at least
#' that long at the stops, by delaying the `departure_time` at these stops in
#' `stop_times` and shifting the later times of the trips accordingly.
#'
#' @template gtfs
#' @param min_dwell_time A non-negative number, the minimum dwell time, in
#'   `unit`. It's rounded to the nearest whole second.
#' @param unit A string representing the time unit in which `min_dwell_time`
#'   is given. One of `"s"` (seconds, the default), `"min"` (minutes), `"h"`
#'   (hours) or `"d"` (days).
#' @param trip_id A character vector including the `trip_id`s to have their
#'   dwell times raised. If `NULL` (the default), the dwell times of every
#'   `trip_id` in the GTFS (or of every trip of the given `route_type`s) are
#'   raised.
#' @param stop_id A character vector including the `stop_id`s at which the
#'   dwell times are raised. If `NULL` (the default), the dwell times are
#'   raised at every `stop_id` in the GTFS.
#' @inheritParams set_dwell_time
#'
#' @inherit set_dwell_time return
#'
#' @section Details:
#' Visits are selected as in [set_dwell_time()]. At each selected visit whose
#' dwell time is shorter than `min_dwell_time`, the arrival time is kept and
#' the departure time is set to the arrival time plus `min_dwell_time`.
#'
#' The first and last visits with both an arrival and a departure time of each
#' trip are never raised (use [set_dwell_time()] for them). They are found
#' among all the visits of the trip, not only the selected ones, and the times
#' of the last visit may still be shifted by an earlier visit.
#'
#' Negative dwell times (departure earlier than arrival) are raised like any
#' other shorter dwell time, so a `min_dwell_time` of 0 raises only these.
#' When they come from times after midnight written as `"00:30:00"` instead of
#' `"24:30:00"`, the later times of the trip are shifted by about a day.
#'
#' Otherwise it works as [set_dwell_time()].
#'
#' @seealso [set_dwell_time()], [get_dwell_time()], [fix_gtfs()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # vehicles stay 0 seconds at the stops of this trip. make them stay at least
#' # 30 seconds at each intermediate stop
#' head(get_dwell_time(gtfs, trip_id = "CPTM L07-0"))
#'
#' new_gtfs <- set_min_dwell_time(gtfs, 30, trip_id = "CPTM L07-0")
#' head(get_dwell_time(new_gtfs, trip_id = "CPTM L07-0"))
#'
#' @export
set_min_dwell_time <- function(
  gtfs,
  min_dwell_time,
  unit = "s",
  trip_id = NULL,
  stop_id = NULL,
  from = NULL,
  to = NULL,
  route_type = NULL,
  by_reference = FALSE
) {
  gtfs <- assert_and_assign_gtfs_object(gtfs, by_reference = by_reference)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_character(stop_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_string(unit)
  checkmate::assert_names(unit, subset.of = names(dwell_unit_factors))
  checkmate::assert_number(
    min_dwell_time,
    lower = 0,
    upper = max_time_secs / dwell_unit_factors[[unit]]
  )
  window <- dwell_time_window(from, to)
  checkmate::assert_integerish(
    route_type,
    min.len = 1,
    any.missing = FALSE,
    null.ok = TRUE
  )
  checkmate::assert_logical(by_reference, any.missing = FALSE, len = 1)

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "stop_id", "stop_sequence", "arrival_time", "departure_time"),
    c("character", "character", "integer", "character", "character")
  )

  min_secs <- as.integer(round(min_dwell_time * dwell_unit_factors[[unit]]))

  gtfs <- change_dwell_times(
    gtfs,
    min_secs,
    trip_id,
    stop_id,
    window,
    route_type,
    by_reference,
    raise_only = TRUE
  )

  if (by_reference) {
    return(invisible(gtfs))
  }

  return(gtfs)
}
