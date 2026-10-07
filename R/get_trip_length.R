#' Get trip length
#'
#' Returns the length of each specified `trip_id`, measured either from the
#' first to the last stop of the trip or between each pair of consecutive
#' stops. Lengths can be measured along the trip's shape or as straight lines
#' between stops.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#'   lengths calculated. If `NULL` (the default), the function calculates the
#'   lengths of every `trip_id` in the GTFS.
#' @param method A string, either `"shapes"` (the default) or `"euclidean"`.
#'   `"shapes"` measures lengths along the trip's shape, described in the
#'   `shapes` table, while `"euclidean"` measures the straight-line
#'   (great-circle) distances between consecutive stops. If the GTFS object
#'   doesn't have a `shapes` table, or if its `trips` table doesn't have a
#'   `shape_id` column, `"euclidean"` is used instead, with a warning.
#' @param by A string, either `"trip"` (the default) or `"segment"`. `"trip"`
#'   returns the length from the first to the last stop of each trip, while
#'   `"segment"` returns the length between each pair of consecutive stops.
#' @param unit A string representing the unit in which lengths are desired.
#'   Either `"km"` (the default) or `"m"`.
#' @param sort_sequence A logical specifying whether to sort timetables and
#'   shapes by `stop_sequence` and `shape_pt_sequence`, respectively. Defaults
#'   to `TRUE`. Sorting an already ordered table is cheap. Set to `FALSE`
#'   only if these tables are known to be ordered.
#' @param file Deprecated. Use `method` instead: `file = "shapes"` corresponds
#'   to `method = "shapes"` and `file = "stop_times"` to `method =
#'   "euclidean"`. If given, `file` takes precedence over `method`. If both
#'   files are given, only `"shapes"` is used.
#'
#' @return With `by = "trip"`, a `data.table` with the `trip_id` and the
#'   `length` of each trip. With `by = "segment"`, a `data.table` with the
#'   `trip_id`, the `segment` number, the `from_stop_id` and `to_stop_id` that
#'   delimit the segment and its `length`.
#'
#' @section Details:
#' A segment is the path between two consecutive stops of the same trip. The
#' segments of each trip are numbered from 1 to the number of stops minus 1,
#' in the same way as in [get_trip_segment_duration()], so the results of both
#' functions can be joined by `trip_id` and `segment` to calculate segment
#' speeds (see [get_trip_speed()]). With `by = "trip"`, the length of a trip is
#' the sum of the lengths of its segments, and trips with a single stop have a
#' length of 0.
#'
#' With `method = "shapes"`, each stop is projected onto the closest point of
#' its trip's shape, with the restriction that the stops must advance along
#' the shape in the order given by `stop_sequence`. This correctly handles
#' loops and shapes that pass by the same place more than once. When a stop is
#' located slightly before the previous one along the shape (e.g. because of
#' imprecise coordinates), the distance between them is usually 0, and the
#' length of the trip usually varies by at most the gap between the two stops,
#' depending on where the shape's points are. However, if the shape passes by
#' the same place more than once in the same direction (e.g. a shape that goes
#' around a loop twice), such a stop may be matched to a later pass, which
#' increases the length of the trip. Stops are
#' projected regardless of how far they are from the shape, and the
#' `shape_dist_traveled` columns of `shapes` and `stop_times`, if present, are
#' ignored. Shape points with missing coordinates are ignored. Trips that are
#' not linked to a shape, or whose shape has fewer than two distinct points
#' with coordinates, have `NA` lengths, and a warning is raised. The length
#' along the shape between the first and the last stop of a trip is usually
#' shorter than the length of its entire shape, which is returned by
#' [get_shape_length()].
#'
#' Lengths are great-circle distances calculated with the haversine formula,
#' on a sphere with the same radius used by `{s2}` (6,371,010 meters),
#' regardless of whether `sf::sf_use_s2()` is enabled. Stops with missing
#' coordinates, or that are not listed in the `stops` table, result in `NA`
#' lengths for the segments they delimit and for the trips they belong to.
#'
#' @seealso [get_shape_length()], [get_trip_speed()],
#'   [get_trip_segment_duration()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # length along the shape from the first to the last stop of each trip
#' trip_length <- get_trip_length(gtfs)
#' head(trip_length)
#'
#' # length along the shape between consecutive stops
#' segment_length <- get_trip_length(gtfs, "CPTM L07-0", by = "segment")
#' head(segment_length)
#'
#' # straight-line distances between consecutive stops, in meters
#' straight_length <- get_trip_length(
#'   gtfs,
#'   "CPTM L07-0",
#'   method = "euclidean",
#'   by = "segment",
#'   unit = "m"
#' )
#' head(straight_length)
#'
#' @export
get_trip_length <- function(gtfs,
                            trip_id = NULL,
                            method = "shapes",
                            by = "trip",
                            unit = "km",
                            sort_sequence = TRUE,
                            file = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  if (!is.null(file)) method <- map_deprecated_file(file, "get_trip_length")
  checkmate::assert(
    checkmate::check_string(method),
    checkmate::check_names(method, subset.of = c("shapes", "euclidean")),
    combine = "and"
  )
  checkmate::assert(
    checkmate::check_string(by),
    checkmate::check_names(by, subset.of = c("trip", "segment")),
    combine = "and"
  )
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = c("km", "m")),
    combine = "and"
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

  # lengths along the shapes require a 'shapes' table and a 'shape_id' column
  # in 'trips'. if any of them is missing, fall back to euclidean distances

  if (method == "shapes" && !has_shapes(gtfs)) {
    cli::cli_warn(
      c(
        paste0(
          "The GTFS object doesn't have a {.file shapes} table, or its ",
          "{.file trips} table doesn't have a {.field shape_id} column."
        ),
        "i" = paste0(
          "Calculating {.val euclidean} (straight-line) lengths between ",
          "consecutive stops instead of lengths along the shapes."
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

  # select the relevant stop_times rows into a new table, so the tables of the
  # given gtfs are never modified. the selection index is created outside of
  # `[` so that {data.table} doesn't add an index to the original table

  if (!is.null(trip_id)) {
    warn_missing_ids(trip_id, gtfs$stop_times$trip_id, "stop_times", "trip_id")
    is_relevant <- gtfs$stop_times$trip_id %chin% trip_id
  } else {
    is_relevant <- rep(TRUE, nrow(gtfs$stop_times))
  }

  st <- gtfs$stop_times[is_relevant, .SD, .SDcols = stop_times_cols]

  if (sort_sequence) {
    data.table::setorderv(st, c("trip_id", "stop_sequence"))
  }

  # the calculations below are vectorised over all rows, which requires the
  # rows of each trip to be contiguous. ordering the trips by their first
  # appearance (a stable order) keeps the order of the rows within each trip,
  # and the order of the output, unchanged

  trip_order <- data.table::chmatch(st$trip_id, unique(st$trip_id))
  if (is.unsorted(trip_order)) st <- st[order(trip_order, method = "radix")]

  n_rows <- nrow(st)
  if (n_rows == 0) return(empty_trip_length(by))

  is_last_stop <- c(st$trip_id[-1L] != st$trip_id[-n_rows], TRUE)

  # stops' coordinates are looked up by their first match, instead of joined, so
  # duplicated stop_ids in 'stops' can't duplicate stop_times rows

  stop_idx <- data.table::chmatch(st$stop_id, gtfs$stops$stop_id)
  stop_lat <- gtfs$stops$stop_lat[stop_idx]
  stop_lon <- gtfs$stops$stop_lon[stop_idx]

  # calculate the distance from each stop to the next stop of the same trip
  # (the last stop of each trip gets NA)

  if (method == "euclidean") {
    distance <- rcpp_distance_haversine(
      stop_lat,
      stop_lon,
      c(stop_lat[-1L], NA_real_),
      c(stop_lon[-1L], NA_real_)
    )
  } else {
    position <- locate_stops_along_shapes(
      gtfs,
      st,
      stop_lat,
      stop_lon,
      sort_sequence
    )
    distance <- c(position[-1L], NA_real_) - position
  }

  distance[is_last_stop] <- NA_real_
  if (unit == "km") distance <- distance / 1000

  # build the output. the length of a trip is the sum of the lengths of its
  # segments, so trips with a single stop have a length of 0 and trips with
  # a missing segment length have NA

  if (by == "segment") {
    is_segment <- !is_last_stop

    lengths <- data.table::data.table(
      trip_id = st$trip_id[is_segment],
      segment = data.table::rowid(st$trip_id[is_segment]),
      from_stop_id = st$stop_id[is_segment],
      to_stop_id = st$stop_id[which(is_segment) + 1L],
      length = distance[is_segment]
    )
  } else {
    distance[is_last_stop] <- 0

    lengths <- data.table::data.table(
      trip_id = st$trip_id,
      length = distance
    )
    lengths <- lengths[, .(length = sum(length, na.rm = FALSE)), by = trip_id]
  }

  return(lengths[])
}



#' Create an empty output of `get_trip_length()`
#'
#' @param by Either `"trip"` or `"segment"`.
#'
#' @return An empty `data.table` with the columns of the output of
#'   `get_trip_length()`.
#'
#' @keywords internal
empty_trip_length <- function(by) {
  if (by == "segment") {
    empty <- data.table::data.table(
      trip_id = character(0),
      segment = integer(0),
      from_stop_id = character(0),
      to_stop_id = character(0),
      length = numeric(0)
    )
  } else {
    empty <- data.table::data.table(
      trip_id = character(0),
      length = numeric(0)
    )
  }

  return(empty)
}



#' Locate stops along their trips' shapes
#'
#' @param gtfs A GTFS object.
#' @param st A `data.table` with the stop_times of the relevant trips, in which
#'   the rows of each trip are contiguous.
#' @param stop_lat,stop_lon The coordinates of the stops listed in `st`.
#' @param sort_sequence Whether to sort the shapes by `shape_pt_sequence`.
#'
#' @return A numeric vector with the position of each stop along its trip's
#'   shape, in meters from the start of the shape. Stops whose trip is not
#'   linked to a usable shape, or that don't have coordinates, get `NA`.
#'
#' @keywords internal
locate_stops_along_shapes <- function(gtfs,
                                      st,
                                      stop_lat,
                                      stop_lon,
                                      sort_sequence) {
  # each trip's first and last rows and its shape, looked up by first match

  trip_start <- which(!duplicated(st$trip_id))
  trip_end <- c(trip_start[-1L] - 1L, nrow(st))
  n_stops <- trip_end - trip_start + 1L

  trip_shape_id <- gtfs$trips$shape_id[
    data.table::chmatch(st$trip_id[trip_start], gtfs$trips$trip_id)
  ]

  # usable shape points, split by shape. shapes with fewer than two distinct
  # points can't be used

  shapes_cols <- c("shape_id", "shape_pt_lat", "shape_pt_lon")
  if (sort_sequence) shapes_cols <- c(shapes_cols, "shape_pt_sequence")

  is_relevant_point <- gtfs$shapes$shape_id %chin% trip_shape_id &
    !is.na(gtfs$shapes$shape_pt_lat) &
    !is.na(gtfs$shapes$shape_pt_lon)
  shapes <- gtfs$shapes[is_relevant_point, .SD, .SDcols = shapes_cols]

  if (sort_sequence) {
    data.table::setorderv(shapes, c("shape_id", "shape_pt_sequence"))
  }

  shape_rows <- split(seq_len(nrow(shapes)), shapes$shape_id)
  is_distinct_point <- !duplicated(
    shapes,
    by = c("shape_id", "shape_pt_lat", "shape_pt_lon")
  )
  n_distinct_points <- table(shapes$shape_id[is_distinct_point])
  usable_shapes <- names(n_distinct_points)[n_distinct_points >= 2]
  has_usable_shape <- trip_shape_id %chin% usable_shapes

  trips_without_shape <- st$trip_id[trip_start][!has_usable_shape & n_stops > 1]

  if (length(trips_without_shape) > 0) {
    cli::cli_warn(
      paste0(
        "{length(trips_without_shape)} trip{?s} {?is/are} not linked to a ",
        "shape with at least two distinct points, so {?its/their} ",
        "length{?s} {?is/are} {.val {NA}}: {.val {trips_without_shape}}."
      ),
      class = "gtfstools_trips_without_shape"
    )
  }

  # trips sharing the same shape and the same sequence of stops (a pattern)
  # have the same stop positions along the shape, so each pattern is located
  # only once. shapes and stops are described by integer codes, which can't
  # collide when pasted together

  shape_code <- data.table::chmatch(trip_shape_id, unique(trip_shape_id))
  stop_code <- data.table::chmatch(st$stop_id, unique(st$stop_id))

  trip_stop_codes <- split(
    stop_code,
    rep.int(seq_along(trip_start), n_stops)
  )
  pattern <- paste(
    shape_code,
    vapply(trip_stop_codes, paste, character(1), collapse = " ")
  )
  pattern_id <- match(pattern, unique(pattern))
  pattern_trip <- which(!duplicated(pattern_id))

  pattern_positions <- lapply(
    pattern_trip,
    function(k) {
      rows <- trip_start[k]:trip_end[k]
      position <- rep(NA_real_, length(rows))
      if (!has_usable_shape[k]) return(position)

      lat <- stop_lat[rows]
      lon <- stop_lon[rows]
      is_valid <- !is.na(lat) & !is.na(lon)
      if (sum(is_valid) < 2) return(position)

      shape_point <- shape_rows[[trip_shape_id[k]]]
      position[is_valid] <- rcpp_locate_stops_on_shape(
        shapes$shape_pt_lat[shape_point],
        shapes$shape_pt_lon[shape_point],
        lat[is_valid],
        lon[is_valid]
      )

      return(position)
    }
  )

  # the positions of each trip are those of its pattern. since the rows of each
  # trip are contiguous, they can simply be concatenated in trip order

  position <- unlist(pattern_positions[pattern_id], use.names = FALSE)

  return(position)
}



#' Check whether a GTFS object has shapes linked to its trips
#'
#' @template gtfs
#'
#' @return `TRUE` if the GTFS object has a `shapes` table and a `shape_id`
#'   column in its `trips` table, `FALSE` otherwise.
#'
#' @keywords internal
has_shapes <- function(gtfs) {
  has_table <- gtfsio::check_file_exists(gtfs, "shapes")
  has_field <- gtfsio::check_field_exists(gtfs, "trips", "shape_id")

  return(isTRUE(has_table) && isTRUE(has_field))
}



#' Map the deprecated `file` argument to `method`
#'
#' Raises a deprecation warning and returns the `method` that corresponds to
#' the given `file`.
#'
#' @param file The value given to the deprecated `file` argument.
#' @param fn_name The name of the function whose argument is deprecated.
#'
#' @return Either `"shapes"`, if `"shapes"` is included in `file`, or
#'   `"euclidean"`.
#'
#' @keywords internal
map_deprecated_file <- function(file, fn_name) {
  checkmate::assert_character(file, min.len = 1, any.missing = FALSE)
  checkmate::assert_names(file, subset.of = c("shapes", "stop_times"))

  method <- ifelse("shapes" %in% file, "shapes", "euclidean")

  message <- c(
    "The {.arg file} argument of {.fun {fn_name}} is deprecated.",
    "i" = "Please use {.arg method} = {.val {method}} instead.",
    "i" = paste0(
      "Lengths are now measured from the first to the last stop of each ",
      "trip. Use {.fun get_shape_length} to calculate the length of the ",
      "entire shapes."
    )
  )
  if (length(file) > 1) {
    message <- c(
      message,
      "i" = paste0(
        "Only {.val shapes} was used. To use both methods, call ",
        "{.fun {fn_name}} once with each of them."
      )
    )
  }

  cli::cli_warn(message, class = "deprecated_file")

  return(method)
}
