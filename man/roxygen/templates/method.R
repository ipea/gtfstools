#' @param method A string, either `"shapes"` (the default) or `"euclidean"`.
#'   `"shapes"` measures lengths along the trip's shape, described in the
#'   `shapes` table, while `"euclidean"` measures the straight-line
#'   (great-circle) distances between consecutive stops. If the GTFS object
#'   doesn't have a `shapes` table, or if its `trips` table doesn't have a
#'   `shape_id` column, `"euclidean"` is used instead, with a warning.
