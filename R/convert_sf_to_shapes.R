#' Convert a simple feature object into a `shapes` table
#'
#' Converts a `LINESTRING sf` object into a GTFS `shapes` table.
#'
#' @param sf_shapes A `LINESTRING sf` associating each `shape_id`s to a
#'   geometry. This object must use CRS WGS 84 (EPSG code 4326).
#' @param shape_id A character vector specifying the `shape_id`s to be
#'   converted. If `NULL` (the default), all shapes are converted.
#' @param calculate_distance A logical. Whether to calculate and populate the
#'   `shape_dist_traveled` column. This column is used to describe the distance
#'   along the shape from each one of its points to its first point, in meters.
#'   Distances are great-circle distances on a sphere with the same radius used
#'   by `{s2}` (6,371,010 meters), regardless of whether `sf::sf_use_s2()` is
#'   enabled. Defaults to `TRUE`.
#'
#' @return A `data.table` representing a GTFS `shapes` table.
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # first converting existing shapes table into a sf object
#' shapes_sf <- convert_shapes_to_sf(gtfs)
#' head(shapes_sf)
#'
#' # by default converts all shapes
#' result <- convert_sf_to_shapes(shapes_sf)
#' result
#'
#' # shape_id argument controls which shapes are converted
#' result <- convert_sf_to_shapes(shapes_sf, shape_id = c("17846", "17847"))
#' result
#'
#' # calculate_distance argument controls whether to calculate
#' # shape_dist_traveled or not
#' result <- convert_sf_to_shapes(shapes_sf, calculate_distance = TRUE)
#' result
#'
#' @export
convert_sf_to_shapes <- function(sf_shapes,
                                 shape_id = NULL,
                                 calculate_distance = TRUE) {
  assert_linestring_sf(sf_shapes)
  checkmate::assert_character(shape_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_logical(calculate_distance, any.missing = FALSE, len = 1)

  if (!is.null(shape_id)) {
    relevant_shapes <- shape_id

    invalid_shape_id <- shape_id[! shape_id %chin% sf_shapes$shape_id]

    if (!identical(invalid_shape_id, character(0))) {
      warning(
        "'sf_shapes' doesn't contain the following shape_id(s): ",
        paste0("'", invalid_shape_id, "'", collapse = ", ")
      )
    }

    sf_shapes <- subset(sf_shapes, shape_id %chin% relevant_shapes)
  }

  # sf_to_df() reads the vertices of the linestrings directly, without casting
  # them to points first

  if (nrow(sf_shapes) > 0) {
    shapes <- sfheaders::sf_to_df(sf_shapes, fill = TRUE)

    data.table::setDT(shapes)
    data.table::setattr(shapes, "sfc_columns", NULL)
    shapes[, c("sfg_id", "linestring_id") := NULL]
  } else {
    sf::st_geometry(sf_shapes) <- NULL
    shapes <- sf_shapes

    data.table::setDT(shapes)
    shapes[, c("x", "y") := numeric(0)]
  }

  if (calculate_distance) {
    shapes <- calculate_shape_dist_traveled(shapes)
  }

  data.table::setnames(
    shapes,
    old = c("x", "y"),
    new = c("shape_pt_lon", "shape_pt_lat")
  )

  shapes[, shape_pt_sequence := seq_len(.N), by = shape_id]

  return(shapes[])
}



calculate_shape_dist_traveled <- function(shapes) {
  # distance from each point to the previous one, on the same sphere used by
  # {s2}. the first point of each shape is 0 meters away from its "previous"
  # point

  distance_to_prev_point <- rcpp_distance_haversine(
    data.table::shift(shapes$y),
    data.table::shift(shapes$x),
    shapes$y,
    shapes$x
  )
  distance_to_prev_point[!duplicated(shapes$shape_id)] <- 0

  shapes[
    ,
    shape_dist_traveled := cumsum(distance_to_prev_point[.I]),
    by = shape_id
  ]

  # shape_dist_traveled goes before the coordinates, as in the previous
  # implementation

  data.table::setcolorder(
    shapes,
    c(setdiff(names(shapes), c("x", "y")), "x", "y")
  )

  return(shapes)
}



assert_linestring_sf <- function(x) {
  checkmate::assert_class(x, "sf", .var.name = "sf_shapes")

  geom_type <- as.character(sf::st_geometry_type(x, by_geometry = FALSE))

  if (geom_type != "LINESTRING" && nrow(x) > 0) {
    stop(
      "Assertion on 'sf_shapes' failed: Must be a 'LINESTRING sf', but it's a ",
      "'", geom_type, " sf'."
    )
  }

  if (sf::st_crs(x) != sf::st_crs(4326)) {
    stop("Assertion on 'sf_shapes' failed: CRS must be WGS 84 (EPSG 4326).")
  }

  return(invisible(TRUE))
}
