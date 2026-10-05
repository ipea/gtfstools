#' Filter GTFS object by `trip_id`
#'
#' Filters a GTFS object by `trip_id`s, keeping (or dropping) the relevant
#' entries in each file.
#'
#' @template gtfs
#' @param trip_id A character vector. The `trip_id`s used to filter the data.
#' @param keep A logical. Whether the entries related to the specified
#'   `trip_id`s should be kept or dropped (defaults to `TRUE`, which keeps the
#'   entries).
#'
#' @return The GTFS object passed to the `gtfs` parameter, after the filtering
#'   process.
#'
#' @family filtering functions
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#' trip_ids <- c("CPTM L07-0", "2002-10-0")
#'
#' object.size(gtfs)
#'
#' # keeps entries related to passed trip_ids
#' smaller_gtfs <- filter_by_trip_id(gtfs, trip_ids)
#' object.size(smaller_gtfs)
#'
#' # drops entries related to passed trip_ids
#' smaller_gtfs <- filter_by_trip_id(gtfs, trip_ids, keep = FALSE)
#' object.size(smaller_gtfs)
#'
#' @export
filter_by_trip_id <- function(gtfs, trip_id, keep = TRUE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, any.missing = FALSE)
  checkmate::assert_logical(keep, len = 1, any.missing = FALSE)

  `%ffilter%` <- `%chin%`
  if (!keep) `%ffilter%` <- Negate(`%chin%`)

  # 'trips', 'stop_times', 'frequencies' and 'transfers' can be filtered using
  # 'trip_id' itself, so `%ffilter%` is used. the other files depend on
  # relational associations with 'trip_id' that come from these 3 tables, so we
  # use %chin%

  # 'trips' (trip_id)

  gtfs <- filter_trips_from_trip_id(gtfs, trip_id, `%ffilter%`)

  # 'trips' allows us to filter by 'route_id', 'service_id' and 'shape_id'

  relevant_routes <- unique(gtfs$trips$route_id)
  relevant_services <- unique(gtfs$trips$service_id)
  relevant_shapes <- unique(gtfs$trips$shape_id)

  # 'shapes' (shape_id)

  gtfs <- filter_shapes_from_shape_id(gtfs, relevant_shapes, `%chin%`)

  # 'calendar' and 'calendar_dates' (service_id)

  gtfs <- filter_calendar_from_service_id(gtfs, relevant_services, `%chin%`)
  gtfs <- filter_calend_dates_from_service_id(gtfs, relevant_services, `%chin%`)

  # 'routes', 'fare_rules' and 'transfers' (route_id)
  #
  # we can use 'routes' to filter agency via routes -> agency_id, but we can
  # also use 'fare_rules' to filter it via fare_rules -> fare_id ->
  # fare_attributes -> agency_id.
  # so we create a 'relevant_agencies' vector that holds the relevant
  # agency_ids from both paths and use all of them to filter agency later.

  gtfs <- filter_transfers_from_route_id(gtfs, relevant_routes, `%chin%`)
  gtfs <- filter_routes_from_route_id(gtfs, relevant_routes, `%chin%`)
  gtfs <- filter_fare_rules_from_route_id(gtfs, relevant_routes, `%chin%`)
  relevant_agencies_from_routes <- unique(gtfs$routes$agency_id)

  # 'fare_rules' allows us to filter by 'fare_id'

  relevant_fares <- unique(gtfs$fare_rules$fare_id)

  # 'fare_attributes' (fare_id)

  gtfs <- filter_fare_attr_from_fare_id(gtfs, relevant_fares, `%chin%`)
  relevant_agencies_from_fare_attr <- unique(gtfs$fare_attributes$agency_id)

  # 'agency' (agency_id, that comes both from routes and fare_attributes)

  relevant_agencies <- c(
    relevant_agencies_from_routes,
    relevant_agencies_from_fare_attr
  )
  relevant_agencies <- unique(relevant_agencies)

  gtfs <- filter_agency_from_derived_agency_id(gtfs, relevant_agencies)

  # 'stop_times' (trip_id)

  gtfs <- filter_stop_times_from_trip_id(gtfs, trip_id, `%ffilter%`)

  # 'stop_times' allows us to filter by 'stop_id'
  # it's important to keep not only the stops that appear on stop_times, but
  # also their parent stops
  # TODO: also include their children

  relevant_stops <- get_stops_and_parents(gtfs)

  # 'stops', 'transfers' and 'pathways' (stop_id)

  gtfs <- filter_transfers_from_stop_id(gtfs, relevant_stops, `%chin%`)
  gtfs <- filter_pathways_from_stop_id(gtfs, relevant_stops, `%chin%`)
  gtfs <- filter_stops_from_stop_id(gtfs, relevant_stops, `%chin%`)

  # 'stops' allows us to filter by 'level_id' and 'zone_id'

  relevant_zones <- unique(gtfs$stops$zone_id)
  relevant_levels <- unique(gtfs$stops$level_id)

  # 'fare_rules' (zone_id)

  gtfs <- filter_fare_rules_from_zone_id(gtfs, relevant_zones, `%chin%`)

  # 'levels' (level_id)

  gtfs <- filter_levels_from_level_id(gtfs, relevant_levels, `%chin%`)

  # 'frequencies' (trip_id)

  gtfs <- filter_frequencies_from_trip_id(gtfs, trip_id, `%ffilter%`)

  # 'transfers' (trip_id)

  gtfs <- filter_transfers_from_trip_id(gtfs, trip_id, `%ffilter%`)

  return(gtfs)
}
