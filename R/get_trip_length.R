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
#' @template method
#' @param by A string, either `"trip"` (the default) or `"segment"`. `"trip"`
#'   returns the length from the first to the last stop of each trip, while
#'   `"segment"` returns the length between each pair of consecutive stops.
#' @param unit A string representing the unit in which lengths are desired.
#'   Either `"km"` (the default) or `"m"`.
#' @param sort_sequence Deprecated; do not supply. Timetables and shapes are
#'   now always sorted by `stop_sequence` and `shape_pt_sequence`. Passing
#'   `TRUE` raises a warning, and passing `FALSE` raises an error.
#' @param file Deprecated. Use `method` instead (`file = "stop_times"`
#'   corresponds to `method = "euclidean"`).
#' @param from A string, in the "HH:MM:SS" format. With `by = "trip"`, only
#'   trips that depart from their first stop at or after `from` are included.
#'   With `by = "segment"`, only segments that depart from their first stop at
#'   or after `from` are included. If `NULL` (the default), there is no lower
#'   limit.
#' @param to A string, in the "HH:MM:SS" format. Only trips (or segments) that
#'   depart from their first stop at or before `to` are included. If `NULL`
#'   (the default), there is no upper limit.
#'
#' @return With `by = "trip"`, a `data.table` with the `trip_id` and the
#'   `length` of each trip. With `by = "segment"`, a `data.table` with the
#'   `trip_id`, the `segment` number, the `from_stop_id` and `to_stop_id` that
#'   delimit the segment and its `length`.
#'
#' @section Details:
#' Segments are numbered as in [get_trip_segment_duration()], so both outputs
#' can be joined by `trip_id` and `segment`. Trips with a single stop have a
#' length of 0.
#'
#' With `method = "shapes"`, each stop is projected onto the closest point of
#' its trip's shape, with stops advancing along the shape in `stop_sequence`
#' order, so loops and shapes that pass by the same place more than once are
#' handled. Some limitations remain:
#'
#' - a stop slightly behind the previous one along the shape (e.g. due to
#'   imprecise coordinates) is placed at the previous stop's position, so their
#'   segment has a length of 0. On shapes that pass the same place twice in the
#'   same direction, such a stop may be matched to the later pass instead;
#' - on shapes whose outbound and return legs overlap exactly, the stops just
#'   before and after the turnaround may be placed at the same position. The
#'   trip length is unaffected, but the segment between them gets a length of
#'   0 and the next one is longer.
#'
#' `shape_dist_traveled` is ignored. Trips not linked to a shape with at least
#' two distinct points have `NA` lengths, with a warning. Use
#' [get_shape_length()] for the length of entire shapes.
#'
#' Lengths are great-circle (haversine) distances on the sphere used by
#' `{s2}`. Stops with missing coordinates, or not listed in `stops`, result in
#' `NA` lengths for their segments and trips.
#'
#' `from` and `to` are compared with the `departure_time` of the first stop of
#' each trip (in `stop_sequence` order) or segment, as written in
#' `stop_times`, so use times past `"24:00:00"` for departures after midnight.
#' With `by = "segment"`, times after midnight written as early morning times
#' (e.g. `"00:30:00"` instead of `"24:30:00"`) are first fixed with
#' [fix_overnight_times()]; a trip's first departure is never changed by it.
#' For trips listed in `frequencies`, these are template times, not the times
#' of each departure. Trips and segments whose departure is blank are never
#' included when `from` or `to` is given.
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
                            sort_sequence,
                            file = NULL,
                            from = NULL,
                            to = NULL) {
  if (!missing(sort_sequence)) {
    check_deprecated_sort_sequence(
      sort_sequence,
      "get_trip_length",
      c("stop_sequence", "shape_pt_sequence")
    )
  }

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
  window <- dwell_time_window(from, to)
  is_windowed <- any(is.finite(window))

  assert_trip_stops_fields(gtfs)
  if (is_windowed) {
    gtfsio::assert_field_class(
      gtfs,
      "stop_times",
      "departure_time",
      "character"
    )
  }

  # lengths along the shapes require a 'shapes' table and a 'shape_id' column
  # in 'trips'. if any of them is missing, fall back to euclidean distances

  method <- resolve_shapes_method(
    gtfs,
    method,
    fallback = paste0(
      "Calculating {.val euclidean} (straight-line) lengths between ",
      "consecutive stops instead of lengths along the shapes."
    )
  )

  if (method == "shapes") assert_shapes_fields(gtfs)

  # with by = "segment", the segments within the time of day are selected by
  # the departure at their first stop, so times after midnight written as
  # early morning times are fixed first. a trip's first departure is never
  # changed by the fix, so by = "trip" doesn't need it

  if (is_windowed && by == "segment") {
    gtfs <- fix_overnight_in_call(gtfs = gtfs, trip_id = trip_id)
  }

  if (is_windowed) {
    st <- prepare_trip_stops(gtfs, trip_id, with_departure = TRUE)
  } else {
    st <- prepare_trip_stops(gtfs, trip_id)
  }

  # with by = "trip", only the trips that depart from their first stop within
  # the time of day are measured. with by = "segment", the segments are
  # filtered after being numbered, below

  if (is_windowed && by == "trip") {
    kept_trips <- trips_departing_within(
      st$trip_id,
      st$stop_sequence,
      st$departure_time,
      window
    )
    st <- st[st$trip_id %chin% kept_trips]
  }

  n_rows <- nrow(st)
  if (n_rows == 0) return(empty_trip_length(by))

  is_last_stop <- c(st$trip_id[-1L] != st$trip_id[-n_rows], TRUE)
  stop_lat <- st$stop_lat
  stop_lon <- st$stop_lon

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
    position <- locate_stops_along_shapes(gtfs, st, stop_lat, stop_lon)
    attr(position, "shape_points") <- NULL
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

    if (is_windowed) {
      departure <- string_to_seconds(st$departure_time[is_segment])
      in_window <- !is.na(departure) &
        departure >= window[1] &
        departure <= window[2]
      lengths <- lengths[in_window]
    }
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
