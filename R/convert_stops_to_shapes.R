#' Convert stops into shapes
#'
#' Creates shapes for the given trips, linking their consecutive stops along
#' straight lines, and assigns them to the trips. Useful for feeds without
#' shapes, or in which some trips are not linked to a shape.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to get new
#'   shapes, which replace the shapes they are currently linked to. If `NULL`
#'   (the default), only the trips that are not linked to a usable shape get
#'   new shapes (see details).
#'
#' @return The GTFS object passed to the `gtfs` parameter, with the new shapes
#'   added to the `shapes` table (created if needed) and assigned to the trips
#'   in the `trips` table.
#'
#' @section Details:
#' The shape of a trip links its stops, in `stop_sequence` order, along
#' straight lines. Stops without coordinates, or not listed in `stops`, are
#' skipped. Trips that visit the same sequence of stops share the same shape.
#' The new shapes get new `shape_id`s (`"stops_shape_1"`, `"stops_shape_2"`,
#' etc.), different from any `shape_id` already listed in `shapes` or `trips`.
#' Their `shape_dist_traveled` is not calculated, because the distance unit
#' used by the feed is unknown, and the `shape_dist_traveled` of the
#' `stop_times` entries of the trips that get new shapes, if present, is set
#' to `NA`. Shapes no longer used by any trip are kept (please use
#' [remove_unused_ids()] to remove them).
#'
#' A shape is usable if it has at least two distinct points with coordinates.
#' With `trip_id = NULL`, the trips that get new shapes are those not linked
#' to a `shape_id`, or linked to a `shape_id` that is not listed in `shapes`
#' or whose shape is not usable (all trips, if the feed doesn't have a
#' `shapes` table). These are the trips that [get_trip_length()] and
#' [get_trip_geometry()] can't measure along a shape.
#'
#' Trips with fewer than two distinct stops with coordinates, or without
#' `stop_times` entries, can't get a usable shape, so they keep their current
#' `shape_id`, with a warning.
#'
#' @seealso [get_trip_geometry()], [convert_sf_to_shapes()],
#'   [remove_unused_ids()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # a feed without shapes gets one shape for each sequence of stops
#' gtfs$shapes <- NULL
#' new_gtfs <- convert_stops_to_shapes(gtfs)
#' head(new_gtfs$shapes)
#' head(new_gtfs$trips[, c("trip_id", "shape_id")])
#' @export
convert_stops_to_shapes <- function(gtfs, trip_id = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)

  gtfsio::assert_field_class(gtfs, "trips", "trip_id", "character")
  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "stop_id", "stop_sequence"),
    c("character", "character", "integer")
  )
  gtfsio::assert_field_class(
    gtfs,
    "stops",
    c("stop_id", "stop_lat", "stop_lon"),
    c("character", "numeric", "numeric")
  )

  has_shape_id <- gtfsio::check_field_exists(gtfs, "trips", "shape_id")
  if (has_shape_id) {
    gtfsio::assert_field_class(gtfs, "trips", "shape_id", "character")
  }

  # the classes of the shapes columns are checked so that adding the new
  # shapes can't coerce them

  has_shapes <- gtfsio::check_file_exists(gtfs, "shapes")
  if (has_shapes) {
    gtfsio::assert_field_class(
      gtfs,
      "shapes",
      c("shape_id", "shape_pt_lat", "shape_pt_lon", "shape_pt_sequence"),
      c("character", "numeric", "numeric", "integer")
    )
  }

  # the trips that get new shapes: the given ones, or those not linked to a
  # usable shape

  if (is.null(trip_id)) {
    trip_shape_id <- rep(NA_character_, nrow(gtfs$trips))
    if (has_shape_id) trip_shape_id <- gtfs$trips$shape_id

    usable_shapes <- character(0)
    if (has_shapes) usable_shapes <- get_usable_shapes(gtfs$shapes)

    target_trips <- gtfs$trips$trip_id[!trip_shape_id %chin% usable_shapes]
  } else {
    trip_id <- unique(trip_id)
    invalid_trip_id <- trip_id[! trip_id %chin% gtfs$trips$trip_id]

    if (length(invalid_trip_id) > 0) {
      cli::cli_warn(
        paste0(
          "{.file trips} doesn't contain the following trip_id{?s}: ",
          "{.val {invalid_trip_id}}."
        ),
        class = "gtfstools_invalid_trip_id"
      )
    }

    target_trips <- setdiff(trip_id, invalid_trip_id)
  }

  target_trips <- unique(target_trips[!is.na(target_trips)])
  if (length(target_trips) == 0) return(gtfs)

  # the stops of each target trip, in stop_sequence order. only trips listed in
  # stop_times are passed, so that prepare_trip_stops() doesn't warn about the
  # others (they are listed in the warning below instead)

  st <- prepare_trip_stops(
    gtfs,
    target_trips[target_trips %chin% gtfs$stop_times$trip_id],
    sort_sequence = TRUE
  )

  has_coords <- !is.na(st$stop_lat) & !is.na(st$stop_lon)
  if (!all(has_coords)) st <- st[has_coords]

  # trips with fewer than two distinct points can't get a usable shape

  trip_ids <- unique(st$trip_id)
  trip_index <- data.table::chmatch(st$trip_id, trip_ids)
  is_distinct_point <- !duplicated(
    st,
    by = c("trip_id", "stop_lat", "stop_lon")
  )
  n_distinct_points <- tabulate(
    trip_index[is_distinct_point],
    nbins = length(trip_ids)
  )
  buildable_trips <- trip_ids[n_distinct_points >= 2]

  trips_not_built <- setdiff(target_trips, buildable_trips)

  if (length(trips_not_built) > 0) {
    cli::cli_warn(
      paste0(
        "{length(trips_not_built)} trip{?s} could not get a shape, because ",
        "{?it has/they have} no {.file stop_times} entries or fewer than two ",
        "distinct stops with coordinates: {.val {trips_not_built}}."
      ),
      class = "gtfstools_shapes_not_built"
    )
  }

  if (length(buildable_trips) == 0) return(gtfs)

  is_buildable <- st$trip_id %chin% buildable_trips
  if (!all(is_buildable)) st <- st[is_buildable]

  # trips that visit the same sequence of stops share a shape. the sequences
  # are described by integer codes, compared by cpp_sequence_pattern_id(),
  # whose ids are numbered in order of first appearance

  trip_start <- which(!duplicated(st$trip_id))
  n_stops <- diff(c(trip_start, nrow(st) + 1L))
  stop_code <- data.table::chmatch(st$stop_id, unique(st$stop_id))
  pattern_id <- cpp_sequence_pattern_id(n_stops, list(stop_code))

  pattern_trip <- which(!duplicated(pattern_id))
  n_patterns <- length(pattern_trip)

  # new shape_ids are the first ones of the "stops_shape_<n>" series that are
  # not already used. as at most length(used_ids) of them are used, the first
  # n_patterns + length(used_ids) candidates are enough

  used_ids <- character(0)
  if (has_shapes) used_ids <- gtfs$shapes$shape_id
  if (has_shape_id) used_ids <- c(used_ids, gtfs$trips$shape_id)
  used_ids <- unique(used_ids)

  candidate_ids <- paste0(
    "stops_shape_",
    seq_len(n_patterns + length(used_ids))
  )
  new_shape_ids <- candidate_ids[! candidate_ids %chin% used_ids]
  new_shape_ids <- new_shape_ids[seq_len(n_patterns)]

  # the points of each new shape are the stops of the first trip of its
  # pattern

  pattern_n_stops <- n_stops[pattern_trip]
  point_rows <- rep(trip_start[pattern_trip], pattern_n_stops) +
    sequence(pattern_n_stops) - 1L

  new_shapes <- data.table::data.table(
    shape_id = rep(new_shape_ids, pattern_n_stops),
    shape_pt_lat = st$stop_lat[point_rows],
    shape_pt_lon = st$stop_lon[point_rows],
    shape_pt_sequence = sequence(pattern_n_stops)
  )

  if (has_shapes) {
    gtfs$shapes <- rbind(gtfs$shapes, new_shapes, fill = TRUE)
  } else {
    gtfs$shapes <- new_shapes
  }

  # the given gtfs tables are copied before being changed

  built_trips <- st$trip_id[trip_start]
  built_trips_shape_id <- new_shape_ids[pattern_id]

  trips <- data.table::copy(gtfs$trips)
  if (!has_shape_id) {
    data.table::set(trips, j = "shape_id", value = NA_character_)
  }

  trip_match <- data.table::chmatch(trips$trip_id, built_trips)
  rebuilt_rows <- which(!is.na(trip_match))
  data.table::set(
    trips,
    i = rebuilt_rows,
    j = "shape_id",
    value = built_trips_shape_id[trip_match[rebuilt_rows]]
  )
  gtfs$trips <- trips

  if (gtfsio::check_field_exists(gtfs, "stop_times", "shape_dist_traveled")) {
    rebuilt_rows <- which(gtfs$stop_times$trip_id %chin% built_trips)

    if (length(rebuilt_rows) > 0) {
      stop_times <- data.table::copy(gtfs$stop_times)
      data.table::set(
        stop_times,
        i = rebuilt_rows,
        j = "shape_dist_traveled",
        value = stop_times$shape_dist_traveled[NA_integer_]
      )
      gtfs$stop_times <- stop_times
    }
  }

  return(gtfs)
}



#' Get the usable shapes of a shapes table
#'
#' Returns the shapes with at least two distinct points with coordinates, the
#' same rule used in `locate_stops_along_shapes()` (keep both in sync).
#'
#' @param shapes A GTFS `shapes` table.
#'
#' @return A character vector with the `shape_id`s of the usable shapes.
#'
#' @keywords internal
get_usable_shapes <- function(shapes) {
  has_coords <- !is.na(shapes$shape_pt_lat) & !is.na(shapes$shape_pt_lon)
  points <- shapes[
    has_coords,
    .SD,
    .SDcols = c("shape_id", "shape_pt_lat", "shape_pt_lon")
  ]
  points <- unique(points)

  n_distinct_points <- table(points$shape_id)
  usable_shapes <- names(n_distinct_points)[n_distinct_points >= 2]

  return(usable_shapes)
}
