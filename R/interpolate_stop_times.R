#' Interpolate missing stop times
#'
#' Fills blank `arrival_time`s and `departure_time`s in `stop_times`, assuming
#' that vehicles travel at a constant speed between consecutive stops with
#' known times (timepoints).
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#'   stop times interpolated. If `NULL` (the default), the function
#'   interpolates the stop times of every `trip_id` in the GTFS.
#' @template method
#'
#' @return A GTFS object whose `stop_times` has its blank times filled in. The
#'   order of the rows and the other columns are kept. The given GTFS object is
#'   not modified.
#'
#' @section Details:
#' Within each trip, ordered by `stop_sequence`, a stop whose arrival and
#' departure times are both blank gets a time interpolated linearly on the
#' distance travelled from the preceding timepoint, as measured by
#' [get_trip_length()]. In other words, the vehicle travels between two
#' timepoints at a constant speed: the distance between them divided by the
#' time from the departure at the first to the arrival at the second.
#' Interpolated stops get equal arrival and departure times (no dwell time),
#' rounded to the nearest second. Times past `"24:00:00"` are supported. If
#' the distance between two timepoints is 0, their times are spread evenly
#' between the stops in between.
#'
#' A timepoint with only one of its two times blank gets the other time in
#' both columns. If `stop_times` has a `timepoint` column, interpolated stops
#' get `timepoint = 0` (approximate times). The column is not created if it
#' doesn't exist.
#'
#' Some stops are left blank, with a warning:
#'
#' - stops before a trip's first or after its last timepoint, including every
#'   stop of trips with fewer than two timepoints;
#' - stops between timepoints whose distance can't be calculated, e.g. trips
#'   not linked to a shape or stops without coordinates;
#' - stops between timepoints in which the arrival is earlier than the
#'   previous departure. This usually happens when times after midnight are
#'   written as `"00:30:00"` instead of `"24:30:00"`.
#'
#' Times are blank when they are `NA`, empty or whitespace-only strings, or
#' `"NA"`. Malformed time strings are left unchanged, with a warning, and are
#' not used as timepoints. Rows without a `trip_id` are left unchanged. Times
#' are read from the time strings, and existing `_secs` columns (e.g. created
#' with [convert_time_to_seconds()]) are updated to match. For trips listed in
#' `frequencies`, the template times are interpolated.
#'
#' The `stops` table is required to interpolate times between timepoints, as
#' well as the `shapes` table and the `shape_id` column in `trips` with
#' `method = "shapes"` (see [get_trip_length()]).
#'
#' @seealso [get_trip_length()], [get_trip_speed()], [set_trip_speed()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#' trip <- "T2-1@1#520"
#'
#' # only the first and last stops of each trip have times
#' head(gtfs$stop_times[trip_id == trip])
#'
#' # distances measured along the trips' shapes. some trips of this feed have
#' # times past midnight written as "00:xx:xx", so they are left blank
#' interpolated_gtfs <- suppressWarnings(interpolate_stop_times(gtfs))
#' head(interpolated_gtfs$stop_times[trip_id == trip])
#'
#' # the speed is now known between every pair of consecutive stops
#' head(get_trip_speed(interpolated_gtfs, trip, by = "segment"))
#'
#' # straight-line distances between stops, for a single trip
#' interpolated_gtfs <- interpolate_stop_times(
#'   gtfs,
#'   trip_id = trip,
#'   method = "euclidean"
#' )
#' head(interpolated_gtfs$stop_times[trip_id == trip])
#'
#' @export
interpolate_stop_times <- function(gtfs, trip_id = NULL, method = "shapes") {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(method),
    checkmate::check_names(method, subset.of = c("shapes", "euclidean")),
    combine = "and"
  )
  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "stop_sequence", "arrival_time", "departure_time"),
    c("character", "integer", "character", "character")
  )

  stop_times <- gtfs$stop_times

  if (!is.null(trip_id)) {
    warn_missing_ids(trip_id, stop_times$trip_id, "stop_times", "trip_id")
    is_relevant <- stop_times$trip_id %chin% trip_id
  } else {
    is_relevant <- rep(TRUE, nrow(stop_times))
  }

  # blanks are detected in the time strings, as in string_to_seconds(), so
  # malformed times are neither filled nor used as timepoints. time columns
  # have few distinct values, so only these are trimmed

  is_blank <- function(x) {
    unique_x <- unique(x)
    blank_x <- unique_x[is.na(unique_x) | trimws(unique_x) %chin% c("", "NA")]
    return(x %chin% blank_x)
  }
  blank_arr <- is_blank(stop_times$arrival_time)
  blank_dep <- is_blank(stop_times$departure_time)

  has_blank <- is_relevant & (blank_arr | blank_dep)
  if (!any(has_blank)) return(gtfs)

  # rows without a trip_id can't be interpolated

  n_na_trip <- sum(
    has_blank & blank_arr & blank_dep & is.na(stop_times$trip_id)
  )
  trips <- unique(stop_times$trip_id[has_blank])
  trips <- trips[!is.na(trips)]

  if (length(trips) == 0) {
    if (n_na_trip > 0) {
      warn_times_not_interpolated(n_na_trip, character(0), character(0))
    }
    return(gtfs)
  }

  # select the rows of the trips with blanks, ordered as in
  # prepare_trip_stops(), which sorts by trip_id and stop_sequence with NAs
  # first. the rows of each trip are contiguous

  rows <- which(stop_times$trip_id %chin% trips)
  rows <- rows[
    order(
      stop_times$trip_id[rows],
      stop_times$stop_sequence[rows],
      method = "radix",
      na.last = FALSE
    )
  ]

  n_rows <- length(rows)
  tid <- stop_times$trip_id[rows]
  is_first <- c(TRUE, tid[-1L] != tid[-n_rows])
  trip_idx <- cumsum(is_first)
  blank_arr <- blank_arr[rows]
  blank_dep <- blank_dep[rows]

  arr <- string_to_seconds(stop_times$arrival_time[rows])
  dep <- string_to_seconds(stop_times$departure_time[rows])
  t_arr <- data.table::fcoalesce(arr, dep)
  t_dep <- data.table::fcoalesce(dep, arr)

  # find the previous and the next timepoint of each row. this is done over
  # all rows at once, so only pairs within the same trip are kept afterwards

  is_timepoint <- !is.na(t_dep)
  timepoint_row <- rep(NA_integer_, n_rows)
  timepoint_row[is_timepoint] <- which(is_timepoint)
  prev_timepoint <- data.table::nafill(timepoint_row, "locf")
  next_timepoint <- data.table::nafill(timepoint_row, "nocb")

  is_left <- blank_arr & blank_dep
  i <- which(is_left)
  p <- prev_timepoint[i]
  q <- next_timepoint[i]

  is_inside <- which(trip_idx[p] == trip_idx[q])
  i <- i[is_inside]
  p <- p[is_inside]
  q <- q[is_inside]

  # spans in which the arrival is earlier than the previous departure (e.g.
  # times after midnight written as "00:xx:xx") are left blank

  is_backwards <- t_arr[q] < t_dep[p]
  back_trips <- unique(tid[i[is_backwards]])
  is_backwards_row <- logical(n_rows)
  is_backwards_row[i[is_backwards]] <- TRUE
  i <- i[!is_backwards]
  p <- p[!is_backwards]
  q <- q[!is_backwards]

  # distances are calculated only for the trips with stops to interpolate.
  # get_trip_length() returns their segments in the same order of 'rows', so
  # the length of the segment ending at each row is assigned without a join

  new_secs <- integer(0)

  if (length(i) > 0) {
    dist_trips <- unique(tid[i])
    segments <- get_trip_length(
      gtfs,
      dist_trips,
      method,
      by = "segment",
      unit = "m"
    )

    segment_rows <- which(!is_first & tid %chin% dist_trips)
    if (!identical(segments$trip_id, tid[segment_rows])) {
      cli::cli_abort(
        "Segment lengths are not aligned with {.file stop_times} rows.",
        .internal = TRUE
      )
    }

    # a single cumulative sum over all rows is enough, because only distances
    # within the same trip are compared. spans that include a segment with an
    # NA length are left blank

    seg_length <- numeric(n_rows)
    seg_length[segment_rows] <- segments$length
    is_na_length <- is.na(seg_length)
    seg_length[is_na_length] <- 0
    distance <- cumsum(seg_length)
    n_na_length <- cumsum(is_na_length)

    has_length <- which(n_na_length[p] == n_na_length[q])
    i <- i[has_length]
    p <- p[has_length]
    q <- q[has_length]

    span <- distance[q] - distance[p]
    fraction <- (distance[i] - distance[p]) / span
    is_zero <- which(span == 0)
    fraction[is_zero] <- (i[is_zero] - p[is_zero]) / (q[is_zero] - p[is_zero])

    # round half up. times are never negative, and round() is much slower on
    # long vectors

    new_secs <- as.integer(
      t_dep[p] + fraction * (t_arr[q] - t_dep[p]) + 0.5
    )
  }

  # write only the filled cells, into a copy of stop_times, so the given gtfs
  # is never modified. timepoints with a single blank time get the other one.
  # existing _secs columns, which other functions use as-is, are updated too

  stop_times <- data.table::copy(stop_times)

  for (time_col in c("arrival_time", "departure_time")) {
    if (time_col == "arrival_time") {
      half_blank <- which(is_timepoint & blank_arr)
      half_secs <- t_arr[half_blank]
    } else {
      half_blank <- which(is_timepoint & blank_dep)
      half_secs <- t_dep[half_blank]
    }

    to_fill <- rows[c(i, half_blank)]
    secs <- c(new_secs, half_secs)
    data.table::set(stop_times, to_fill, time_col, seconds_to_string(secs))

    secs_col <- paste0(time_col, "_secs")
    if (secs_col %chin% names(stop_times)) {
      data.table::set(stop_times, to_fill, secs_col, secs)
    }
  }

  if ("timepoint" %chin% names(stop_times) && length(i) > 0) {
    approximate <- if (is.character(stop_times$timepoint)) "0" else 0L
    data.table::set(stop_times, rows[i], "timepoint", approximate)
  }

  is_left[i] <- FALSE
  if (any(is_left) || n_na_trip > 0) {
    left_trips <- unique(tid[is_left & !is_backwards_row])
    warn_times_not_interpolated(
      sum(is_left) + n_na_trip,
      left_trips,
      back_trips
    )
  }

  gtfs$stop_times <- stop_times
  return(gtfs)
}



#' Warn about stop times that couldn't be interpolated
#'
#' @param n_left The number of stop times left blank.
#' @param left_trips The trips with blank stop times outside two timepoints or
#'   whose distances couldn't be calculated.
#' @param back_trips The trips with blank stop times between timepoints in
#'   which the arrival is earlier than the previous departure.
#'
#' @return Invisibly returns `NULL`. Called for its warning.
#'
#' @keywords internal
warn_times_not_interpolated <- function(n_left, left_trips, back_trips) {
  message <- paste0(
    "{n_left} stop time{?s} could not be interpolated and {?was/were} left ",
    "blank."
  )

  if (length(left_trips) > 0) {
    message <- c(
      message,
      "i" = paste0(
        "Times are interpolated only between two stops with known times, ",
        "and only if the distance between them can be calculated (e.g. ",
        "stops listed in {.file stops} with coordinates). Affected trip{?s}: ",
        "{.val {left_trips}}."
      )
    )
  }

  if (length(back_trips) > 0) {
    message <- c(
      message,
      "i" = paste0(
        "{length(back_trips)} trip{?s} {?has/have} an arrival earlier than ",
        "the previous departure, e.g. times after midnight written as ",
        "{.val 00:30:00} instead of {.val 24:30:00}: {.val {back_trips}}."
      )
    )
  }

  cli::cli_warn(message, class = "gtfstools_times_not_interpolated")

  return(invisible(NULL))
}
