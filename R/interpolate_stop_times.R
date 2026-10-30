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
#' @param overwrite A logical. If `FALSE` (the default), only blank times are
#'   filled. If `TRUE`, the times of every stop between the first and the last
#'   stop of each trip (in `stop_sequence` order) are replaced by interpolated
#'   ones, so only the trips' first and last times are used. Trips whose times
#'   can't be interpolated keep their original times as they are, with a
#'   warning, so blanks that `overwrite = FALSE` would fill in some of their
#'   stops may be left blank.
#' @param keep_dwell_times A logical. Only used when `overwrite = TRUE`. If
#'   `TRUE` (the default), the stops between the first and the last keep their
#'   original dwell times (the difference between their departure and arrival
#'   times), and the remaining time is spread over the distance travelled.
#'   Dwell times that can't be calculated (e.g. a blank time) or that are
#'   negative (e.g. a stop arriving at `"23:59:00"` and departing at
#'   `"00:01:00"`) are taken as 0. If `FALSE`, interpolated stops get equal
#'   arrival and departure times.
#'
#' @return A GTFS object whose `stop_times` has its blank times filled in (or,
#'   with `overwrite = TRUE`, the times of its intermediate stops replaced).
#'   The order of the rows and the other columns are kept. The given GTFS
#'   object is not modified.
#'
#' @section Details:
#' Within each trip, in `stop_sequence` order, a stop whose arrival and
#' departure times are both blank gets a time interpolated linearly on the
#' distance travelled from the preceding timepoint, as measured by
#' [get_trip_length()] (if the distance between two timepoints is 0, their
#' times are spread evenly between the stops in between). Interpolated stops
#' get equal arrival and departure times, rounded to the nearest second,
#' unless they keep their dwell times (see `keep_dwell_times`).
#' Times past `"24:00:00"` are supported. A timepoint with only one of its
#' two times blank gets the other time in both columns. If `stop_times` has a
#' `timepoint` column, interpolated stops get `timepoint = 0`; the column is
#' not created otherwise.
#'
#' Some stops are left blank, with a warning:
#'
#' - stops before a trip's first or after its last timepoint, including every
#'   stop of trips with fewer than two timepoints;
#' - stops between timepoints whose distance can't be calculated, e.g. trips
#'   not linked to a shape or stops without coordinates;
#' - stops between timepoints in which the arrival is earlier than the
#'   previous departure, usually times after midnight written as
#'   `"00:30:00"` instead of `"24:30:00"`.
#'
#' Times are blank when they are `NA`, empty or whitespace-only strings, or
#' `"NA"`. Malformed time strings are left unchanged (unless overwritten with
#' `overwrite = TRUE`), with a warning, and are not used as timepoints. Rows
#' without a `trip_id` are left unchanged. For trips listed in `frequencies`,
#' the template times are interpolated. Times are read from the time strings,
#' and existing `_secs` columns (e.g. created with [convert_time_to_seconds()])
#' are updated to match.
#'
#' Interpolating between timepoints requires the `stops` table.
#'
#' @seealso [get_trip_length()], [get_trip_speed()], [set_trip_speed()]
#'
#' @examplesIf requireNamespace("dplyr", quietly = TRUE)
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#' }
#' library(dplyr)
#'
#' data_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#' trip <- "T2-1@1#520"
#'
#' # only the first and last stops of each trip have times
#' gtfs$stop_times |>
#'   filter(trip_id == trip) |>
#'   head()
#'
#' # distances measured along the trips' shapes. some trips of this feed have
#' # times past midnight written as "00:xx:xx", so they are left blank
#' interpolated_gtfs <- suppressWarnings(interpolate_stop_times(gtfs))
#' interpolated_gtfs$stop_times |>
#'   filter(trip_id == trip) |>
#'   head()
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
#' interpolated_gtfs$stop_times |>
#'   filter(trip_id == trip) |>
#'   head()
#' \dontshow{data.table::setDTthreads(old_dt_threads)}
#'
#' @export
interpolate_stop_times <- function(
  gtfs,
  trip_id = NULL,
  method = "shapes",
  overwrite = FALSE,
  keep_dwell_times = TRUE
) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(method),
    checkmate::check_names(method, subset.of = c("shapes", "euclidean")),
    combine = "and"
  )
  checkmate::assert_logical(overwrite, len = 1, any.missing = FALSE)
  checkmate::assert_logical(keep_dwell_times, len = 1, any.missing = FALSE)
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
  # malformed times are neither filled nor used as timepoints

  blank_arr <- is_blank_time(stop_times$arrival_time)
  blank_dep <- is_blank_time(stop_times$departure_time)

  # with overwrite = TRUE every relevant trip is processed, because the times
  # of its intermediate stops are replaced even when none of them is blank

  has_blank <- is_relevant & (blank_arr | blank_dep)
  if (!overwrite && !any(has_blank)) {
    return(gtfs)
  }

  # rows without a trip_id can't be interpolated

  n_na_trip <- sum(
    has_blank & blank_arr & blank_dep & is.na(stop_times$trip_id)
  )
  if (overwrite) {
    trips <- unique(stop_times$trip_id[is_relevant])
  } else {
    trips <- unique(stop_times$trip_id[has_blank])
  }
  trips <- trips[!is.na(trips)]

  if (length(trips) == 0) {
    if (n_na_trip > 0) {
      warn_times_not_interpolated(n_na_trip, character(0), character(0))
    }
    return(gtfs)
  }

  # select the rows of the trips to interpolate, ordered as in
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

  # with overwrite = TRUE, the intermediate stops of each trip are treated as
  # blank, but only in these local vectors, so the stops that can't be
  # interpolated keep their original times. stops with at least one time are
  # told apart from those that were already blank, for the warnings. their
  # dwell times are kept, if requested, as doubles to avoid an integer
  # overflow in the cumulative sum below

  dwell <- numeric(n_rows)
  is_overwritten <- logical(n_rows)

  if (overwrite) {
    is_last <- c(tid[-1L] != tid[-n_rows], TRUE)
    is_mid <- !is_first & !is_last
    is_overwritten <- is_mid & !(blank_arr & blank_dep)

    if (keep_dwell_times) {
      dwell[is_mid] <- data.table::fcoalesce(
        pmax(dep[is_mid] - arr[is_mid], 0),
        0
      )
    }

    arr[is_mid] <- NA_integer_
    dep[is_mid] <- NA_integer_
    blank_arr[is_mid] <- TRUE
    blank_dep[is_mid] <- TRUE
  }

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
  back_trips <- unique(tid[i[is_backwards & !is_overwritten[i]]])
  is_backwards_row <- logical(n_rows)
  is_backwards_row[i[is_backwards]] <- TRUE
  i <- i[!is_backwards]
  p <- p[!is_backwards]
  q <- q[!is_backwards]

  # distances are calculated only for the trips with stops to interpolate.
  # get_trip_length() returns their segments in the same order of 'rows', so
  # the length of the segment ending at each row is assigned without a join

  new_arr <- integer(0)
  new_dep <- integer(0)
  short_trips <- character(0)

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

    # dwell times kept at the stops of a span are taken out of the time
    # between its timepoints, and the remaining travel time is spread over
    # the distance. as with distances, a single cumulative sum is enough.
    # dwell times are dropped from spans in which they exceed the time
    # between the timepoints, which only happens with times out of order

    cum_dwell <- cumsum(dwell)
    span_dwell <- cum_dwell[q] - cum_dwell[p]
    prev_dwell <- cum_dwell[i] - dwell[i] - cum_dwell[p]
    stop_dwell <- dwell[i]

    is_short <- which(t_arr[q] - t_dep[p] < span_dwell)
    short_trips <- unique(tid[i[is_short]])
    span_dwell[is_short] <- 0
    prev_dwell[is_short] <- 0
    stop_dwell[is_short] <- 0

    # round half up. times are never negative, and round() is much slower on
    # long vectors. dwell times are whole seconds, so adding them before
    # rounding doesn't change it

    travel_time <- t_arr[q] - t_dep[p] - span_dwell
    new_arr <- as.integer(t_dep[p] + fraction * travel_time + 0.5 + prev_dwell)
    new_dep <- new_arr + as.integer(stop_dwell)
  }

  # write only the filled cells, into a copy of stop_times, so the given gtfs
  # is never modified. timepoints with a single blank time get the other one.
  # existing _secs columns, which other functions use as-is, are updated too

  stop_times <- data.table::copy(stop_times)

  for (time_col in c("arrival_time", "departure_time")) {
    if (time_col == "arrival_time") {
      half_blank <- which(is_timepoint & blank_arr)
      half_secs <- t_arr[half_blank]
      new_secs <- new_arr
    } else {
      half_blank <- which(is_timepoint & blank_dep)
      half_secs <- t_dep[half_blank]
      new_secs <- new_dep
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

  # overwritten stops that couldn't be interpolated keep their original times,
  # so they are not reported as blank

  is_left[i] <- FALSE
  is_kept <- is_left & is_overwritten
  is_left <- is_left & !is_overwritten

  if (any(is_left) || n_na_trip > 0) {
    left_trips <- unique(tid[is_left & !is_backwards_row])
    warn_times_not_interpolated(
      sum(is_left) + n_na_trip,
      left_trips,
      back_trips
    )
  }

  if (any(is_kept)) {
    kept_trips <- unique(tid[is_kept])
    cli::cli_warn(
      c(
        paste0(
          "The times of {length(kept_trips)} trip{?s} could not be ",
          "interpolated, so {?its/their} original times were kept: ",
          "{.val {kept_trips}}."
        ),
        "i" = paste0(
          "Their first or last times may be blank or earlier than the ",
          "previous ones, or the distance between their stops may not be ",
          "calculable."
        )
      ),
      class = "gtfstools_times_not_overwritten"
    )
  }

  if (length(short_trips) > 0) {
    cli::cli_warn(
      paste0(
        "The dwell times of {length(short_trips)} trip{?s} exceed the time ",
        "between {?its/their} known times, so they were not kept: ",
        "{.val {short_trips}}."
      ),
      class = "gtfstools_dwell_times_dropped"
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
