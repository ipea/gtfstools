#' Filter a GTFS object using a `simple features` object (deprecated)
#'
#' @description
#' This function has been deprecated as of the current package version and will
#' be completely removed from version 2.0.0 onward. Please use
#' [filter_by_spatial_extent()] instead.
#'
#' Filters a GTFS object using the geometry of an `sf` object, keeping (or
#' dropping) entries related to shapes and trips selected through a spatial
#' operation.
#'
#' @template gtfs
#' @param geom An `sf` object. Describes the geometry used to filter the data.
#' @param spatial_operation A spatial operation function from the set of
#'   options listed in [geos_binary_pred][sf::geos_binary_pred] (check the
#'   [DE-I9M](https://en.wikipedia.org/wiki/DE-9IM) Wikipedia entry for the
#'   definition of each function). Defaults to `sf::st_intersects`, which tests
#'   if the shapes and trips have ANY intersection with the object specified in
#'   `geom`. Please note that `geom` is passed as the `x` argument of these
#'   functions.
#' @param keep A logical. Whether the entries related to the shapes and trips
#'   that cross through the given geometry should be kept or dropped (defaults
#'   to `TRUE`, which keeps the entries).
#'
#' @return The GTFS object passed to the `gtfs` parameter, after the filtering
#' process.
#'
#' @seealso [filter_by_spatial_extent()], which replaces this function.
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
#' smaller_gtfs <- filter_by_sf(gtfs, bbox)
#' object.size(smaller_gtfs)
#'
#' # drops entries that intersect with the specified polygon
#' smaller_gtfs <- filter_by_sf(gtfs, bbox, keep = FALSE)
#' object.size(smaller_gtfs)
#'
#' # uses a different function to filter the gtfs
#' smaller_gtfs <- filter_by_sf(gtfs, bbox, spatial_operation = sf::st_contains)
#' object.size(smaller_gtfs)
#'
#' @export
filter_by_sf <- function(gtfs,
                         geom,
                         spatial_operation = sf::st_intersects,
                         keep = TRUE) {
  filter_by_sf_deprecation_warning()

  filter_by_spatial_extent(gtfs, geom, spatial_operation, keep)
}

filter_by_sf_deprecation_warning <- function() {
  cli::cli_warn(
    class = "deprecated_filter_by_sf",
    message = c(
      "{.fun filter_by_sf} was deprecated in gtfstools 1.3.0.",
      "i" = "Please use {.fun filter_by_spatial_extent} instead.",
      "i" = paste0(
        "For backwards compatibility reasons, usage of {.fun filter_by_sf} is ",
        "still allowed as of the current version, but the function will be ",
        "removed from the package in version 2.0.0."
      )
    )
  )
}
