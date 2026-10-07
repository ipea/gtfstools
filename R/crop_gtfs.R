crop_gtfs <- function(gtfs,
                      spatial_extent,
                      keep = TRUE,
                      preserve_stops_hierarchy = TRUE,
                      include_parents = TRUE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_logical(keep, len = 1)
  checkmate::assert(
    checkmate::check_class(geom, "sf"),
    checkmate::check_class(geom, "sfc"),
    checkmate::check_class(geom, "bbox")
  )

  gtfsio::assert_field_class(
    gtfs,
    "stops",
    c("stop_id", "stop_lon", "stop_lat"),
    c("character", "numeric", "numeric")
  )

  # convert 'geom' to polygon if a bounding box was given

  if (inherits(geom, "bbox")) geom <- sf::st_buffer(sf::st_as_sfc(geom), 0)

  if (sf::st_crs(geom) != sf::st_crs(4326)) {
    stop("'geom' CRS must be WGS 84 (EPSG 4326).")
  }

  if (
    (inherits(geom, "sf") && nrow(geom) > 1) ||
      (inherits(geom, "sfc") && length(geom) > 1)
  ) {
    geom <- sf::st_union(geom)
  }

  # TODO: crop shapes and then substitute the shapes of the filtered gtfs with
  # the cropped shapes. we probably want to keep every shape that is contained
  # inside the spatial extent, even if they're not linked to any trips/stops

  stops_sf <- convert_stops_to_sf(gtfs)
  did_succeed_operation <- sf::st_intersects(geom, stops_sf, sparse = FALSE)

  stops_sf <- stops_sf[did_succeed_operation, ]

  relevant_stops <- stops_sf$stop_id

  gtfs <- filter_by_stop_id(
    gtfs,
    relevant_stops,
    include_children = ifelse(preserve_stops_hierarchy, TRUE, FALSE),
    include_parents = ifelse(preserve_stops_hierarchy, TRUE, FALSE)
  )

  return(gtfs)
}
