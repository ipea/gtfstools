#' Get trip geometry
#'
#' Returns the geometry of each specified `trip_id`, based either on the
#' `shapes` or the `stop_times` file (or both).
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#'   geometries generated. If `NULL` (the default), the function generates
#'   geometries for every `trip_id` in the GTFS.
#' @param file A character vector specifying the file from which geometries
#'   should be generated (either one of or both `shapes` and `stop_times`). If
#'   `NULL` (the default), the function attemps to generate the geometries from
#'   both files, but only raises an error if none of the files exist.
#' @param crs The CRS of the resulting object, either as an EPSG code or as an
#'   `crs` object. Defaults to 4326 (WGS 84).
#' @param sort_sequence A logical specifying whether to sort shapes and
#'   timetables by `shape_pt_sequence` and `stop_sequence`, respectively.
#'   Defaults to `TRUE`. Sorting an already ordered table is cheap. Set to
#'   `FALSE` only if shapes and timetables are known to be ordered. Geometries
#'   generated from unordered sequences do not correctly depict the trip
#'   trajectories.
#'
#' @return A `LINESTRING sf`.
#'
#' @section Details:
#' The geometry generation works differently for the two files. In the case of
#' `shapes`, the shape as described in the text file is converted to an `sf`
#' object. For `stop_times` the geometry is the result of linking subsequent
#' stops along a straight line (stops' coordinates are retrieved from the
#' `stops` file). Thus, the resolution of the geometry when generated with
#' `shapes` tends to be much higher than when created with `stop_times`.
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#'
#' gtfs <- read_gtfs(data_path)
#'
#' trip_geometry <- get_trip_geometry(gtfs)
#' head(trip_geometry)
#'
#' # the above is identical to
#' trip_geometry <- get_trip_geometry(gtfs, file = c("shapes", "stop_times"))
#' head(trip_geometry)
#'
#' trip_ids <- c("CPTM L07-0", "2002-10-0")
#' trip_geometry <- get_trip_geometry(gtfs, trip_id = trip_ids)
#' trip_geometry
#' plot(trip_geometry["origin_file"])
#'
#' @export
get_trip_geometry <- function(gtfs,
                              trip_id = NULL,
                              file = NULL,
                              crs = 4326,
                              sort_sequence = TRUE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_number(crs),
    checkmate::check_class(crs, "crs"),
    combine = "or"
  )
  checkmate::assert_logical(sort_sequence, any.missing = FALSE, len = 1)

  checkmate::assert_character(file, null.ok = TRUE)
  if (!is.null(file)) {
    checkmate::assert_names(file, subset.of = c("shapes", "stop_times"))
  } else {
    file <- names(gtfs)
    file <- file[file %chin% c("shapes", "stop_times")]

    if (identical(file, character(0))) {
      stop(
        "The GTFS object must have either a 'shapes' or a 'stop_times' table."
      )
    }
  }

  if ("shapes" %in% file) {
    gtfsio::assert_field_class(
      gtfs,
      "trips",
      c("trip_id", "shape_id"),
      rep("character", 2)
    )

    shp_req_cols <- c("shape_id", "shape_pt_lat", "shape_pt_lon")
    shp_req_classes <- c("character", "numeric", "numeric")
    if (sort_sequence) {
      shp_req_cols <- c(shp_req_cols, "shape_pt_sequence")
      shp_req_classes <- c(shp_req_classes, "integer")
    }
    gtfsio::assert_field_class(gtfs, "shapes", shp_req_cols, shp_req_classes)
  }

  if ("stop_times" %in% file) {
    gtfsio::assert_field_class(gtfs, "trips", "trip_id", "character")

    st_req_cols <- c("trip_id", "stop_id")
    st_req_classes <- c("character", "character")
    if (sort_sequence) {
      st_req_cols <- c(st_req_cols, "stop_sequence")
      st_req_classes <- c(st_req_classes, "integer")
    }
    gtfsio::assert_field_class(gtfs, "stop_times", st_req_cols, st_req_classes)

    gtfsio::assert_field_class(
      gtfs,
      "stops",
      c("stop_id", "stop_lat", "stop_lon"),
      c("character", "numeric", "numeric")
    )
  }

  # select trip_ids to get geometry of and raise warning if a given trip_id
  # doesn't exist in trips

  if (!is.null(trip_id)) {
    relevant_trips <- trip_id

    invalid_trip_id <- trip_id[! trip_id %chin% unique(gtfs$trips$trip_id)]

    if (!identical(invalid_trip_id, character(0))) {
      warning(
        "'trips' doesn't contain the following trip_id(s): ",
        paste0("'", invalid_trip_id, "'", collapse = ", ")
      )
    }
  }

  # create linestrings from shapes

  if ("shapes" %in% file) {
    if (!is.null(trip_id)) {
      trips <- gtfs$trips[trip_id %chin% relevant_trips & shape_id != ""]
    } else {
      trips <- gtfs$trips[shape_id != ""]
    }

    relevant_shapes <- unique(trips$shape_id)

    shapes <- gtfs$shapes[shape_id %chin% relevant_shapes]

    if (sort_sequence) {
      shapes <- data.table::setorderv(
        shapes,
        c("shape_id", "shape_pt_sequence")
      )
    }

    # the condition for nrow == 0 prevents an sfheaders error

    if (nrow(shapes) == 0) {
      empty_linestring <- sf::st_sfc()
      class(empty_linestring)[1] <- "sfc_LINESTRING"

      shapes_sf <- sf::st_sf(
        shape_id = character(),
        geometry = empty_linestring,
        stringsAsFactors = FALSE
      )
    } else {
      shapes_sf <- sfheaders::sf_linestring(
        shapes,
        x = "shape_pt_lon",
        y = "shape_pt_lat",
        linestring_id = "shape_id"
      )
    }

    shapes_sf <- sf::st_set_crs(shapes_sf, 4326)

    # transform each shape before joining it to the trips, otherwise a shape
    # used by many trips would be transformed once per trip

    if (crs != 4326 && crs != sf::st_crs(4326)) {
      shapes_sf <- sf::st_transform(shapes_sf, crs)
    }

    shapes_sf <- data.table::setDT(shapes_sf)[trips, on = "shape_id"]
    shapes_sf[, origin_file := "shapes"]

    cols_to_remove <- setdiff(
      names(shapes_sf),
      c("trip_id", "origin_file", "geometry")
    )
    shapes_sf <- shapes_sf[, eval(cols_to_remove) := NULL]
  }

  # create linestrings from stop_times

  if ("stop_times" %in% file) {
    if (!is.null(trip_id)) {
      stop_times <- gtfs$stop_times[trip_id %chin% relevant_trips]
    } else {
      stop_times <- gtfs$stop_times
    }

    if (sort_sequence) {
      if (is.null(trip_id)) stop_times <- data.table::copy(stop_times)
      stop_times <- data.table::setorderv(
        stop_times,
        c("trip_id", "stop_sequence")
      )
    }

    # the condition for nrow == 0 prevents an sfheaders error

    stop_times[
      gtfs$stops,
      on = "stop_id",
      `:=`(stop_lat = i.stop_lat, stop_lon = i.stop_lon)
    ]

    if (nrow(stop_times) == 0) {
      empty_linestring <- sf::st_sfc()
      class(empty_linestring)[1] <- "sfc_LINESTRING"

      stop_times_sf <- sf::st_sf(
        trip_id = character(),
        geometry = empty_linestring,
        stringsAsFactors = FALSE
      )
    } else {
      stop_times_sf <- sfheaders::sf_linestring(
        stop_times,
        x = "stop_lon",
        y = "stop_lat",
        linestring_id = "trip_id"
      )
    }

    # joining stops to stop_times may change the original gtfs if stop_times
    # didn't create a copy of gtfs$stop_times before, so we have to cleanup the
    # table

    if (gtfsio::check_field_exists(gtfs, "stop_times", "stop_lat")) {
      gtfs$stop_times[, c("stop_lat", "stop_lon") := NULL]
    }

    stop_times_sf <- sf::st_set_crs(stop_times_sf, 4326)

    if (crs != 4326 && crs != sf::st_crs(4326)) {
      stop_times_sf <- sf::st_transform(stop_times_sf, crs)
    }

    data.table::setDT(stop_times_sf)
    stop_times_sf[, origin_file := "stop_times"]
  }

  # tidy final object

  if (length(file) == 2) {
    final_sf <- rbind(shapes_sf, stop_times_sf)
  } else {
    final_sf <- get(paste0(file, "_sf"))
  }

  data.table::setcolorder(final_sf, c("trip_id", "origin_file", "geometry"))
  final_sf <- sf::st_as_sf(final_sf)

  return(final_sf)
}
