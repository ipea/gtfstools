#' Get shape length
#'
#' Returns the length of each specified `shape_id`, from its first to its last
#' point.
#'
#' @template gtfs
#' @param shape_id A character vector including the `shape_id`s to have their
#'   length calculated. If `NULL` (the default), the function calculates the
#'   length of every `shape_id` in the GTFS.
#' @param unit A string representing the unit in which lengths are desired.
#'   Either `"km"` (the default) or `"m"`.
#'
#' @return A `data.table` with the `shape_id` and the `length` of each shape.
#'
#' @section Details:
#' The points of each shape are sorted by `shape_pt_sequence` before the length
#' is calculated. Lengths are great-circle distances calculated with the
#' haversine formula, on a sphere with the same radius used by `{s2}`
#' (6,371,010 meters), regardless of whether `sf::sf_use_s2()` is enabled.
#' Shapes with any point with missing coordinates have `NA` lengths.
#'
#' A trip usually travels only part of its shape, from its first to its last
#' stop. Use [get_trip_length()] to calculate the length of the trips.
#'
#' @seealso [get_trip_length()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' shape_length <- get_shape_length(gtfs)
#' head(shape_length)
#'
#' shape_length <- get_shape_length(gtfs, c("17846", "68962"), unit = "m")
#' shape_length
#'
#' @export
get_shape_length <- function(gtfs, shape_id = NULL, unit = "km") {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(shape_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = c("km", "m")),
    combine = "and"
  )

  shapes_cols <- c(
    "shape_id",
    "shape_pt_lat",
    "shape_pt_lon",
    "shape_pt_sequence"
  )
  gtfsio::assert_field_class(
    gtfs,
    "shapes",
    shapes_cols,
    c("character", "numeric", "numeric", "integer")
  )

  # select the relevant shapes rows into a new table, so the given gtfs is not
  # modified. the selection index is created outside of `[` so that
  # {data.table} doesn't add an index to the original table

  if (!is.null(shape_id)) {
    warn_missing_ids(shape_id, gtfs$shapes$shape_id, "shapes", "shape_id")
    is_relevant <- gtfs$shapes$shape_id %chin% shape_id
  } else {
    is_relevant <- rep(TRUE, nrow(gtfs$shapes))
  }

  shapes <- gtfs$shapes[is_relevant, .SD, .SDcols = shapes_cols]
  data.table::setorderv(shapes, c("shape_id", "shape_pt_sequence"))

  # distance from each point to the previous one. the first point of each shape
  # is 0 meters away from its "previous" point

  distance <- rcpp_distance_haversine(
    data.table::shift(shapes$shape_pt_lat),
    data.table::shift(shapes$shape_pt_lon),
    shapes$shape_pt_lat,
    shapes$shape_pt_lon
  )
  distance[!duplicated(shapes$shape_id)] <- 0
  if (unit == "km") distance <- distance / 1000

  lengths <- data.table::data.table(
    shape_id = shapes$shape_id,
    length = distance
  )
  lengths <- lengths[, .(length = sum(length, na.rm = FALSE)), by = shape_id]

  return(lengths[])
}
