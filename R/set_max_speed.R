#' Set trip maximum speed
#'
#' Caps the speed of the specified trips: each part of a trip that is faster
#' than `max_speed` is slowed down to `max_speed`, by changing the
#' `arrival_time` and `departure_time` columns in `stop_times`. Parts of the
#' trips that are already slower are left unchanged.
#'
#' @template gtfs
#' @param max_speed A number. The maximum speed allowed, in the unit given by
#'   `unit`.
#' @param unit A string representing the unit in which the speed is given. One
#'   of `"km/h"` (the default), `"m/s"` or `"mph"` (miles per hour).
#' @param route_id A character vector including the `route_id`s whose trips
#'   have their speeds capped. If `route_id`, `trip_id` and `route_type` are
#'   all `NULL` (the default), the speeds of every trip in the GTFS are capped.
#'   `route_id`s not listed in `trips` are ignored, with a warning.
#' @param trip_id A character vector including the `trip_id`s to have their
#'   speeds capped. When given together with `route_id`, the trips of both are
#'   capped.
#' @param first_stop A string. The `stop_id` where the segment whose speeds
#'   are capped starts. If `NULL` (the default), the segment starts at each
#'   trip's first stop.
#' @param last_stop A string. The `stop_id` where the segment ends. If `NULL`
#'   (the default), the segment ends at each trip's last stop.
#' @param from A string, in the "HH:MM:SS" format. Only trips that depart from
#'   the segment's first stop at or after `from` are changed. If `NULL` (the
#'   default), there is no lower limit.
#' @param to A string, in the "HH:MM:SS" format. Only trips that depart from
#'   the segment's first stop at or before `to` are changed. If `NULL` (the
#'   default), there is no upper limit.
#' @inheritParams set_trip_speed
#'
#' @return A GTFS object with the time columns of its `stop_times` adjusted.
#'
#' @section Details:
#' A span is the part of a trip between two consecutive stops with times;
#' stops with blank times inside it are kept blank. Its speed is its length,
#' calculated by [get_trip_length()] along the trip's shape (or, with a
#' warning, as straight lines between stops if there are no shapes; the
#' `stops` table is required), divided by the time from the departure at its
#' first stop to the arrival at its second. Spans whose length is `NA` (e.g.
#' in trips not linked to a shape) are left unchanged.
#'
#' Each span faster than `max_speed`, or with a zero duration, has its duration
#' raised to its length divided by `max_speed`, rounded up to the next second.
#' All the later times of the trip are shifted by the accumulated extra time,
#' so dwell times are kept. Times after midnight written as early morning
#' times (e.g. `"00:30:00"` instead of `"24:30:00"`) are first fixed with
#' [fix_overnight_times()] in every trip, so the returned GTFS has them fixed.
#' Spans whose arrival is still earlier than the previous departure (by 12
#' hours or less) are left unchanged, with a warning. An error is raised if a
#' shift would result in a time later than `"9999:59:59"`. Only `stop_times`
#' is modified; its existing `_secs` columns are updated to match.
#'
#' With `first_stop` and `last_stop`, matched as in [set_trip_speed()], only
#' the spans between them are capped: times before `first_stop` don't change,
#' and the times at and after `last_stop` are shifted. The given stops must
#' have a time, so that no span crosses them (if only `last_stop` is given,
#' the trip's first stop needs none). Trips that don't visit `first_stop` and
#' then `last_stop`, or have blank times there, are left unchanged, with a
#' warning if they were given in `trip_id` or `route_id`.
#'
#' `from` and `to` are compared with the departure at the segment's first stop
#' (or its arrival, if the departure is blank) as written in `stop_times`, once
#' fixed (template times, for trips listed in `frequencies`), so use times past
#' `"24:00:00"` for departures after midnight. Trips without a time there are
#' left unchanged.
#'
#' @seealso [set_min_speed()], [set_trip_speed()], [get_trip_speed()]
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
#' # the trip is faster than 30 km/h between some of its stops
#' get_trip_speed(gtfs, "CPTM L07-0", by = "segment")
#'
#' gtfs_capped <- set_max_speed(gtfs, max_speed = 30, trip_id = "CPTM L07-0")
#' get_trip_speed(gtfs_capped, "CPTM L07-0", by = "segment")
#'
#' # the later stops are shifted, so the trip ends later
#'  get_start_and_end_times(gtfs, trip_id = "CPTM L07-0")
#'  get_start_and_end_times(gtfs_capped, trip_id = "CPTM L07-0")
#'
#' # cap the speed only between two stops. the spans before and after them
#' # are not capped
#' gtfs_capped <- set_max_speed(
#'   gtfs,
#'   max_speed = 30,
#'   trip_id = "CPTM L07-0",
#'   first_stop = "18921",
#'   last_stop = "18974"
#' )
#' get_trip_speed(gtfs_capped, "CPTM L07-0", by = "segment")
#'
#' # cap the speed of all the trips of all routes of the GTFS feed
#' gtfs_capped <- set_max_speed(gtfs, max_speed = 8)
#'
#' @export
set_max_speed <- function(
  gtfs,
  max_speed,
  unit = "km/h",
  route_id = NULL,
  trip_id = NULL,
  first_stop = NULL,
  last_stop = NULL,
  from = NULL,
  to = NULL,
  route_type = NULL
) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_number(
    max_speed,
    lower = .Machine$double.eps,
    finite = TRUE
  )
  checkmate::assert_character(route_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = names(speed_unit_factors)),
    combine = "and"
  )
  checkmate::assert_string(first_stop, min.chars = 1, null.ok = TRUE)
  checkmate::assert_string(last_stop, min.chars = 1, null.ok = TRUE)
  checkmate::assert_string(from, pattern = time_pattern, null.ok = TRUE)
  checkmate::assert_string(to, pattern = time_pattern, null.ok = TRUE)
  checkmate::assert_integerish(
    route_type,
    min.len = 1,
    any.missing = FALSE,
    null.ok = TRUE
  )

  window <- dwell_time_window(from, to)

  # calculations use km/h

  max_kmh <- max_speed * speed_unit_factors[[unit]]

  return(
    limit_trip_speed(
      gtfs,
      max_kmh,
      "max",
      route_id,
      trip_id,
      first_stop,
      last_stop,
      window,
      route_type
    )
  )
}



# changes the speed of the selected trips, either capping it ('mode = "max"',
# used by set_max_speed()) or raising it ('mode = "min"', used by
# set_min_speed()) to 'limit_kmh'. the arguments are validated by the callers,
# so that their errors are attributed to them, and 'window' is the output of
# dwell_time_window()

limit_trip_speed <- function(
  gtfs,
  limit_kmh,
  mode,
  route_id,
  trip_id,
  first_stop,
  last_stop,
  window,
  route_type
) {
  is_max <- identical(mode, "max")

  from_secs <- window[1]
  to_secs <- window[2]

  has_stop_args <- !is.null(first_stop) || !is.null(last_stop)
  has_window <- any(is.finite(window))

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time", "stop_sequence"),
    c("character", "character", "character", "integer")
  )

  if (has_stop_args) {
    gtfsio::assert_field_class(gtfs, "stop_times", "stop_id", "character")
  }

  # times after midnight written as early morning times are fixed first, so
  # they don't go back. the returned feed keeps the fixed times

  gtfs <- fix_overnight_in_call(gtfs)

  # select the trips. ids is NULL only when both arguments are NULL, so that
  # trip_ids that don't exist don't result in all trips being changed

  existing_trips <- gtfs$stop_times$trip_id
  ids <- NULL

  if (!is.null(trip_id) || !is.null(route_id)) {
    ids <- character(0)

    # the call must be evaluated directly in this function's body, so that
    # the warning is attributed to its caller

    if (!is.null(trip_id)) {
      invalid_trip_id <- warn_missing_ids(
        trip_id,
        existing_trips,
        "stop_times",
        "trip_id",
        call = sys.call(-1)
      )
      ids <- setdiff(trip_id, invalid_trip_id)
    }

    if (!is.null(route_id)) {
      gtfsio::assert_field_class(
        gtfs,
        "trips",
        c("trip_id", "route_id"),
        c("character", "character")
      )

      warn_invalid_ids(route_id, gtfs$trips$route_id, "trips", "route_id")

      # only trips with stop times, so get_trip_length() doesn't warn about
      # the others

      route_trips <- gtfs$trips$trip_id[gtfs$trips$route_id %chin% route_id]
      route_trips <- route_trips[route_trips %chin% existing_trips]
      ids <- unique(c(ids, route_trips))
    }
  }

  # route_type restricts the trips selected by id (or selects all the trips of
  # these types). trips without the segment are only reported when the user
  # listed them by id

  selected_by_id <- !is.null(ids)

  if (!is.null(route_type)) {
    type_routes <- route_type_ids(gtfs, route_type)
    type_trips <- gtfs$trips$trip_id[gtfs$trips$route_id %chin% type_routes]
    type_trips <- unique(type_trips[type_trips %chin% existing_trips])
    ids <- if (is.null(ids)) type_trips else intersect(ids, type_trips)
  }

  if (is.null(ids)) {
    rows <- seq_along(existing_trips)
  } else {
    rows <- which(existing_trips %chin% ids)
  }

  if (length(rows) == 0) {
    return(gtfs)
  }

  # the rows are ordered as in get_trip_length(), so that the segment starting
  # at the n-th stop of a trip is its n-th segment. a blank arrival or
  # departure is replaced by the other time of the stop. stops with any time
  # are 'timed'

  st <- gtfs$stop_times[
    rows,
    .(trip_id, stop_id, stop_sequence, arrival_time, departure_time)
  ]
  st[, row := rows]
  data.table::setorderv(st, c("trip_id", "stop_sequence"))
  st[, pos := data.table::rowid(trip_id)]
  st[, arr := string_to_seconds(arrival_time)]
  st[, dep := string_to_seconds(departure_time)]
  st[, t_dep := as.numeric(data.table::fcoalesce(dep, arr))]

  # find the positions of the first and last stops of the segment of each
  # trip, and keep only the trips that visit them, with times there, and that
  # depart from the first one within the time of day. trips that don't visit
  # the segment are only reported if they were explicitly selected

  if (has_stop_args || has_window) {
    if (has_stop_args) {
      trips <- st[,
        {
          start <- if (is.null(first_stop)) 1L else match(first_stop, stop_id)
          end <- if (is.null(last_stop)) {
            .N
          } else {
            which(stop_id == last_stop & pos > start)[1L]
          }

          list(
            start = start,
            end = end,
            dep_start = t_dep[start],
            end_is_timed = !is.na(t_dep[end])
          )
        },
        by = trip_id
      ]

      without_segment <- is.na(trips$start) |
        is.na(trips$end) |
        trips$end <= trips$start
      if (!is.null(first_stop)) {
        without_segment <- without_segment | is.na(trips$dep_start)
      }
      if (!is.null(last_stop)) {
        without_segment <- without_segment | !trips$end_is_timed
      }
      without_segment[is.na(without_segment)] <- TRUE
    } else {
      trips <- st[
        pos == 1L,
        .(trip_id, start = 1L, end = Inf, dep_start = t_dep)
      ]
      without_segment <- rep(FALSE, nrow(trips))
    }

    in_window <- !is.na(trips$dep_start) &
      trips$dep_start >= from_secs &
      trips$dep_start <= to_secs
    in_window <- in_window | !has_window

    to_warn <- without_segment &
      (in_window | is.na(trips$dep_start)) &
      selected_by_id

    if (any(to_warn)) {
      trips_without_segment <- trips$trip_id[to_warn]
      abbreviated <- abbreviate_ids(trips_without_segment)
      cli::cli_warn(
        paste0(
          "{length(trips_without_segment)} trip{?s} {?doesn't/don't} visit ",
          "{.arg first_stop} and then {.arg last_stop}, or {?has/have} blank ",
          "times at them, so {?it was/they were} left unchanged: ",
          "{.val {abbreviated$shown}}{abbreviated$more}."
        ),
        class = "gtfstools_trips_without_segment"
      )
    }

    trips <- trips[!without_segment & in_window]

    if (nrow(trips) == 0) {
      return(gtfs)
    }

    ids <- trips$trip_id
    st <- st[trip_id %chin% ids]
  }

  # calculate the length of each segment between consecutive stops, which is
  # kept in the segment's first stop row

  segment_length <- get_trip_length(gtfs, ids, by = "segment", unit = "km")
  st[
    segment_length,
    on = c(trip_id = "trip_id", pos = "segment"),
    seg_length := i.length
  ]

  # each span between consecutive timed stops gets a label, the number of
  # timed stops up to its first stop, so its length is the sum of the lengths
  # of the segments with this label. a span that includes a segment with
  # unknown length has an NA length

  st[, label := cumsum(!is.na(t_dep))]

  span_length <- st[, .(span_len = sum(seg_length)), by = .(trip_id, label)]

  # each timed stop ends the span labelled one less than itself, which starts
  # at the previous timed stop of the trip. the first timed stop of each trip
  # ends no span, so its extra time is 0

  timed <- st[!is.na(t_dep)]
  timed[, t_arr := as.numeric(data.table::fcoalesce(arr, dep))]
  timed[, prev_label := label - 1L]
  timed[
    span_length,
    on = c(trip_id = "trip_id", prev_label = "label"),
    span_len := i.span_len
  ]

  # capped spans last at least their length divided by the limit, rounded up,
  # and raised ones at most that, rounded down, so that their speed respects
  # the limit. raising spans of length 0 would remove the time spent between
  # stops at the same place, so they are left unchanged. the extra time of
  # raised spans is negative

  is_first <- data.table::rowid(timed$trip_id) == 1L
  span_dur <- timed$t_arr - data.table::shift(timed$t_dep)
  if (is_max) {
    min_dur <- ceiling(timed$span_len / limit_kmh * 3600)
    extra <- pmax(min_dur - span_dur, 0)
  } else {
    max_dur <- floor(timed$span_len / limit_kmh * 3600)
    extra <- -pmax(span_dur - max_dur, 0)
    extra[!is.na(timed$span_len) & timed$span_len <= 0] <- 0
  }
  extra[is_first | is.na(extra)] <- 0

  # spans that end before they start have invalid times, which are not
  # replaced by made-up ones. spans whose length is unknown are left unchanged
  # anyway, so they are not reported

  is_backwards <- !is_first &
    !is.na(span_dur) &
    span_dur < 0 &
    !is.na(timed$span_len)

  # only the spans inside the segment, which end at a stop after its first
  # stop and up to its last one, are capped

  if (has_stop_args || has_window) {
    trip_index <- match(timed$trip_id, trips$trip_id)
    in_segment <- timed$pos > trips$start[trip_index] &
      timed$pos <= trips$end[trip_index]
    extra[!in_segment] <- 0
    is_backwards <- is_backwards & in_segment
  }

  extra[is_backwards] <- 0

  if (any(is_backwards)) {
    backwards_trips <- unique(timed$trip_id[is_backwards])
    abbreviated <- abbreviate_ids(backwards_trips)
    changed <- if (is_max) "capped" else "raised"
    cli::cli_warn(
      c(
        paste0(
          "{length(backwards_trips)} trip{?s} {?has/have} stops whose ",
          "arrival is earlier than the previous departure, so {?its/their} ",
          "speed{?s} {?was/were} not ", changed, " between them: ",
          "{.val {abbreviated$shown}}{abbreviated$more}."
        ),
        "i" = paste0(
          "Times that go back by 12 hours or less are not taken as times ",
          "after midnight (see {.fn fix_overnight_times})."
        )
      ),
      class = "gtfstools_backwards_times"
    )
  }

  # the delay of each stop is the extra time accumulated up to it in its trip
  # (negative when raising speeds). shifting a span doesn't change the
  # duration of the following ones, so the delays don't depend on each other

  cum_extra <- cumsum(extra)
  trip_start <- cumsum(is_first)
  timed[, delay := cum_extra - (cum_extra - extra)[is_first][trip_start]]

  timed <- timed[delay != 0]

  if (nrow(timed) == 0) {
    return(gtfs)
  }

  # seconds_to_string() can't write times later than 9999:59:59 or earlier
  # than 00:00:00. the latter usually happens after a span that ends before
  # it starts. the calls to cli_abort() must be evaluated directly in this
  # function's body, so that the errors are attributed to its caller

  if (is_max) {
    is_invalid <- pmax(timed$arr, timed$dep, na.rm = TRUE) + timed$delay >
      max_time_secs

    if (any(is_invalid)) {
      invalid_trips <- unique(timed$trip_id[is_invalid])
      abbreviated <- abbreviate_ids(invalid_trips)
      cli::cli_abort(
        paste0(
          "Capping the speed results in times later than {.val 9999:59:59} ",
          "in the following {cli::qty(length(invalid_trips))}trip{?s}: ",
          "{.val {abbreviated$shown}}{abbreviated$more}."
        ),
        class = "gtfstools_time_out_of_range",
        call = parent.frame()
      )
    }
  } else {
    is_invalid <- pmin(timed$arr, timed$dep, na.rm = TRUE) + timed$delay < 0

    if (any(is_invalid)) {
      invalid_trips <- unique(timed$trip_id[is_invalid])
      abbreviated <- abbreviate_ids(invalid_trips)
      cli::cli_abort(
        c(
          paste0(
            "Raising the speed results in times earlier than ",
            "{.val 00:00:00} in the following ",
            "{cli::qty(length(invalid_trips))}trip{?s}: ",
            "{.val {abbreviated$shown}}{abbreviated$more}."
          ),
          "i" = paste0(
            "This usually happens when times after midnight are written as ",
            "{.val 00:30:00} instead of {.val 24:30:00}."
          )
        ),
        class = "gtfstools_time_out_of_range",
        call = parent.frame()
      )
    }
  }

  # shift the non-blank times of the delayed stops

  stop_times <- data.table::copy(gtfs$stop_times)

  has_arr <- !is.na(timed$arr)
  stop_times[
    timed$row[has_arr],
    arrival_time := seconds_to_string(
      as.integer(timed$arr[has_arr] + timed$delay[has_arr])
    )
  ]

  has_dep <- !is.na(timed$dep)
  stop_times[
    timed$row[has_dep],
    departure_time := seconds_to_string(
      as.integer(timed$dep[has_dep] + timed$delay[has_dep])
    )
  ]

  # refresh pre-existing *_secs columns, which other functions use as-is

  refresh_secs_columns(
    stop_times,
    c("departure_time", "arrival_time"),
    timed$row
  )

  gtfs$stop_times <- stop_times
  return(gtfs)
}
