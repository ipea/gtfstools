#' Convert `stops` table to simple feature object
#'
#' Converts the `stops` table to a `POINT sf` object.
#'
#' @template gtfs
#' @param stop_id A character vector including the `stop_id`s to be converted.
#'   If `NULL` (the default), all stops are converted.
#' @param crs The CRS of the resulting object, either as an EPSG code or as an
#'   `crs` object. Defaults to 4326 (WGS 84).
#'
#' @return A `POINT sf` object.
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' # read gtfs
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' stops_sf <- convert_stops_to_sf(gtfs)
#' head(stops_sf)
#'
#' stops_sf <- convert_stops_to_sf(gtfs, stop_id = "18848")
#' stops_sf
#'
#' @export
convert_stops_to_sf <- function(gtfs, stop_id = NULL, crs = 4326) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(stop_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_number(crs),
    checkmate::check_class(crs, "crs"),
    combine = "or"
  )

  gtfsio::assert_field_class(
    gtfs,
    "stops",
    c("stop_id", "stop_lon", "stop_lat"),
    c("character", "numeric", "numeric")
  )

  # select relevant stop_ids
  if (!is.null(stop_id)) {
    relevant_stops <- stop_id
  } else {
    relevant_stops <- unique(gtfs$stops$stop_id)
  }

  # raise warning/error if given 'stop_id's don't exist in 'stops'
  if (!is.null(stop_id)) {
    warn_missing_ids(stop_id, gtfs$stops$stop_id, "stops", "stop_id")
  }

  # filter 'stops' table and create sf from it

  stops <- gtfs$stops[stop_id %chin% relevant_stops]

  if (nrow(stops) == 0) {
    empty_point <- sf::st_sfc()
    class(empty_point)[1] <- "sfc_POINT"

    stops_sf <- stops[0]
    stops_sf[, c("stop_lat", "stop_lon") := NULL]
    stops_sf <- sf::st_sf(
      stops_sf,
      geometry = empty_point,
      stringsAsFactors = FALSE
    )
  } else {
    stops_sf <- sfheaders::sf_point(
      stops,
      x = "stop_lon",
      y = "stop_lat",
      keep = TRUE
    )
  }

  stops_sf <- sf::st_set_crs(stops_sf, 4326)

  # transform crs from 4326 to the one passed to 'crs'
  if (crs != 4326 && crs != sf::st_crs(4326)) {
    stops_sf <- sf::st_transform(stops_sf, crs)
  }

  return(stops_sf)

}
