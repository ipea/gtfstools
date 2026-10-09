#' Get start and end times
#'
#' Returns the earliest departure time and the latest arrival time listed in
#' the `stop_times` table, optionally restricted to the given trips and/or to
#' the trips active on the given dates.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to consider.
#'   If `NULL` (the default), all trips are considered.
#' @param date A `Date` vector (including `IDate`) or a character vector of
#'   dates in the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. If given, only trips
#'   whose services are active on any of these dates are considered. If `NULL`
#'   (the default), trips are not restricted by date.
#'
#' @return A named character vector of length 2, with the elements
#'   `start_time` (the earliest `departure_time`) and `end_time` (the latest
#'   `arrival_time`), in the `"HH:MM:SS"` format. Times past midnight keep
#'   hours of 24 and above. If no stop time is considered, or if all their
#'   times are empty, both elements are `NA`, without a warning.
#'
#' @section Details:
#' Times are compared as seconds, not as strings, so `"5:00:00"` comes before
#' `"10:00:00"` (and is returned as `"05:00:00"`). Empty times are ignored,
#' and malformed ones are ignored with a warning.
#'
#' When both `trip_id` and `date` are given, only the given trips that are
#' active on the given dates are considered. The services active on each date
#' are found with [get_active_services()]. Trips listed in `stop_times` but
#' not in `trips` are not considered when `date` is given, and if the GTFS
#' object has no `calendar` nor `calendar_dates` tables, no trip is active.
#'
#' The `frequencies` table is not used: the times of frequency-based trips are
#' taken from their template trips as they are listed in `stop_times`. To
#' consider all their departures, convert them with
#' [frequencies_to_stop_times()] first.
#'
#' @seealso [get_active_services()], [get_trip_duration()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' get_start_and_end_times(gtfs)
#'
#' get_start_and_end_times(gtfs, trip_id = c("146389748", "146389727"))
#'
#' # restricted to the trips active on a given date
#' data_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' get_start_and_end_times(gtfs, date = "20060701")
#' @export
get_start_and_end_times <- function(gtfs, trip_id = NULL, date = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time"),
    rep("character", 3)
  )

  # the stop_times columns are handled as vectors, so the table is neither
  # copied nor modified. they are only subset if a filter is given

  is_relevant <- NULL

  if (!is.null(trip_id)) {
    is_relevant <- gtfs$stop_times$trip_id %chin% trip_id

    # the matched rows already hold every existing trip_id, so the full
    # column doesn't have to be searched again

    warn_missing_ids(
      trip_id,
      gtfs$stop_times$trip_id[is_relevant],
      "stop_times",
      "trip_id"
    )
  }

  if (!is.null(date)) {
    gtfsio::assert_field_class(
      gtfs,
      "trips",
      c("trip_id", "service_id"),
      rep("character", 2)
    )

    active_services <- get_active_services(gtfs, date)$service_id
    is_active <- gtfs$trips$service_id %chin% active_services
    active_trips <- gtfs$trips$trip_id[is_active]

    # NA %chin% NA is TRUE, so NA trip_ids would match each other

    active_trips <- active_trips[!is.na(active_trips)]

    is_active <- gtfs$stop_times$trip_id %chin% active_trips
    if (!is.null(is_relevant)) is_active <- is_relevant & is_active
    is_relevant <- is_active
  }

  departure_time <- gtfs$stop_times$departure_time
  arrival_time <- gtfs$stop_times$arrival_time

  if (!is.null(is_relevant)) {
    departure_time <- departure_time[is_relevant]
    arrival_time <- arrival_time[is_relevant]
  }

  departure_secs <- string_to_seconds(departure_time)
  arrival_secs <- string_to_seconds(arrival_time)

  # seconds_to_string() formats NA as "", so empty results are kept as NA

  start_time <- end_time <- NA_character_

  if (any(!is.na(departure_secs))) {
    start_time <- seconds_to_string(min(departure_secs, na.rm = TRUE))
  }

  if (any(!is.na(arrival_secs))) {
    end_time <- seconds_to_string(max(arrival_secs, na.rm = TRUE))
  }

  return(c(start_time = start_time, end_time = end_time))
}
