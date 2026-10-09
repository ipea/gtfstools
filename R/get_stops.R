#' Get stops
#'
#' Returns the stops visited by the given trips and/or routes.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s whose stops
#'   should be returned. If `NULL` (the default), all trips are considered. An
#'   empty vector selects no trip.
#' @param route_id A character vector including the `route_id`s whose stops
#'   should be returned. If `NULL` (the default), all routes are considered.
#'   An empty vector selects no route.
#'
#' @return A `data.table` with the entries of the `stops` table that are
#'   visited by the selected trips, with all its columns and in its original
#'   order.
#'
#' @section Details:
#' A trip is selected if it is listed in `trip_id` (when given) and belongs to
#' one of the routes listed in `route_id` (when given), so when both are given
#' only the trips that satisfy both are selected. When `route_id` is given,
#' trips not listed in the `trips` table can't be matched to a route and are
#' not selected. Ids not found in the feed raise a warning.
#'
#' Only the stops listed in the `stop_times` entries of the selected trips are
#' returned, so their parent stations, entrances, etc. are not. Please use
#' [get_parent_station()] and [get_children_stops()] to get these. Stops listed
#' in `stop_times` but not in `stops` are not returned.
#'
#' @seealso [get_parent_station()], [get_children_stops()],
#'   [filter_by_trip_id()], [filter_by_route_id()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # stops visited by a trip
#' stops <- get_stops(gtfs, trip_id = "CPTM L07-0")
#' head(stops)
#'
#' # stops visited by the trips of a route
#' stops <- get_stops(gtfs, route_id = "CPTM L07")
#' head(stops)
#'
#' # stops visited by any trip
#' stops <- get_stops(gtfs)
#' nrow(stops)
#' @export
get_stops <- function(gtfs, trip_id = NULL, route_id = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_character(route_id, null.ok = TRUE, any.missing = FALSE)

  gtfsio::assert_field_class(gtfs, "stops", "stop_id", "character")
  gtfsio::assert_field_class(gtfs, "stop_times", "stop_id", "character")

  if (!is.null(trip_id) || !is.null(route_id)) {
    gtfsio::assert_field_class(gtfs, "stop_times", "trip_id", "character")
  }

  # 'is_selected' flags the stop_times entries of the selected trips, and each
  # filter narrows it down. it stays NULL when all trips are selected, so that
  # the stop_id column isn't copied

  is_selected <- NULL

  if (!is.null(trip_id)) {
    is_selected <- gtfs$stop_times$trip_id %chin% trip_id
    invalid_trip_id <- unique(
      trip_id[! trip_id %chin% gtfs$stop_times$trip_id[is_selected]]
    )

    if (length(invalid_trip_id) > 0) {
      cli::cli_warn(
        paste0(
          "{.file stop_times} doesn't contain the following trip_id{?s}: ",
          "{.val {invalid_trip_id}}."
        ),
        class = "gtfstools_invalid_trip_id"
      )
    }
  }

  if (!is.null(route_id)) {
    gtfsio::assert_field_class(
      gtfs,
      "trips",
      c("trip_id", "route_id"),
      rep("character", 2)
    )

    invalid_route_id <- unique(
      route_id[! route_id %chin% gtfs$trips$route_id]
    )

    if (length(invalid_route_id) > 0) {
      cli::cli_warn(
        paste0(
          "{.file trips} doesn't contain the following route_id{?s}: ",
          "{.val {invalid_route_id}}."
        ),
        class = "gtfstools_invalid_route_id"
      )
    }

    route_trips <- gtfs$trips$trip_id[gtfs$trips$route_id %chin% route_id]
    route_trips <- route_trips[!is.na(route_trips)]
    is_route_trip <- gtfs$stop_times$trip_id %chin% route_trips

    if (is.null(is_selected)) {
      is_selected <- is_route_trip
    } else {
      is_selected <- is_selected & is_route_trip
    }
  }

  visited_stops <- gtfs$stop_times$stop_id
  if (!is.null(is_selected)) visited_stops <- visited_stops[is_selected]

  # a logical vector is used in i, instead of an expression, so that columns
  # of 'stops' can't be mistaken for local variables. NA stop_ids are excluded
  # on the 'stops' side, which is usually much smaller than 'stop_times'

  is_visited <- gtfs$stops$stop_id %chin% visited_stops &
    !is.na(gtfs$stops$stop_id)
  stops <- gtfs$stops[is_visited]

  return(stops)
}
