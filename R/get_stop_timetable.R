#' Get stop timetable
#'
#' Returns the timetable of the given stops on the given dates: one row for
#' each stop time at these stops on each date on which its trip runs.
#'
#' @template gtfs
#' @param stop_id A character vector including the `stop_id`s whose timetable
#'   should be built. If `NULL` (the default), the timetable of all stops is
#'   built.
#' @param date A `Date` vector (including `IDate`) or a character vector of
#'   dates in the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. If `NULL` (the
#'   default), all the dates on which the GTFS object has service (as returned
#'   by [get_dates()]) are used, which may result in a very large table.
#'
#' @return A `data.table` with the column `date` (of class `Date`), followed by
#'   all the columns of `trips` and all the columns of `stop_times` (`trip_id`
#'   appears only once). It is sorted by `date`, `stop_id`, departure time and
#'   `trip_id`. If no trip stops at the given stops on the given dates, an empty
#'   table with the same columns is returned, without a warning.
#'
#' @section Details:
#' A trip runs on a date if its service is active on it, as in
#' [get_active_services()], so dates outside the period covered by the GTFS
#' object are skipped. Trips listed in `stop_times` but not in `trips` are not
#' included. Departure times are sorted as times, not as strings, and stop
#' times with an empty `departure_time` come last at each stop. Duplicated
#' rows in `trips` and `stop_times` are kept.
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
#' Only the exact given stops are included: to include the stops of a station,
#' pass them with [get_children_stops()]. The `frequencies` table is not used:
#' frequency-based trips appear with the times of their template trips, as
#' listed in `stop_times`. To include all their departures, convert them with
#' [frequencies_to_stop_times()] first.
#'
#' @seealso [get_route_timetable()], [get_active_services()], [get_dates()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' timetable <- get_stop_timetable(gtfs, "100000720101", "20210104")
#' head(timetable)
#'
#' # several dates, also as Date objects
#' timetable <- get_stop_timetable(
#'   gtfs,
#'   stop_id = "100000720101",
#'   date = as.Date(c("2021-01-04", "2021-01-09"))
#' )
#' table(timetable$date)
#' @export
get_stop_timetable <- function(gtfs, stop_id = NULL, date = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(stop_id, null.ok = TRUE, any.missing = FALSE)
  gtfsio::assert_field_class(
    gtfs,
    "trips",
    c("trip_id", "service_id"),
    rep("character", 2)
  )
  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "stop_id", "departure_time"),
    rep("character", 3)
  )

  if (is.null(date)) {
    date <- get_dates(gtfs)
  } else {
    date <- parse_dates(date)
  }

  stop_times <- gtfs$stop_times

  if (!is.null(stop_id)) {
    is_relevant <- stop_times$stop_id %chin% stop_id

    # the matched rows already hold every existing stop_id, so the full
    # column doesn't have to be searched again

    warn_missing_ids(
      stop_id,
      stop_times$stop_id[is_relevant],
      "stop_times",
      "stop_id"
    )

    stop_times <- stop_times[is_relevant]
  }

  timetable <- build_timetable(
    gtfs,
    gtfs$trips,
    stop_times,
    date,
    sort_by = c("date", "stop_id", ".departure_secs", "trip_id")
  )

  return(timetable)
}



#' Build a timetable
#'
#' Joins the given trips and stop times, and then each resulting row to the
#' dates on which its trip runs. Used by [get_stop_timetable()] and
#' [get_route_timetable()].
#'
#' @template gtfs
#' @param trips,stop_times The (possibly filtered) `trips` and `stop_times`
#'   tables. They are not modified.
#' @param date A `Date` vector, possibly empty.
#' @param sort_by A character vector with the columns to sort the timetable by.
#'   It may include the temporary columns `".departure_secs"` (the departure
#'   time in seconds) and `".first_departure_secs"` (the first departure time
#'   of the trip in seconds), which are removed after sorting.
#' @param call The environment of the calling function, in which errors are
#'   reported.
#'
#' @return A `data.table` with the column `date`, followed by the columns of
#'   `trips` and those of `stop_times`, sorted by `sort_by`.
#'
#' @keywords internal
build_timetable <- function(gtfs,
                            trips,
                            stop_times,
                            date,
                            sort_by,
                            call = parent.frame()) {
  tables_with_date <- c("trips", "stop_times")[
    c("date" %in% names(trips), "date" %in% names(stop_times))
  ]

  if (length(tables_with_date) > 0) {
    cli::cli_abort(
      c(
        "The timetable {.field date} column can't be created.",
        "x" = "{.field {tables_with_date}} already ha{?s/ve} a {.field date}
               column."
      ),
      class = "gtfstools_timetable_date_column_error",
      call = call
    )
  }

  # trips that don't run on any of the dates are dropped first, so the work
  # below is done only for the relevant trips. a service may be listed twice
  # on a day, by calendar and calendar_dates

  services <- unique(get_services_on_days(gtfs, unique(as.integer(date))))
  runs_on_dates <- trips$service_id %chin% services$service_id
  trips <- trips[runs_on_dates]

  # the stop times are joined to their trips before being repeated for each
  # date, so only the given stop times are repeated. the join creates a new
  # table, so the temporary columns below don't reach the given tables.
  # duplicated trips are kept, which may result in more rows than the inputs

  timetable <- trips[
    stop_times,
    on = "trip_id",
    nomatch = NULL,
    allow.cartesian = TRUE
  ]

  departure_secs <- string_to_seconds(timetable$departure_time)

  if (".departure_secs" %in% sort_by) {
    data.table::set(timetable, j = ".departure_secs", value = departure_secs)
  }

  # the first departure of each trip is calculated only from its non-empty
  # times, because min() of an empty vector is Inf, with a warning

  if (".first_departure_secs" %in% sort_by) {
    first_departure_secs <- rep(NA_integer_, nrow(timetable))
    is_timed <- !is.na(departure_secs)

    if (any(is_timed)) {
      first_departures <- data.table::data.table(
        trip_id = timetable$trip_id[is_timed],
        departure_time_secs = departure_secs[is_timed]
      )
      first_departures <- first_departures[
        ,
        .(departure_time_secs = min(departure_time_secs, na.rm = TRUE)),
        by = trip_id
      ]

      first_departure_secs <- first_departures$departure_time_secs[
        data.table::chmatch(timetable$trip_id, first_departures$trip_id)
      ]
    }

    data.table::set(
      timetable,
      j = ".first_departure_secs",
      value = first_departure_secs
    )
  }

  services <- services[
    ,
    .(date = as.Date(day, origin = "1970-01-01"), service_id)
  ]

  timetable <- timetable[
    services,
    on = "service_id",
    nomatch = NULL,
    allow.cartesian = TRUE
  ]

  data.table::setcolorder(timetable, "date")
  data.table::setorderv(timetable, sort_by, na.last = TRUE)

  temporary_cols <- intersect(
    c(".departure_secs", ".first_departure_secs"),
    names(timetable)
  )
  if (length(temporary_cols) > 0) {
    data.table::set(timetable, j = temporary_cols, value = NULL)
  }

  return(timetable)
}
