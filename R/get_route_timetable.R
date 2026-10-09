#' Get route timetable
#'
#' Returns the timetable of the given routes on the given dates: one row for
#' each stop time of their trips on each date on which the trip runs.
#'
#' @template gtfs
#' @param route_id A character vector including the `route_id`s whose
#'   timetable should be built. If `NULL` (the default), the timetable of all
#'   routes is built.
#' @param date A `Date` vector (including `IDate`) or a character vector of
#'   dates in the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. If `NULL` (the
#'   default), all the dates on which the GTFS object has service (as returned
#'   by [get_dates()]) are used, which may result in a very large table.
#'
#' @return A `data.table` with the column `date` (of class `Date`), followed by
#'   all the columns of `trips` and all the columns of `stop_times` (`trip_id`
#'   appears only once). It is sorted by `date` and `route_id`, and then the
#'   trips of each route are sorted by their first departure time (and
#'   `trip_id`), each with its stop times sorted by `stop_sequence`. If the
#'   given routes have no trips on the given dates, an empty table with the
#'   same columns is returned, without a warning.
#'
#' @section Details:
#' A trip runs on a date if its service is active on it, as in
#' [get_active_services()], so dates outside the period covered by the GTFS
#' object are skipped. Trips listed in `stop_times` but not in `trips` are not
#' included. Departure times are sorted as times, not as strings, and trips
#' without any departure time come last in their route. Duplicated rows in
#' `trips` and `stop_times` are kept.
#'
#' Without `calendar` and `calendar_dates` tables, no trip runs, and an empty
#' table is returned. Columns other than `trip_id` present in both `trips` and
#' `stop_times` (not defined by the GTFS reference) appear twice, the one from
#' `stop_times` prefixed with `i.`, and the ones from `trips` are used to sort
#' the timetable.
#'
#' `date` is the service date: stop times past 24:00:00 happen on the
#' following calendar day.
#'
#' The `frequencies` table is not used: frequency-based trips appear with the
#' times of their template trips, as listed in `stop_times`. To include all
#' their departures, convert them with [frequencies_to_stop_times()] first.
#'
#' @seealso [get_stop_timetable()], [get_active_services()], [get_dates()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' timetable <- get_route_timetable(gtfs, "1922_3", "20210104")
#' head(timetable)
#'
#' # several routes and dates, also as Date objects
#' timetable <- get_route_timetable(
#'   gtfs,
#'   route_id = c("1922_3", "1921_3"),
#'   date = as.Date(c("2021-01-04", "2021-01-09"))
#' )
#' table(timetable$date, timetable$route_id)
#' @export
get_route_timetable <- function(gtfs, route_id = NULL, date = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(route_id, null.ok = TRUE, any.missing = FALSE)
  gtfsio::assert_field_class(
    gtfs,
    "trips",
    c("trip_id", "route_id", "service_id"),
    rep("character", 3)
  )
  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "departure_time", "stop_sequence"),
    c("character", "character", "integer")
  )

  if (is.null(date)) {
    date <- get_dates(gtfs)
  } else {
    date <- parse_dates(date)
  }

  # the stop times of other routes are dropped when joined to the trips, so
  # only the trips have to be filtered

  trips <- gtfs$trips

  if (!is.null(route_id)) {
    is_relevant <- trips$route_id %chin% route_id

    warn_missing_ids(
      route_id,
      trips$route_id[is_relevant],
      "trips",
      "route_id"
    )

    trips <- trips[is_relevant]
  }

  timetable <- build_timetable(
    gtfs,
    trips,
    gtfs$stop_times,
    date,
    sort_by = c(
      "date",
      "route_id",
      ".first_departure_secs",
      "trip_id",
      "stop_sequence"
    )
  )

  return(timetable)
}
