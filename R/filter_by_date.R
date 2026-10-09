#' Filter GTFS object by date
#'
#' Filters a GTFS object by the services that run on the given dates, keeping
#' (or dropping) the relevant entries in each file.
#'
#' @template gtfs
#' @param date A `Date` vector (including `IDate`) or a character vector of
#'   dates in the `"YYYY-MM-DD"` format. The dates used to filter the data.
#' @param keep A logical. Whether the entries related to the services that run
#'   on the specified dates should be kept or dropped (defaults to `TRUE`,
#'   which keeps the entries).
#'
#' @return The GTFS object passed to the `gtfs` parameter, after the filtering
#'   process.
#'
#' @section Details:
#' The services that run on at least one of the given dates are kept (or
#' dropped) as a whole: their `calendar` and `calendar_dates` entries are not
#' trimmed to the given dates, so they may still run on other dates.
#'
#' A service runs on a date if its `calendar` entry spans the date and flags
#' its weekday, unless the date is removed from it in `calendar_dates`
#' (`exception_type` 2), or if the date is added to it in `calendar_dates`
#' (`exception_type` 1). An addition wins over a removal on the same date.
#' Either table may be missing. If both are missing, the GTFS object is
#' returned unchanged, with a warning.
#'
#' @family filtering functions
#' @seealso [filter_by_weekday()], [get_calendar_overlap()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # on 2006-07-03 (a monday) the weekday service "WD" is replaced by the
#' # weekend service "WE", according to the calendar_dates table
#' gtfs$calendar_dates
#'
#' smaller_gtfs <- filter_by_date(gtfs, "2006-07-03")
#' smaller_gtfs$calendar
#'
#' # dates may also be given as Date objects. drops the services that run on
#' # 2006-07-05 (a wednesday)
#' smaller_gtfs <- filter_by_date(gtfs, as.Date("2006-07-05"), keep = FALSE)
#' smaller_gtfs$calendar
#' @export
filter_by_date <- function(gtfs, date, keep = TRUE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert(
    checkmate::check_date(date, any.missing = FALSE, min.len = 1),
    checkmate::check_character(date, any.missing = FALSE, min.len = 1),
    .var.name = "date"
  )
  checkmate::assert_logical(keep, len = 1, any.missing = FALSE)

  # as.Date() alone accepts trailing text (e.g. "2021-01-01x"), so strings
  # must also be formatted back to themselves

  if (is.character(date)) {
    parsed_date <- as.Date(date, format = "%Y-%m-%d")
    is_bad <- is.na(parsed_date) | format(parsed_date) != date
    is_bad[is.na(is_bad)] <- TRUE

    if (any(is_bad)) {
      bad_dates <- date[is_bad]
      cli::cli_abort(
        c(
          "{.arg date} must be in the {.val YYYY-MM-DD} format.",
          "x" = "Invalid date{?s}: {.val {bad_dates}}."
        ),
        class = "gtfstools_bad_date_error"
      )
    }

    date <- parsed_date
  }

  if (
    !gtfsio::check_file_exists(gtfs, "calendar") &&
      !gtfsio::check_file_exists(gtfs, "calendar_dates")
  ) {
    cli::cli_warn(
      c(
        "The GTFS object has neither a {.file calendar} nor a
         {.file calendar_dates} table.",
        "i" = "It was returned unchanged."
      ),
      class = "gtfstools_no_calendar_warning"
    )
    return(gtfs)
  }

  relevant_services <- get_services_on_days(gtfs, unique(as.integer(date)))
  gtfs <- filter_by_service_id(gtfs, relevant_services, keep)

  return(gtfs)
}



#' Get the services that run on the given days
#'
#' Returns the services that run on at least one of the given days, according
#' to the `calendar` and `calendar_dates` tables (either may be missing).
#'
#' @template gtfs
#' @param days An integer vector of unique days, as the number of days since
#'   1970-01-01.
#'
#' @return A character vector of unique `service_id`s, empty if no service
#'   runs on the given days.
#'
#' @keywords internal
get_services_on_days <- function(gtfs, days) {
  weekday_cols <- c(
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday"
  )

  # 1970-01-01 was a thursday, so (day + 3) %% 7 is 0 on mondays, which gives
  # the weekday of a day (1 is monday) regardless of the locale

  given_days <- data.table::data.table(
    day = days,
    weekday = (days + 3L) %% 7L + 1L
  )

  services_on_days <- data.table::data.table(
    service_id = character(0),
    day = integer(0)
  )

  # each calendar entry is matched to the given days that it spans and whose
  # weekday it flags (entries with missing or inverted dates are dropped)

  if (gtfsio::check_file_exists(gtfs, "calendar")) {
    gtfsio::assert_field_class(
      gtfs,
      "calendar",
      c("service_id", weekday_cols, "start_date", "end_date"),
      c("character", rep("integer", 7), "Date", "Date")
    )

    service_weekdays <- data.table::melt(
      gtfs$calendar[
        ,
        c("service_id", weekday_cols, "start_date", "end_date"),
        with = FALSE
      ],
      measure.vars = weekday_cols,
      variable.name = "weekday",
      value.name = "runs"
    )
    service_weekdays <- service_weekdays[
      runs %in% 1L & start_date <= end_date,
      .(
        service_id,
        weekday = as.integer(weekday),
        first_day = as.integer(start_date),
        last_day = as.integer(end_date)
      )
    ]

    services_on_days <- service_weekdays[
      given_days,
      on = .(weekday, first_day <= day, last_day >= day),
      nomatch = NULL,
      .(service_id = x.service_id, day = i.day)
    ]
  }

  # the days removed from a service are dropped before the days added to it
  # are included, so that an addition wins over a removal on the same day

  if (gtfsio::check_file_exists(gtfs, "calendar_dates")) {
    gtfsio::assert_field_class(
      gtfs,
      "calendar_dates",
      c("service_id", "date", "exception_type"),
      c("character", "Date", "integer")
    )

    exceptions <- gtfs$calendar_dates[
      as.integer(date) %in% days,
      .(service_id, day = as.integer(date), exception_type)
    ]

    services_on_days <- services_on_days[
      !exceptions[exception_type == 2L],
      on = .(service_id, day)
    ]
    services_on_days <- rbind(
      services_on_days,
      exceptions[exception_type == 1L, .(service_id, day)]
    )
  }

  relevant_services <- unique(services_on_days$service_id)
  relevant_services <- relevant_services[!is.na(relevant_services)]

  return(relevant_services)
}
