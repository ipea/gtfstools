#' Get vehicle-miles travelled
#'
#' Returns the vehicle-miles travelled (VMT) by each specified `route_id`:
#' the length of each of its trips, counted once for every departure of the
#' trip on every day on which its service runs. VMT can be restricted to some
#' dates and to a time of day.
#'
#' @inheritParams get_vkt
#'
#' @return A `data.table` with the columns `route_id`, `n_days` (the number of
#'   counted days on which at least one counted departure of the route runs),
#'   `vmt` (the vehicle-miles travelled on these days) and `vmt_daily_mean`
#'   (`vmt` divided by `n_days`, in miles per day), sorted by `route_id`.
#'   Routes without any departure on the counted days (and within the time of
#'   day) are not included.
#'
#' @section Details:
#' The VMT is the vehicle-kilometres travelled calculated by [get_vkt()],
#' converted to international miles (1 mile = 1.609344 km). See [get_vkt()]
#' for how trips, departures, days and trip lengths are counted, and how
#' times after midnight written as early morning times are fixed.
#'
#' @seealso [get_vkt()], [get_route_frequency()], [get_trip_length()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # VMT of every route over every day of the feed's calendar
#' vmt <- get_vmt(gtfs)
#' head(vmt)
#'
#' # VMT of two routes in the morning peak of a single day
#' get_vmt(
#'   gtfs,
#'   route_id = c("CPTM L07", "2002-10"),
#'   date = "2019-03-04",
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#'
#' @export
get_vmt <- function(
  gtfs,
  route_id = NULL,
  date = NULL,
  from = NULL,
  to = NULL
) {
  vkt <- get_vkt(
    gtfs = gtfs,
    route_id = route_id,
    date = date,
    from = from,
    to = to
  )

  # convert kilometres to international miles

  vmt <- data.table::data.table(
    route_id = vkt$route_id,
    n_days = vkt$n_days,
    vmt = vkt$vkt / km_per_mile,
    vmt_daily_mean = vkt$vkt_daily_mean / km_per_mile
  )

  return(vmt)
}
