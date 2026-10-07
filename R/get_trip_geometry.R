#' Get trip geometry
#'
#' Returns the geometry of each specified `trip_id`, from its first to its last
#' stop, either along the trip's shape or as straight lines between stops.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#'   geometries generated. If `NULL` (the default), the function generates
#'   geometries for every `trip_id` in the GTFS.
#' @param method A string, either `"shapes"` (the default) or `"euclidean"`.
#'   `"shapes"` returns the part of the trip's shape, described in the `shapes`
#'   table, between its first and last stops, while `"euclidean"` links the
#'   consecutive stops of the trip along straight lines. If the GTFS object
#'   doesn't have a `shapes` table, or if its `trips` table doesn't have a
#'   `shape_id` column, `"euclidean"` is used instead, with a warning.
#' @param crs The CRS of the resulting object, either as an EPSG code or as an
#'   `crs` object. Defaults to 4326 (WGS 84).
#' @param sort_sequence A logical specifying whether to sort timetables and
#'   shapes by `stop_sequence` and `shape_pt_sequence`, respectively. Defaults
#'   to `TRUE`. Set to `FALSE` only if these tables are known to be ordered.
#'   Geometries generated from unordered sequences do not correctly depict the
#'   trip trajectories.
#' @param file Deprecated. Use `method` instead (`file = "stop_times"`
#'   corresponds to `method = "euclidean"`).
#'
#' @return A `LINESTRING sf` with the `trip_id` and the `geometry` of each trip
#'   listed in `stop_times`.
#'
#' @section Details:
#' With `method = "shapes"`, the first and last stops of each trip are
#' projected onto its shape, as in [get_trip_length()], and the geometry is the
#' part of the shape between them. Thus, its length matches the length
#' returned by [get_trip_length()] (when this length is not `NA`, see below),
#' and the limitations described there apply. Trips whose stops are all
#' located at the same point of the shape get a zero-length geometry.
#' Use [convert_shapes_to_sf()] for the geometry of entire shapes.
#'
#' With `method = "euclidean"`, the geometry links the consecutive stops of
#' each trip along straight lines (stops' coordinates are retrieved from the
#' `stops` table), so its resolution tends to be much lower than that of the
#' geometry generated from the shapes. Trips with a single stop get a
#' single-point geometry.
#'
#' Both methods ignore stops with missing coordinates, or not listed in
#' `stops` (for which [get_trip_length()] returns `NA` lengths). Trips
#' without any stop with coordinates get an empty geometry, as do, with
#' `method = "shapes"`, trips with fewer than two stops with coordinates or
#' not linked to a shape with at least two distinct points (the
#' latter with a warning). Geometries along shapes that cross the antimeridian
#' are not handled correctly.
#'
#' @seealso [get_trip_length()], [convert_shapes_to_sf()]
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
#' # geometry along the shape from the first to the last stop of each trip
#' trip_geometry <- get_trip_geometry(gtfs)
#' head(trip_geometry)
#'
#' # straight lines between consecutive stops
#' trip_ids <- c("CPTM L07-0", "2002-10-0")
#' straight_geometry <- get_trip_geometry(
#'   gtfs,
#'   trip_id = trip_ids,
#'   method = "euclidean"
#' )
#' straight_geometry
#' plot(straight_geometry["trip_id"])
#'
#' @export
get_trip_geometry <- function(gtfs,
                              trip_id = NULL,
                              method = "shapes",
                              crs = 4326,
                              sort_sequence = TRUE,
                              file = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  if (!is.null(file)) {
    method <- map_deprecated_file(
      file,
      "get_trip_geometry",
      details = paste0(
        "Geometries are now trimmed to the first and last stop of each trip. ",
        "Use {.fun convert_shapes_to_sf} for the geometry of the entire shapes."
      )
    )
  }
  checkmate::assert(
    checkmate::check_string(method),
    checkmate::check_names(method, subset.of = c("shapes", "euclidean")),
    combine = "and"
  )
  checkmate::assert(
    checkmate::check_number(crs),
    checkmate::check_class(crs, "crs"),
    combine = "or"
  )
  checkmate::assert_logical(sort_sequence, any.missing = FALSE, len = 1)

  stop_times_cols <- c("trip_id", "stop_id")
  stop_times_classes <- c("character", "character")
  if (sort_sequence) {
    stop_times_cols <- c(stop_times_cols, "stop_sequence")
    stop_times_classes <- c(stop_times_classes, "integer")
  }
  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    stop_times_cols,
    stop_times_classes
  )
  gtfsio::assert_field_class(
    gtfs,
    "stops",
    c("stop_id", "stop_lat", "stop_lon"),
    c("character", "numeric", "numeric")
  )

  # geometries along the shapes require a 'shapes' table and a 'shape_id'
  # column in 'trips'. if any of them is missing, fall back to straight lines

  if (method == "shapes" && !has_shapes(gtfs)) {
    cli::cli_warn(
      c(
        paste0(
          "The GTFS object doesn't have a {.file shapes} table, or its ",
          "{.file trips} table doesn't have a {.field shape_id} column."
        ),
        "i" = paste0(
          "Generating {.val euclidean} geometries (straight lines between ",
          "consecutive stops) instead of geometries along the shapes."
        )
      ),
      class = "gtfstools_shapes_unavailable"
    )
    method <- "euclidean"
  }

  if (method == "shapes") {
    gtfsio::assert_field_class(
      gtfs,
      "trips",
      c("trip_id", "shape_id"),
      c("character", "character")
    )

    shapes_cols <- c("shape_id", "shape_pt_lat", "shape_pt_lon")
    shapes_classes <- c("character", "numeric", "numeric")
    if (sort_sequence) {
      shapes_cols <- c(shapes_cols, "shape_pt_sequence")
      shapes_classes <- c(shapes_classes, "integer")
    }
    gtfsio::assert_field_class(gtfs, "shapes", shapes_cols, shapes_classes)
  }

  st <- prepare_trip_stops(gtfs, trip_id, sort_sequence)

  trip_ids <- unique(st$trip_id)
  trip_index <- data.table::chmatch(st$trip_id, trip_ids)

  # geometries are only built for the trips that have one. 'built_trip' lists
  # these trips and 'built_idx' the built geometry of each of them, so that a
  # geometry shared by many trips is built and transformed only once

  if (method == "euclidean") {
    has_coords <- !is.na(st$stop_lat) & !is.na(st$stop_lon)
    built_trip <- unique(trip_index[has_coords])
    built_idx <- seq_along(built_trip)

    # 'st' is a new table, so the trip index can be added to it by reference.
    # it's only subset when some stops don't have coordinates (usually none)

    data.table::set(st, j = "trip_index", value = trip_index)
    stop_points <- if (all(has_coords)) st else st[has_coords]
    built <- build_linestrings(
      stop_points,
      "trip_index",
      "stop_lon",
      "stop_lat"
    )
  } else {
    position <- locate_stops_along_shapes(
      gtfs,
      st,
      st$stop_lat,
      st$stop_lon,
      sort_sequence
    )
    shape_points <- attr(position, "shape_points")

    # each trip is cut from its first to its last located stop. trips sharing
    # the same shape and the same cut (e.g. trips of the same pattern) share
    # the same geometry, so each cut is built only once

    is_located <- !is.na(position)
    located_trip <- trip_index[is_located]
    located_position <- position[is_located]
    is_first <- !duplicated(located_trip)
    is_last <- !duplicated(located_trip, fromLast = TRUE)

    built_trip <- located_trip[is_first]
    trip_cuts <- data.table::data.table(
      shape_id = shape_points$trip_shape_id[built_trip],
      from = located_position[is_first],
      to = located_position[is_last]
    )
    cuts <- unique(trip_cuts)
    built_idx <- cuts[trip_cuts, on = names(cuts), which = TRUE]

    built <- build_shape_cuts(cuts, shape_points)
  }

  if (crs != 4326 && crs != sf::st_crs(4326)) {
    built <- sf::st_transform(built, crs)
  }

  # trips without a built geometry get an empty one, appended after the built
  # geometries, so that the geometry of every trip is selected at once

  geometry_idx <- rep(length(built) + 1L, length(trip_ids))
  geometry_idx[built_trip] <- built_idx
  geometry <- sf::st_sfc(
    c(unclass(built), list(sf::st_linestring()))[geometry_idx],
    crs = sf::st_crs(built)
  )
  if (length(trip_ids) == 0) class(geometry)[1] <- "sfc_LINESTRING"

  trips_sf <- data.table::data.table(trip_id = trip_ids, geometry = geometry)
  trips_sf <- sf::st_as_sf(trips_sf)

  return(trips_sf)
}



#' Build the geometries of parts of shapes
#'
#' @param cuts A `data.table` with the `shape_id` of each part and the
#'   positions, in meters from the start of the shape, where it starts
#'   (`from`) and ends (`to`).
#' @param shape_points The `"shape_points"` attribute of the output of
#'   `locate_stops_along_shapes()`, on which the positions were measured.
#'
#' @return A `sfc_LINESTRING` in WGS 84 with the geometry of each part.
#'
#' @keywords internal
build_shape_cuts <- function(cuts, shape_points) {
  # cumulative distance of each point of the relevant shapes, calculated as in
  # rcpp_locate_stops_on_shape(). R's cumsum() accumulates in long double while
  # the C++ code accumulates in double, so the positions of the last stops may
  # slightly exceed the cumulative distance of the last shape point. hence the
  # interpolation factors are clamped to [0, 1] below

  if (nrow(cuts) == 0) return(build_linestrings(cuts, "shape_id"))

  relevant_shapes <- unique(cuts$shape_id)
  shape_rows <- shape_points$rows[relevant_shapes]
  rows <- unlist(shape_rows, use.names = FALSE)
  n_points <- length(rows)
  shape_group <- rep.int(seq_along(shape_rows), lengths(shape_rows))

  lat <- shape_points$shapes$shape_pt_lat[rows]
  lon <- shape_points$shapes$shape_pt_lon[rows]

  step <- rcpp_distance_haversine(
    c(lat[1L], lat[-n_points]),
    c(lon[1L], lon[-n_points]),
    lat,
    lon
  )
  step[!duplicated(shape_group)] <- 0
  cum <- unlist(lapply(split(step, shape_group), cumsum), use.names = FALSE)

  shape_start <- which(!duplicated(shape_group))
  shape_end <- c(shape_start[-1L] - 1L, n_points)
  cut_shape <- match(cuts$shape_id, relevant_shapes)

  # each part goes from the point at 'from' to the point at 'to', interpolated
  # along the shape, through the shape points in between ('inner' points,
  # whose cumulative distance is strictly between 'from' and 'to'). the shape
  # segments that contain 'from' and 'to' and the range of inner points are
  # found for all the parts of each shape at once. indices are global (into
  # 'cum', 'lat' and 'lon')

  n_cuts <- nrow(cuts)
  from_segment <- to_segment <- first_inner <- last_inner <- integer(n_cuts)

  for (cuts_k in split(seq_len(n_cuts), cut_shape)) {
    s <- cut_shape[cuts_k[1L]]
    offset <- shape_start[s] - 1L
    shape_cum <- cum[shape_start[s]:shape_end[s]]
    last_segment <- length(shape_cum) - 1L

    n_up_to_from <- findInterval(cuts$from[cuts_k], shape_cum)
    n_up_to_to <- findInterval(cuts$to[cuts_k], shape_cum)

    from_segment[cuts_k] <- offset + pmin(pmax(n_up_to_from, 1L), last_segment)
    to_segment[cuts_k] <- offset + pmin(pmax(n_up_to_to, 1L), last_segment)
    first_inner[cuts_k] <- offset + n_up_to_from + 1L
    last_inner[cuts_k] <- offset + findInterval(
      cuts$to[cuts_k],
      shape_cum,
      left.open = TRUE
    )
  }

  interpolate <- function(position, segment) {
    segment_length <- cum[segment + 1L] - cum[segment]
    fraction <- (position - cum[segment]) / segment_length
    fraction[!(segment_length > 0)] <- 0
    fraction <- pmin(pmax(fraction, 0), 1)

    list(
      lon = lon[segment] + fraction * (lon[segment + 1L] - lon[segment]),
      lat = lat[segment] + fraction * (lat[segment + 1L] - lat[segment])
    )
  }
  start_point <- interpolate(cuts$from, from_segment)
  end_point <- interpolate(cuts$to, to_segment)

  # the points of each part: its start point, its inner points and its end
  # point

  n_inner <- pmax(last_inner - first_inner + 1L, 0L)
  n_cut_points <- n_inner + 2L
  cut_id <- rep.int(seq_len(n_cuts), n_cut_points)
  point_position <- sequence(n_cut_points)
  is_start <- point_position == 1L
  is_end <- point_position == n_cut_points[cut_id]

  point_idx <- first_inner[cut_id] + point_position - 2L
  point_idx[is_start | is_end] <- NA_integer_

  cut_lon <- lon[point_idx]
  cut_lat <- lat[point_idx]
  cut_lon[is_start] <- start_point$lon
  cut_lat[is_start] <- start_point$lat
  cut_lon[is_end] <- end_point$lon
  cut_lat[is_end] <- end_point$lat

  cut_points <- data.table::data.table(
    cut = cut_id,
    lon = cut_lon,
    lat = cut_lat
  )

  return(build_linestrings(cut_points, "cut"))
}



#' Build linestrings from sequences of points
#'
#' @param points A `data.table` with the coordinates of each point and an
#'   integer column identifying the linestring of each point. The points of
#'   each linestring must be contiguous and the ids increasing.
#' @param id_col The name of the column that identifies the linestrings.
#' @param x_col,y_col The names of the columns with the longitude and the
#'   latitude of each point.
#'
#' @return A `sfc_LINESTRING` in WGS 84, with one linestring per id.
#'
#' @keywords internal
build_linestrings <- function(points, id_col, x_col = "lon", y_col = "lat") {
  # the condition for nrow == 0 prevents an sfheaders error

  if (nrow(points) == 0) {
    built <- sf::st_sfc(crs = 4326)
    class(built)[1] <- "sfc_LINESTRING"
    return(built)
  }

  built <- sfheaders::sfc_linestring(
    points,
    x = x_col,
    y = y_col,
    linestring_id = id_col
  )
  built <- sf::st_set_crs(built, 4326)

  return(built)
}
