#' Get dwell time
#'
#' Returns the dwell time of each specified `trip_id` at each specified
#' `stop_id`, i.e. the time the vehicle stays at the stop, as specified in the
#' `stop_times` table.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#'   dwell times calculated. If `NULL` (the default), the function calculates
#'   the dwell times of every `trip_id` in the GTFS.
#' @param stop_id A character vector including the `stop_id`s to have their
#'   dwell times calculated. If `NULL` (the default), the function calculates
#'   the dwell times at every `stop_id` in the GTFS.
#' @param unit A string representing the time unit in which the dwell times
#'   are desired. One of `"s"` (seconds, the default), `"min"` (minutes), `"h"`
#'   (hours) or `"d"` (days).
#' @param from A string, in the "HH:MM:SS" format. Only visits whose arrival
#'   time is at or after `from` are included. If `NULL` (the default), there is
#'   no lower limit.
#' @param to A string, in the "HH:MM:SS" format. Only visits whose arrival time
#'   is at or before `to` are included. If `NULL` (the default), there is no
#'   upper limit.
#'
#' @return A `data.table` with the columns `trip_id`, `stop_id`,
#'   `stop_sequence` and `dwell_time`, with one row per visit of a specified
#'   trip to a specified stop (within the time of day, if `from` or `to` is
#'   given), ordered by `trip_id` and `stop_sequence`.
#'   `dwell_time` is numeric, in the given `unit`, and `NA` where a time is
#'   blank.
#'
#' @section Details:
#' The dwell time of a visit is its `departure_time` minus its `arrival_time`
#' in `stop_times`. When both `trip_id` and `stop_id` are given, the visits of
#' every specified trip to every specified stop are returned (not of pairs
#' formed by their elements). The first and last stops of each trip are
#' included. For trips listed in `frequencies`, one dwell time is returned per
#' visit of the template, not per departure.
#'
#' Blank times (`NA` dwell times) can be filled beforehand with
#' [interpolate_stop_times()]. Negative dwell times (departure earlier than
#' arrival) are returned as they are.
#'
#' Times after midnight written as early morning times (e.g. `"00:30:00"`
#' instead of `"24:30:00"`) are fixed with [fix_overnight_times()] before the
#' dwell times are calculated.
#'
#' `from` and `to` are compared with the `arrival_time` of each visit as
#' written in `stop_times`, once fixed (template times, for trips listed in
#' `frequencies`), so use times past `"24:00:00"` for arrivals after midnight.
#' Visits with a blank arrival time are never included when `from` or `to` is
#' given.
#'
#' `stop_id`s are matched against the `stop_id`s in `stop_times`, which are
#' never stations: to get the dwell times at a station, pass its children that
#' appear in `stop_times` (see [get_children_stops()]). Existing `_secs`
#' columns in `stop_times` are not used; times are read from the time strings.
#'
#' @seealso [set_dwell_time()], [set_min_dwell_time()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' dwell_times <- get_dwell_time(gtfs)
#' head(dwell_times)
#'
#' # use the trip_id and stop_id arguments to control which trips and stops
#' # are analyzed
#' get_dwell_time(gtfs, trip_id = "CPTM L07-0")
#' get_dwell_time(gtfs, stop_id = "18960")
#' get_dwell_time(
#'   gtfs,
#'   trip_id = c("CPTM L08-0", "CPTM L09-0"),
#'   stop_id = "18960"
#' )
#'
#' # blank times result in NA dwell times. use the unit argument to control in
#' # which unit the dwell times are calculated
#' ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
#' ggl_gtfs <- read_gtfs(ggl_path)
#' get_dwell_time(ggl_gtfs, trip_id = "AWE1", unit = "min")
#'
#' @export
get_dwell_time <- function(gtfs,
                           trip_id = NULL,
                           stop_id = NULL,
                           unit = "s",
                           from = NULL,
                           to = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_character(stop_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_string(unit)
  checkmate::assert_names(unit, subset.of = names(dwell_unit_factors))
  window <- dwell_time_window(from, to)

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "stop_id", "stop_sequence", "arrival_time", "departure_time"),
    c("character", "character", "integer", "character", "character")
  )

  # times after midnight written as early morning times are fixed first, so
  # they don't go back

  gtfs <- fix_overnight_in_call(gtfs, trip_id)

  rows <- select_dwell_time_calls(gtfs$stop_times, trip_id, stop_id)

  arr <- string_to_seconds(gtfs$stop_times$arrival_time[rows])
  dep <- string_to_seconds(gtfs$stop_times$departure_time[rows])

  # only visits whose arrival is within the time of day are kept, so blank
  # arrivals are dropped when a window is given

  if (any(is.finite(window))) {
    in_window <- !is.na(arr) & arr >= window[1] & arr <= window[2]
    rows <- rows[in_window]
    arr <- arr[in_window]
    dep <- dep[in_window]
  }

  dwell <- gtfs$stop_times[rows, .(trip_id, stop_id, stop_sequence)]
  dwell[, dwell_time := as.numeric(dep - arr)]
  data.table::setorderv(dwell, c("trip_id", "stop_sequence"))

  if (unit != "s") {
    dwell[, dwell_time := dwell_time / dwell_unit_factors[[unit]]]
  }

  return(dwell[])
}
