#' Set trip average speed
#'
#' Sets the average speed of each specified `trip_id`, or of a segment of it,
#' by changing the `arrival_time` and `departure_time` columns in `stop_times`.
#'
#' @template gtfs
#' @param trip_id A string vector including the `trip_id`s to have their
#'   average speed set. If `NULL` (the default), `route_type` must be given,
#'   and the speed of every trip of these types is set.
#' @param speed A numeric representing the speed to be set. Its length must
#'   either equal 1, in which case the value is recycled for all
#'   `trip_id`s, or equal `trip_id`'s length. Must be positive and finite. A
#'   `trip_id` listed more than once must be given the same speed. Must be a
#'   single number when `trip_id` is `NULL`.
#' @param unit A string representing the unit in which the speed is given. One
#'   of `"km/h"` (the default), `"m/s"` or `"mph"` (miles per hour).
#' @param first_stop A string. The `stop_id` where the segment whose speed is
#'   set starts. If `NULL` (the default), the segment starts at each trip's
#'   first stop.
#' @param last_stop A string. The `stop_id` where the segment ends. If `NULL`
#'   (the default), the segment ends at each trip's last stop.
#' @param from A string, in the "HH:MM:SS" format. Only trips that depart from
#'   the segment's first stop at or after `from` are changed. If `NULL` (the
#'   default), there is no lower limit.
#' @param to A string, in the "HH:MM:SS" format. Only trips that depart from
#'   the segment's first stop at or before `to` are changed. If `NULL` (the
#'   default), there is no upper limit.
#' @param route_type An integer vector of `route_type`s (see
#'   [filter_by_route_type()]). If given, only trips of routes of these types
#'   are changed; together with the other selection arguments, it restricts
#'   their selection. `route_type`s not listed in `routes` are ignored. If
#'   `NULL` (the default), trips of any type are changed.
#' @param by_reference Whether to update `stop_times`' `data.table` by
#'   reference. Defaults to `FALSE`.
#'
#' @return If `by_reference` is set to `FALSE`, returns a GTFS object with the
#'   time columns of its `stop_times` adjusted. Else, returns a GTFS object
#'   invisibly (note that in this case the original GTFS object is altered).
#'
#' @section Details:
#' The duration of each trip's segment, from the departure at `first_stop` to
#' the arrival at `last_stop`, is set to its length divided by `speed`.
#' Lengths are calculated by [get_trip_length()] along the trip's shape, or as
#' straight lines between stops, with a warning, if there are no shapes; the
#' `stops` table is required. Trips whose length is `NA` (e.g. not linked to a
#' shape) are left unchanged.
#'
#' The times at stops strictly inside the segment are set to `""` (written as
#' `NA` by [write_gtfs()]). Times after `last_stop` are shifted by the change
#' in the segment's duration. Dwell times at `first_stop` and `last_stop` are
#' kept, except at the trip's first and last stops, whose dwell time becomes
#' 0. `first_stop` is matched at its first visit in `stop_sequence` order, and
#' `last_stop` at its next visit after that (which may be the same stop).
#' Blank times at `last_stop` are filled if it's the trip's last stop.
#'
#' With `first_stop` or `last_stop`, trips that don't visit `first_stop` and
#' then `last_stop`, or whose departure at `first_stop` is blank, or whose
#' times at `last_stop` are both blank (unless it's the trip's last stop), are
#' left unchanged, with a warning if they were given in `trip_id`. Without
#' `first_stop`, `last_stop`, `from` and `to`, a blank departure at the trip's
#' first stop leaves all the times of the trip blank, without a warning.
#'
#' `from` and `to` are compared with the `departure_time` at `first_stop` as
#' written in `stop_times` (template times, for trips listed in
#' `frequencies`), so use times past `"24:00:00"` for departures after
#' midnight; trips whose departure there is blank are then left unchanged.
#' Existing `_secs` columns in `stop_times` are updated to match.
#'
#' @seealso [set_route_speed()], [get_trip_speed()], [get_route_speed()]
#'
#' @examplesIf requireNamespace("dplyr", quietly = TRUE)
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#' }
#' library(dplyr)
#'
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#'
#' gtfs <- read_gtfs(data_path)
#'
#' gtfs_new_speed <- set_trip_speed(gtfs, trip_id = "CPTM L07-0", 50)
#' gtfs_new_speed$stop_times |>
#'   filter(trip_id == "CPTM L07-0")
#'
#' # use the unit argument to change the speed unit
#' gtfs_new_speed <- set_trip_speed(
#'   gtfs,
#'   trip_id = "CPTM L07-0",
#'   speed = 15,
#'   unit = "m/s"
#' )
#' gtfs_new_speed$stop_times |>
#'   filter(trip_id == "CPTM L07-0")
#'
#' # set the speed only between two stops. later stops are shifted
#' gtfs_new_speed <- set_trip_speed(
#'   gtfs,
#'   trip_id = "CPTM L07-0",
#'   speed = 30,
#'   first_stop = "18917",
#'   last_stop = "18922"
#' )
#' gtfs_new_speed$stop_times |>
#'   filter(trip_id == "CPTM L07-0")
#'
#' # set the speed only of the trips that depart within a time of day
#' poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
#' poa_gtfs <- read_gtfs(poa_path)
#'
#' poa_new_speed <- set_trip_speed(
#'   poa_gtfs,
#'   trip_id = poa_gtfs$trips$trip_id,
#'   speed = 25,
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#'
#' # the arrival at the last stop of a trip that departs at 07:02 changes
#' poa_gtfs$stop_times |>
#'   filter(trip_id == "T2-1@1#702") |>
#'   slice_tail(n = 1)
#'
#' poa_new_speed$stop_times |>
#'   filter(trip_id == "T2-1@1#702") |>
#'   slice_tail(n = 1)
#'
#' # original gtfs remains unchanged
#' gtfs$stop_times |>
#'   filter(trip_id == "CPTM L07-0")
#'
#' # when doing by reference, original gtfs is changed
#' set_trip_speed(gtfs, trip_id = "CPTM L07-0", 50, by_reference = TRUE)
#'
#' gtfs$stop_times |>
#'   filter(trip_id == "CPTM L07-0")
#' \dontshow{data.table::setDTthreads(old_dt_threads)}
#'
#' @export
set_trip_speed <- function(
  gtfs,
  trip_id = NULL,
  speed,
  unit = "km/h",
  first_stop = NULL,
  last_stop = NULL,
  from = NULL,
  to = NULL,
  route_type = NULL,
  by_reference = FALSE
) {
  gtfs <- assert_and_assign_gtfs_object(gtfs, by_reference = by_reference)
  if (is.null(trip_id) && is.null(route_type)) {
    cli::cli_abort(
      "At least one of {.arg trip_id} and {.arg route_type} must be given.",
      class = "gtfstools_missing_selection_error"
    )
  }
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  if (is.null(trip_id)) {
    checkmate::assert_number(speed)
  } else {
    checkmate::assert(
      checkmate::check_number(speed),
      checkmate::check_numeric(
        speed,
        len = length(trip_id),
        any.missing = FALSE
      ),
      combine = "or"
    )
  }
  if (any(speed <= 0 | !is.finite(speed))) {
    cli::cli_abort(
      "{.arg speed} must be positive and finite.",
      class = "gtfstools_invalid_speed"
    )
  }
  if (length(speed) > 1) {
    first_speed <- speed[match(trip_id, trip_id)]
    if (any(speed != first_speed)) {
      conflicting_ids <- unique(trip_id[speed != first_speed])
      cli::cli_abort(
        paste0(
          "Different speeds were given to the same trip{?s}: ",
          "{.val {conflicting_ids}}."
        ),
        class = "gtfstools_conflicting_speeds"
      )
    }
  }
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
  checkmate::assert_logical(by_reference, any.missing = FALSE, len = 1)

  window <- dwell_time_window(from, to)
  from_secs <- window[1]
  to_secs <- window[2]

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time", "stop_sequence"),
    c("character", "character", "character", "integer")
  )

  # with route_type, only trips of these types are changed. without trip_id,
  # these are the selected trips (only those with stop times, so that
  # get_trip_length() doesn't warn about the others). warnings about trips
  # without the segment are only raised for trips the user listed

  selected_by_id <- !is.null(trip_id)

  if (!is.null(route_type)) {
    type_routes <- route_type_ids(gtfs, route_type)
    type_trips <- gtfs$trips$trip_id[gtfs$trips$route_id %chin% type_routes]

    if (is.null(trip_id)) {
      trip_id <- unique(type_trips[type_trips %chin% gtfs$stop_times$trip_id])
    }
  }

  # calculate the length of each segment between consecutive stops of the
  # given trip_ids. trips whose length couldn't be calculated (e.g. trips not
  # linked to a shape) are left unchanged

  segment_length <- get_trip_length(
    gtfs,
    trip_id,
    by = "segment",
    unit = "km"
  )

  # calculations use km/h

  if (length(speed) == 1) {
    speed <- rep(speed, length(trip_id))
  }
  speed <- speed * speed_unit_factors[[unit]]
  names(speed) <- trip_id

  # if by_reference is set to FALSE, make a copy of stop_times

  if (by_reference) {
    stop_times <- gtfs$stop_times
  } else {
    stop_times <- data.table::copy(gtfs$stop_times)
  }

  # select the rows of the given trips, ordered as in get_trip_length(), so
  # that the segment starting at the n-th stop of a trip is its n-th segment.
  # 'which = TRUE' returns row numbers of stop_times (.I in a j filtered by i
  # would number the rows of the subset instead)

  ids <- trip_id
  if (!is.null(route_type)) ids <- ids[ids %chin% type_trips]
  rows <- stop_times[trip_id %chin% ids, which = TRUE]

  st <- stop_times[
    rows,
    .(trip_id, stop_id, stop_sequence, arrival_time, departure_time)
  ]
  st[, row := rows]
  data.table::setorderv(st, c("trip_id", "stop_sequence"))
  st[, pos := data.table::rowid(trip_id)]
  st[
    segment_length,
    on = c(trip_id = "trip_id", pos = "segment"),
    seg_length := i.length
  ]

  if (nrow(st) > 0) {
    # find the first and last stops of the segment of each trip. single-stop
    # trips have a length of 0, as in get_trip_length(by = "trip")

    has_stop_args <- !is.null(first_stop) || !is.null(last_stop)

    trips <- st[,
      {
        start <- if (is.null(first_stop)) 1L else match(first_stop, stop_id)
        end <- if (is.null(last_stop)) {
          .N
        } else {
          which(stop_id == last_stop & pos > start)[1L]
        }
        arr_end <- arrival_time[end]
        if (is.na(arr_end) || arr_end == "") {
          arr_end <- departure_time[end]
        }

        list(
          start = start,
          end = end,
          is_last = end == .N,
          length = sum(seg_length[pos >= start & pos < end]),
          dep_start = departure_time[start],
          arr_end = arr_end
        )
      },
      by = trip_id
    ]

    # under the default arguments, a blank departure at the first stop is kept
    # as NA and becomes "" at the last stop, as before the segment arguments
    # were added. trips departing outside the time of day are left unchanged
    # without a warning

    trips[, dep_secs := string_to_seconds(dep_start)]
    has_window <- !is.null(from) || !is.null(to)
    in_window <- !is.na(trips$dep_secs) &
      trips$dep_secs >= from_secs &
      trips$dep_secs <= to_secs
    in_window <- in_window | !has_window

    is_blank <- function(x) is.na(x) | x == ""
    without_segment <- is.na(trips$start) | is.na(trips$end)
    if (has_stop_args) {
      without_segment <- without_segment |
        trips$end <= trips$start |
        is_blank(trips$dep_start) |
        (!trips$is_last & is_blank(trips$arr_end))
    }
    without_segment[is.na(without_segment)] <- TRUE

    to_warn <- without_segment &
      (in_window | is.na(trips$dep_secs)) &
      selected_by_id
    if (any(to_warn)) {
      trips_without_segment <- trips$trip_id[to_warn]
      cli::cli_warn(
        paste0(
          "{length(trips_without_segment)} trip{?s} {?doesn't/don't} visit ",
          "{.arg first_stop} and then {.arg last_stop}, or {?has/have} blank ",
          "times at them, so {?it was/they were} left unchanged: ",
          "{.val {trips_without_segment}}."
        ),
        class = "gtfstools_trips_without_segment"
      )
    }

    trips <- trips[!without_segment & !is.na(length) & in_window]

    # calculate the new arrival at the segment's last stop and the change in
    # the segment's duration, by which the following times are shifted

    trips[, new_arr := dep_secs + as.integer(length / speed[trip_id] * 3600)]
    trips[is_last == FALSE, delta := new_arr - string_to_seconds(arr_end)]

    st <- st[
      trips[, .(trip_id, start, end, is_last, new_arr, delta)],
      on = "trip_id",
      nomatch = NULL
    ]

    # blank the times inside the segment, make the trip's first stop arrival
    # equal its departure, and shift the times after the segment

    stop_times[
      st[pos > start & pos < end, row],
      `:=`(arrival_time = "", departure_time = "")
    ]
    stop_times[st[pos == 1L & start == 1L, row], arrival_time := departure_time]

    shifted <- st[is_last == FALSE & pos >= end]
    for (time_col in c("arrival_time", "departure_time")) {
      to_shift <- shifted[pos > end | time_col == "departure_time"]
      secs <- string_to_seconds(stop_times[[time_col]][to_shift$row]) +
        to_shift$delta
      stop_times[
        to_shift$row[!is.na(secs)],
        (time_col) := seconds_to_string(secs[!is.na(secs)])
      ]
    }

    # set the arrival at the segment's last stop. if it's the trip's last
    # stop, its departure is set to the same time

    ends <- st[pos == end]
    stop_times[ends$row, arrival_time := seconds_to_string(ends$new_arr)]
    stop_times[
      ends[is_last == TRUE, row],
      departure_time := seconds_to_string(ends[is_last == TRUE, new_arr])
    ]

    # refresh pre-existing *_secs columns, which other functions use as-is

    refresh_secs_columns(
      stop_times,
      c("departure_time", "arrival_time"),
      st$row
    )
  }

  if (by_reference) {
    return(invisible(gtfs))
  }

  gtfs$stop_times <- stop_times
  return(gtfs)
}
