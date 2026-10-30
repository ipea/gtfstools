#' Set dwell time
#'
#' Sets the dwell time of each specified `trip_id` at each specified `stop_id`,
#' i.e. the time the vehicle stays at the stop, by changing the
#' `departure_time` at these stops in `stop_times` and shifting the later times
#' of the trips accordingly.
#'
#' @template gtfs
#' @param dwell_time A non-negative number, the dwell time to be set, in
#'   `unit`. It's rounded to the nearest whole second and applies to every
#'   specified visit (call the function once per value to set different dwell
#'   times).
#' @param unit A string representing the time unit in which `dwell_time` is
#'   given. One of `"s"` (seconds, the default), `"min"` (minutes), `"h"`
#'   (hours) or `"d"` (days).
#' @param trip_id A character vector including the `trip_id`s to have their
#'   dwell times set. If `NULL` (the default), the dwell times of every
#'   `trip_id` in the GTFS (or of every trip of the given `route_type`s) are
#'   set.
#' @param stop_id A character vector including the `stop_id`s at which the
#'   dwell times are set. If `NULL` (the default), the dwell times are set at
#'   every `stop_id` in the GTFS.
#' @param from A string, in the "HH:MM:SS" format. Only visits whose arrival
#'   time is at or after `from` are changed. If `NULL` (the default), there is
#'   no lower limit.
#' @param to A string, in the "HH:MM:SS" format. Only visits whose arrival time
#'   is at or before `to` are changed. If `NULL` (the default), there is no
#'   upper limit.
#' @inheritParams set_trip_speed
#' @param by_reference Whether to update `stop_times`' `data.table` by
#'   reference. Defaults to `FALSE`.
#'
#' @return If `by_reference` is set to `FALSE`, returns a GTFS object with the
#'   time columns of its `stop_times` adjusted. Else, returns a GTFS object
#'   invisibly (note that in this case the original GTFS object is altered).
#'
#' @section Details:
#' The dwell time of a visit is its `departure_time` minus its `arrival_time`
#' in `stop_times`, as returned by [get_dwell_time()]. It is set at the visits
#' of every specified trip to every specified stop (not of pairs formed by
#' their elements): the arrival time is kept and the departure time is set to
#' the arrival time plus `dwell_time`. All the later times of the trip, in
#' `stop_sequence` order, are shifted by the change, and changes at several
#' visits of the same trip add up. At a trip's last stop, only the departure
#' time changes. A stop visited more than once by the same trip has its dwell
#' time set at each visit.
#'
#' Blank times are never filled. Selected visits with a blank arrival or
#' departure time are not changed and don't shift the later times, with a
#' warning when `stop_id` is given; fill them beforehand with
#' [interpolate_stop_times()]. An error is raised if a shift would result in a
#' negative time (times not in chronological order) or in a time later than
#' `"9999:59:59"`. `stop_sequence` is assumed to be unique within each trip
#' and not `NA`. When both `trip_id` and `stop_id` are given but none of the
#' trips visits any of the stops, a warning is raised and the GTFS is returned
#' unchanged.
#'
#' For trips listed in `frequencies`, the times in `stop_times` are a template
#' (see [frequencies_to_stop_times()]), so setting the dwell time at the first
#' stop only changes how long before each departure the vehicle arrives there,
#' while changes at later stops lengthen or shorten every departure.
#'
#' `from` and `to` are compared with the `arrival_time` of each visit as
#' written in `stop_times` before any change (template times, for trips listed
#' in `frequencies`), so use times past `"24:00:00"` for arrivals after
#' midnight. A shift caused by an earlier visit may thus move a changed visit
#' out of the time of day, or another visit into it. Visits with a blank
#' arrival time are never selected when `from` or `to` is given. When the time
#' of day contains no visit of the specified trips to the specified stops, the
#' GTFS is returned unchanged.
#'
#' `stop_id`s are matched against the `stop_id`s in `stop_times`, which are
#' never stations: to set the dwell times at a station, pass its children that
#' appear in `stop_times` (see [get_children_stops()]). Existing `_secs`
#' columns in `stop_times` (e.g. created with [convert_time_to_seconds()]) are
#' updated to match.
#'
#' @seealso [get_dwell_time()], [set_min_dwell_time()], [set_trip_speed()]
#'
#' @examplesIf requireNamespace("dplyr", quietly = TRUE)
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#' }
#' library(dplyr)
#'
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # set a 30 seconds dwell time at a stop of a trip. the later times of the
#' # trip are shifted by 30 seconds
#' new_gtfs <- set_dwell_time(
#'   gtfs,
#'   trip_id = "CPTM L07-0",
#'   stop_id = "18920",
#'   dwell_time = 30
#' )
#' new_gtfs$stop_times |>
#'   filter(trip_id == "CPTM L07-0") |>
#'   head()
#'
#' # set the dwell time at a stop in every trip that visits it. use the unit
#' # argument to give the dwell time in another unit
#' new_gtfs <- set_dwell_time(
#'   gtfs,
#'   stop_id = "18960",
#'   dwell_time = 1,
#'   unit = "min"
#' )
#' get_dwell_time(new_gtfs, stop_id = "18960")
#'
#' # set the dwell time only at the visits that arrive within a time of day
#' new_gtfs <- set_dwell_time(
#'   gtfs,
#'   trip_id = "CPTM L07-0",
#'   dwell_time = 30,
#'   from = "05:00:00",
#'   to = "06:00:00"
#' )
#' get_dwell_time(new_gtfs, trip_id = "CPTM L07-0")
#'
#' # original gtfs remains unchanged
#' get_dwell_time(gtfs, stop_id = "18960")
#'
#' # when doing by reference, original gtfs is changed
#' set_dwell_time(
#'   gtfs,
#'   trip_id = "CPTM L07-0",
#'   stop_id = "18920",
#'   dwell_time = 30,
#'   by_reference = TRUE
#' )
#' gtfs$stop_times |>
#'   filter(trip_id == "CPTM L07-0") |>
#'   head()
#' \dontshow{data.table::setDTthreads(old_dt_threads)}
#'
#' @export
set_dwell_time <- function(
  gtfs,
  dwell_time,
  unit = "s",
  trip_id = NULL,
  stop_id = NULL,
  from = NULL,
  to = NULL,
  route_type = NULL,
  by_reference = FALSE
) {
  gtfs <- assert_and_assign_gtfs_object(gtfs, by_reference = by_reference)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_character(stop_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_string(unit)
  checkmate::assert_names(unit, subset.of = names(dwell_unit_factors))
  checkmate::assert_number(
    dwell_time,
    lower = 0,
    upper = max_time_secs / dwell_unit_factors[[unit]]
  )
  window <- dwell_time_window(from, to)
  checkmate::assert_integerish(
    route_type,
    min.len = 1,
    any.missing = FALSE,
    null.ok = TRUE
  )
  checkmate::assert_logical(by_reference, any.missing = FALSE, len = 1)

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "stop_id", "stop_sequence", "arrival_time", "departure_time"),
    c("character", "character", "integer", "character", "character")
  )

  # a dwell time above the upper bound always results in a time that can't be
  # written. the accumulated changes are checked further below

  dwell_secs <- as.integer(round(dwell_time * dwell_unit_factors[[unit]]))

  gtfs <- change_dwell_times(
    gtfs,
    dwell_secs,
    trip_id,
    stop_id,
    window,
    route_type,
    by_reference
  )

  if (by_reference) {
    return(invisible(gtfs))
  }

  return(gtfs)
}



# sets the dwell time of the selected visits to 'dwell_secs' and shifts the
# later times of their trips, as described in set_dwell_time(). with
# 'raise_only', only shorter dwell times are raised, as described in
# set_min_dwell_time(). the arguments are validated by these functions

change_dwell_times <- function(
  gtfs,
  dwell_secs,
  trip_id,
  stop_id,
  window,
  route_type,
  by_reference,
  raise_only = FALSE
) {
  if (!is.null(route_type)) {
    type_routes <- route_type_ids(gtfs, route_type)
    type_trips <- gtfs$trips$trip_id[gtfs$trips$route_id %chin% type_routes]
  }

  if (by_reference) {
    stop_times <- gtfs$stop_times
  } else {
    stop_times <- data.table::copy(gtfs$stop_times)
  }

  selected_rows <- select_dwell_time_calls(stop_times, trip_id, stop_id)

  # ids missing from 'stop_times' were already reported by the helper

  if (length(selected_rows) == 0) {
    all_ids_exist <- !is.null(trip_id) &&
      !is.null(stop_id) &&
      all(trip_id %chin% stop_times$trip_id) &&
      all(stop_id %chin% stop_times$stop_id)

    if (all_ids_exist) {
      cli::cli_warn(
        "None of the given trips visits any of the given stops.",
        class = "gtfstools_no_calls_selected"
      )
    }
  }

  # route_type restricts the selected calls to trips of these types. it's
  # applied after the warning above, which is about the given ids only

  if (!is.null(route_type)) {
    selected_rows <- selected_rows[
      stop_times$trip_id[selected_rows] %chin% type_trips
    ]
  }

  if (length(selected_rows) > 0) {
    # all the calls of the affected trips are needed to order them and
    # accumulate the shifts. with no stop filter, every call of the selected
    # trips is itself selected

    if (is.null(stop_id)) {
      rows <- selected_rows
    } else {
      affected_trips <- unique(stop_times$trip_id[selected_rows])
      rows <- which(stop_times$trip_id %chin% affected_trips)
    }

    st <- stop_times[rows, .(trip_id, stop_sequence)]
    st[,
      `:=`(
        row = rows,
        selected = if (is.null(stop_id)) TRUE else rows %in% selected_rows,
        arr = string_to_seconds(stop_times$arrival_time[rows]),
        dep = string_to_seconds(stop_times$departure_time[rows])
      )
    ]

    # the time of day only narrows the selected visits. the other visits of
    # the trips stay in 'st', so that they are shifted. blank arrivals can't
    # be placed in the time of day, so they are not selected

    if (any(is.finite(window))) {
      st[,
        selected := selected &
          !is.na(arr) &
          arr >= window[1] &
          arr <= window[2]
      ]
    }

    # calls with a blank time have no dwell time to set. without a stop filter
    # these are usually untimed stops, so they are skipped silently

    is_blank <- st$selected & (is.na(st$arr) | is.na(st$dep))

    if (!is.null(stop_id) && any(is_blank)) {
      blank_trips <- unique(st$trip_id[is_blank])
      abbreviated <- abbreviate_ids(blank_trips)
      cli::cli_warn(
        paste0(
          "The dwell time was not set at {sum(is_blank)} call{?s} with a ",
          "blank arrival or departure time, in the following ",
          "{cli::qty(length(blank_trips))}trip{?s}: ",
          "{.val {abbreviated$shown}}{abbreviated$more}."
        ),
        class = "gtfstools_blank_dwell_time"
      )
    }

    # a minimum skips the first and last visits with both times, and raises
    # negative dwell times like any other shorter one. it comes after the
    # blank warning, which needs the selection before it's narrowed

    if (raise_only) {
      timed <- st[
        !is.na(arr) & !is.na(dep) & !is.na(trip_id) & !is.na(stop_sequence),
        c("row", "trip_id", "stop_sequence")
      ]
      data.table::setorderv(timed, c("trip_id", "stop_sequence"))
      is_middle <- duplicated(timed$trip_id) &
        duplicated(timed$trip_id, fromLast = TRUE)
      st[,
        selected := selected &
          row %in% timed$row[is_middle] &
          dep - arr < dwell_secs
      ]
    }

    # each selected call shifts its own departure and all the later times of
    # its trip by the change in its dwell time

    # the shifts are accumulated as doubles, so that a sum beyond the integer
    # range raises the error below instead of silently becoming NA

    st[, delta := 0]
    st[selected & !is_blank, delta := as.numeric(arr) + dwell_secs - dep]
    data.table::setorderv(st, c("trip_id", "stop_sequence"))
    st[, dep_shift := cumsum(delta), by = trip_id]
    st[, arr_shift := dep_shift - delta]

    st <- st[dep_shift != 0 | arr_shift != 0]
    st[, `:=`(new_arr = arr + arr_shift, new_dep = dep + dep_shift)]

    # check before writing, so that by_reference doesn't leave a half-edited
    # table behind

    is_out_of_range <- function(x) {
      return(!is.na(x) & (x < 0 | x > max_time_secs))
    }
    is_invalid <- is_out_of_range(st$new_arr) | is_out_of_range(st$new_dep)

    if (any(is_invalid)) {
      invalid_trips <- unique(st$trip_id[is_invalid])
      abbreviated <- abbreviate_ids(invalid_trips)
      cli::cli_abort(
        c(
          paste0(
            "Setting the dwell time results in negative times or times ",
            "later than {.val 9999:59:59} ",
            "in the following {cli::qty(length(invalid_trips))}trip{?s}: ",
            "{.val {abbreviated$shown}}{abbreviated$more}."
          ),
          "i" = paste0(
            "Negative times result from times that are not in chronological ",
            "order."
          )
        ),
        class = "gtfstools_time_out_of_range",
        call = parent.frame()
      )
    }

    st[, `:=`(new_arr = as.integer(new_arr), new_dep = as.integer(new_dep))]
    has_arr <- !is.na(st$new_arr) & st$arr_shift != 0
    has_dep <- !is.na(st$new_dep) & st$dep_shift != 0

    stop_times[
      st$row[has_arr],
      arrival_time := seconds_to_string(st$new_arr[has_arr])
    ]
    stop_times[
      st$row[has_dep],
      departure_time := seconds_to_string(st$new_dep[has_dep])
    ]

    # refresh pre-existing *_secs columns, which other functions use as-is

    if ("arrival_time_secs" %chin% names(stop_times)) {
      stop_times[st$row, arrival_time_secs := st$new_arr]
    }

    if ("departure_time_secs" %chin% names(stop_times)) {
      stop_times[st$row, departure_time_secs := st$new_dep]
    }
  }

  if (by_reference) {
    return(invisible(gtfs))
  }

  gtfs$stop_times <- stop_times
  return(gtfs)
}
