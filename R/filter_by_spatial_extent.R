#' Filter a GTFS object using a spatial extent
#'
#' Filters a GTFS object using a spatial extent (passed as an `sf` object),
#' keeping (or dropping) entries related to shapes and trips whose geometries
#' are selected through a specified spatial operation.
#'
#' @template gtfs
#' @param geom An `sf` object. Describes the spatial extent used to filter the
#'   data.
#' @param spatial_operation A spatial operation function from the set of
#'   options listed in [geos_binary_pred][sf::geos_binary_pred] (check the
#'   [DE-I9M](https://en.wikipedia.org/wiki/DE-9IM) Wikipedia entry for the
#'   definition of each function). Defaults to [`sf::st_intersects`], which
#'   tests if the shapes and trips have ANY intersection with the object
#'   specified in `geom`. Please note that `geom` is passed as the `x` argument
#'   of these functions.
#' @param keep A logical. Whether the entries related to the shapes and trips
#'   selected by the given spatial operation should be kept or dropped (defaults
#'   to `TRUE`, which keeps the entries).
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
#'
#' shape_id <- "68962"
#' shape_sf <- convert_shapes_to_sf(gtfs, shape_id)
#' bbox <- sf::st_bbox(shape_sf)
#' object.size(gtfs)
#'
#' # keeps entries that intersect with the specified polygon
#' smaller_gtfs <- filter_by_spatial_extent(gtfs, bbox)
#' object.size(smaller_gtfs)
#'
#' # drops entries that intersect with the specified polygon
#' smaller_gtfs <- filter_by_spatial_extent(gtfs, bbox, keep = FALSE)
#' object.size(smaller_gtfs)
#'
#' # uses a different function to filter the gtfs
#' smaller_gtfs <- filter_by_spatial_extent(
#'   gtfs,
#'   bbox,
#'   spatial_operation = sf::st_contains
#' )
#' object.size(smaller_gtfs)
#'
#' @export
filter_by_spatial_extent <- function(gtfs,
                                     geom,
                                     spatial_operation = sf::st_intersects,
                                     keep = TRUE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_logical(keep, len = 1)
  checkmate::assert(
    checkmate::check_class(geom, "sf"),
    checkmate::check_class(geom, "sfc"),
    checkmate::check_class(geom, "bbox")
  )
  assert_spatial_operation(spatial_operation)

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

  has_shapes <- gtfsio::check_file_exists(gtfs, "shapes")
  has_stop_times <- gtfsio::check_file_exists(gtfs, "stop_times")

  if (!has_shapes && !has_stop_times) {
    stop(
      "Could not conduct spatial operations with the provided GTFS object. ",
      "It must contain either a 'shapes' or a 'stop_times' table."
    )
  }

  # a trip is selected if either its shape or the path through its stops
  # satisfies the spatial operation. we gather the union of these trips and
  # filter the gtfs only once, so 'keep = FALSE' drops trips selected by either
  # of them

  relevant_trips <- character(0)

  if (has_shapes) {
    shapes_sf <- convert_shapes_to_sf(gtfs)
    did_succeed_operation <- spatial_operation(geom, shapes_sf, sparse = FALSE)

    relevant_shapes <- shapes_sf$shape_id[did_succeed_operation]
    is_relevant <- gtfs$trips$shape_id %chin% relevant_shapes
    relevant_trips <- c(relevant_trips, gtfs$trips$trip_id[is_relevant])
  }

  if (has_stop_times) {
    # trips already selected by their shapes don't need to be tested again. the
    # logical index is created outside of `[` so that {data.table} doesn't add
    # an index to the original stop_times table

    to_test <- !(gtfs$stop_times$trip_id %chin% relevant_trips)
    untested_gtfs <- gtfs
    untested_gtfs$stop_times <- gtfs$stop_times[to_test]

    trips_sf <- get_trip_geometry(untested_gtfs, file = "stop_times")
    did_succeed_operation <- spatial_operation(geom, trips_sf, sparse = FALSE)

    relevant_trips <- c(relevant_trips, trips_sf$trip_id[did_succeed_operation])
  }

  result_gtfs <- filter_by_trip_id(gtfs, unique(relevant_trips), keep)

  return(result_gtfs)
}

assert_spatial_operation <- function(spatial_operation) {
  available_operations <- list(
    intersects = sf::st_intersects,
    disjoint = sf::st_disjoint,
    touches = sf::st_touches,
    crosses = sf::st_crosses,
    within = sf::st_within,
    contains = sf::st_contains,
    contains_properly = sf::st_contains_properly,
    overlaps = sf::st_overlaps,
    equals = sf::st_equals,
    covers = sf::st_covers,
    covered_by = sf::st_covered_by,
    equals_exact = sf::st_equals_exact,
    is_within_distance = sf::st_is_within_distance
  )

  checkmate::assert_class(spatial_operation, "function")

  operation_matches <- vapply(
    available_operations,
    FUN.VALUE = logical(1),
    FUN = function(op) identical(op, spatial_operation)
  )

  if (!any(operation_matches)) {
    function_listing <- paste0(
      "'sf::st_", names(available_operations), "'",
      collapse = ", "
    )

    stop(
      "Assertion on 'spatial_operation' failed: ",
      "Must be a geometric binary predicate listed in '?sf::geos_binary_pred' ",
      "- i.e. one of ", function_listing, "."
    )
  }

  return(invisible(TRUE))
}
