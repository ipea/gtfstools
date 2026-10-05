#' Get trip length
#'
#' Returns the length of each specified `trip_id`, based either on the `shapes`
#' or the `stop_times` file (or both).
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#'   length calculated If `NULL` (the default), the function calculates the
#'   length of each `trip_id` in the GTFS.
#' @param file A character vector specifying the file from which lengths should
#'   be calculated (either one of or both `shapes` and `stop_times`). If `NULL`
#'   (the default), the function attempts to calculate the lengths from both
#'   files, but only raises an error if none of the files exist.
#' @param unit A string representing the unit in which lengths are desired.
#'   Either `"km"` (the default) or `"m"`.
#' @param sort_sequence A logical specifying whether to sort shapes and
#'   timetables by `shape_pt_sequence` and `stop_sequence`, respectively.
#'   Defaults to `TRUE`. Sorting an already ordered table is cheap. Set to
#'   `FALSE` only if shapes and timetables are known to be ordered. Lengths
#'   calculated from trip trajectories generated with unordered sequences do
#'   not correctly depict the actual trip lengths.
#'
#' @return A `data.table` containing the length of each specified trip.
#'
#' @section Details:
#' Please check [get_trip_geometry()] documentation to understand how geometry
#' generation, and consequently length calculation, differs depending on the
#' chosen file.
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
#' trip_length <- get_trip_length(gtfs)
#' head(trip_length)
#'
#' # the above is identical to
#' trip_length <- get_trip_length(gtfs, file = c("shapes", "stop_times"))
#' head(trip_length)
#'
#' trip_ids <- c("CPTM L07-0", "2002-10-0")
#' trip_length <- get_trip_length(gtfs, trip_id = trip_ids)
#' trip_length
#'
#' @export
get_trip_length <- function(gtfs,
                            trip_id = NULL,
                            file = NULL,
                            unit = "km",
                            sort_sequence = TRUE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = c("km", "m")),
    combine = "and"
  )
  checkmate::assert_logical(sort_sequence, any.missing = FALSE, len = 1)

  checkmate::assert_character(file, null.ok = TRUE)
  if (!is.null(file)) {
    checkmate::assert_names(file, subset.of = c("shapes", "stop_times"))
  } else {
    file <- names(gtfs)
    file <- file[file %in% c("shapes", "stop_times")]

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

  if ("shapes" %in% file) {
    if (!is.null(trip_id)) {
      trips <- gtfs$trips[trip_id %chin% relevant_trips & shape_id != ""]
    } else {
      trips <- gtfs$trips[shape_id != ""]
    }

    relevant_shapes <- unique(trips$shape_id)

    # generate geometry and calculate the length of each unique shape_id
    # the condition for nrow == 0 prevents an sfheaders error

    shapes <- gtfs$shapes[shape_id %chin% relevant_shapes]

    if (sort_sequence) {
      shapes <- data.table::setorderv(
        shapes,
        c("shape_id", "shape_pt_sequence")
      )
    }

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
    shapes_length <- sf::st_length(shapes_sf)
    if (unit != "m") {
      shapes_length <- units::set_units(shapes_length, unit, mode = "standard")
    }
    shapes_length <- as.numeric(shapes_length)
    shapes_length_df <- data.table::data.table(
      shape_id = shapes_sf$shape_id,
      length = shapes_length
    )

    length_from_shapes <- trips[
      shapes_length_df,
      on = "shape_id",
      length := i.length
    ]
    length_from_shapes[, setdiff(names(trips), c("trip_id", "length")) := NULL]
    length_from_shapes[, origin_file := "shapes"]
  }

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

    # generate geometry; the condition for nrow == 0 prevents an sfheaders error

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
    stop_times_length <- sf::st_length(stop_times_sf)
    if (unit != "m") {
      stop_times_length <- units::set_units(
        stop_times_length,
        unit,
        mode = "standard"
      )
    }
    stop_times_length <- as.numeric(stop_times_length)
    length_from_stop_times <- data.table::data.table(
      trip_id = stop_times_sf$trip_id,
      length = stop_times_length,
      origin_file = rep("stop_times", length(stop_times_length))
    )
  }

  # tidy final object

  if (length(file) == 2) {
    length_df <- rbind(length_from_shapes, length_from_stop_times)
  } else {
    length_df <- get(paste0("length_from_", file))
  }

  return(length_df)
}
