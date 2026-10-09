#' Get service dates
#'
#' Returns the dates on which the GTFS object has service.
#'
#' @template gtfs
#' @param as_date A logical. Whether to return the dates as a `Date` vector
#'   (`TRUE`, the default) or as a character vector in the `"YYYYMMDD"` format
#'   used by GTFS (`FALSE`).
#'
#' @return A sorted vector of unique dates, either of class `Date` or a
#'   character vector, depending on `as_date`. It is empty, without a warning,
#'   if the GTFS object has no service date.
#'
#' @section Details:
#' The GTFS object has service on a date if at least one of its services runs
#' on it. A service runs on the dates between the `start_date` and `end_date`
#' of its `calendar` entry whose weekday is flagged, minus the dates removed
#' from it in `calendar_dates` (`exception_type` 2), plus the dates added to it
#' (`exception_type` 1). Either table may be missing. If the `trips` table has
#' a `service_id` field, services not used by any trip are ignored, so each
#' returned date keeps at least one trip when passed to [filter_by_date()].
#' `feed_info` dates are not used.
#'
#' @seealso [get_calendar_overlap()], [filter_by_date()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # the calendar covers all of July 2006, but only weekends (plus 2006-07-03
#' # and 2006-07-04, added by calendar_dates) are returned, because the
#' # weekday service "WD" is not used by any trip
#' get_dates(gtfs)
#'
#' # dates may also be returned in the "YYYYMMDD" format used by GTFS
#' get_dates(gtfs, as_date = FALSE)
#' @export
get_dates <- function(gtfs, as_date = TRUE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_logical(as_date, len = 1, any.missing = FALSE)

  dates <- get_service_period(gtfs)
  if (!as_date) dates <- format(dates, "%Y%m%d")

  return(dates)
}
