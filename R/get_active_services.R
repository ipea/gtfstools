#' Get active services
#'
#' Returns the services that are active on the given dates.
#'
#' @template gtfs
#' @param date A `Date` vector (including `IDate`) or a character vector of
#'   dates in the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats.
#'
#' @return A `data.table` with the columns `date` (of class `Date`) and
#'   `service_id`, with one row for each service active on each of the given
#'   dates, sorted by `date` and then by `service_id` (in the C locale, so
#'   uppercase letters come before lowercase ones). Dates on which no service is
#'   active have no rows. `service_id` is never `NA`.
#'
#' @section Details:
#' A service is active on a date if its `calendar` entry spans the date and
#' flags its weekday, unless the date is removed from it in `calendar_dates`
#' (`exception_type` 2), or if the date is added to it in `calendar_dates`
#' (`exception_type` 1). An addition wins over a removal on the same date,
#' and either table may be missing. If the `trips` table has a `service_id`
#' field, services not used by any trip are not returned, as in
#' [get_dates()]. If no service is active, an empty table is returned without
#' a warning.
#'
#' @seealso [get_dates()], [filter_by_date()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' get_active_services(gtfs, "20060703")
#'
#' # several dates, also as Date objects. only the weekend service "WE" is
#' # returned, because the weekday service "WD" is not used by any trip
#' get_active_services(gtfs, as.Date(c("2006-07-01", "2006-07-05")))
#' @export
get_active_services <- function(gtfs, date) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  date <- parse_dates(date)

  active_services <- get_services_on_days(gtfs, unique(as.integer(date)))

  # services not used by any trip are dropped, as in get_service_period()

  if (gtfsio::check_field_exists(gtfs, "trips", "service_id")) {
    gtfsio::assert_field_class(gtfs, "trips", "service_id", "character")
    is_used <- active_services$service_id %chin% gtfs$trips$service_id
    active_services <- active_services[is_used]
  }

  active_services <- unique(active_services)
  data.table::setorderv(active_services, c("day", "service_id"))

  active_services <- active_services[
    ,
    .(date = as.Date(day, origin = "1970-01-01"), service_id)
  ]

  return(active_services)
}
