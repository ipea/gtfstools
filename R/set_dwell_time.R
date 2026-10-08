#' Set dwell time
#'
#' Sets the dwell time of each specified `trip_id` at each specified `stop_id`,
#' i.e. the time the vehicle stays at the stop, by changing the
#' `departure_time` at these stops in `stop_times` and shifting the later times
#' of the trips accordingly.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#'   dwell times set. If `NULL` (the default), the dwell times of every
#'   `trip_id` in the GTFS are set.
#' @param stop_id A character vector including the `stop_id`s at which the
#'   dwell times are set. If `NULL` (the default), the dwell times are set at
#'   every `stop_id` in the GTFS.
#' @param dwell_time A non-negative number, the dwell time to be set, in
#'   `unit`. It's rounded to the nearest whole second and applies to every
#'   specified visit (call the function once per value to set different dwell
#'   times).
#' @param unit A string representing the time unit in which `dwell_time` is
#'   given. One of `"s"` (seconds, the default), `"min"` (minutes), `"h"`
#'   (hours) or `"d"` (days).
#' @param from A string, in the "HH:MM:SS" format. Only visits whose arrival
#'   time is at or after `from` are changed. If `NULL` (the default), there is
#'   no lower limit.
#' @param to A string, in the "HH:MM:SS" format. Only visits whose arrival time
#'   is at or before `to` are changed. If `NULL` (the default), there is no
#'   upper limit.
#' @param by_reference Whether to update `stop_times`' `data.table` by
#'   reference. Defaults to `FALSE`.
#'
#' @return If `by_reference` is set to `FALSE`, returns a GTFS object with the
#'   time columns of its `stop_times` adjusted. Else, returns a GTFS object
#'   invisibly (note that in this case the original GTFS object is altered).
#'
#' @section Details:
#' The dwell time of a trip at a stop is the time difference between the
#' `departure_time` and the `arrival_time` of that visit in `stop_times`, as
#' returned by [get_dwell_time()]. The function sets it at the visits of every
#' specified trip to every specified stop (not of pairs formed by their
#' elements), within the time of day if `from` or `to` is given. At each of
#' these visits, the arrival time is kept and the departure time is set to the
#' arrival time plus `dwell_time`. All the later times of the trip, in
#' `stop_sequence` order, are shifted by the change in the dwell time, so the
#' travel times between stops are kept and the trip ends earlier or later.
#' Changes at several visits of the same trip add up.
#'
#' Setting the dwell time at a trip's first stop shifts the rest of the trip.
#' At its last stop, only the departure time changes. A stop visited more than
#' once by the same trip (e.g. in a loop) has its dwell time set at each visit.
#'
#' Blank times are never filled, and later blank times stay blank. Selected
#' visits with a blank arrival or departure time have no dwell time to change,
#' so their dwell time is not set and they don't shift the later times. When
#' `stop_id` is given, this raises a warning. Use [interpolate_stop_times()]
#' to fill blank times beforehand. The function raises an error if a shift
#' would result in a negative time, which only happens when the times of a
#' trip are not in chronological order, or in a time later than
#' `"9999:59:59"`, the latest time that can be written. The visits of each trip
#' are ordered by `stop_sequence`, which is assumed to be unique within each
#' trip and not `NA`, as required by the GTFS specification. When both
#' `trip_id` and `stop_id` are given, but none of the trips visits any of the
#' stops, the function raises a warning and returns the GTFS unchanged.
#'
#' For trips listed in `frequencies`, the times in `stop_times` are a template:
#' the trips depart at the times listed in `frequencies`, starting from their
#' first departure (see [frequencies_to_stop_times()]). Setting the dwell time
#' at the first stop of such a trip therefore changes only how long before each
#' departure the vehicle arrives there, while changes at later stops lengthen
#' or shorten every departure of the trip.
#'
#' `from` and `to` are compared with the `arrival_time` of each visit, as
#' written in `stop_times` before any change, so use times past `"24:00:00"`
#' for arrivals after midnight. A shift caused by an earlier visit may thus
#' move a changed visit out of the time of day, or another visit into it. For
#' trips listed in `frequencies`, these are template times, not the times of
#' each departure. Visits with a blank arrival time are never selected when
#' `from` or `to` is given, so they don't raise the warning above. When the
#' time of day contains no visit of the specified trips to the specified
#' stops, the GTFS is returned unchanged.
#'
#' `stop_id`s are matched exactly against the `stop_id`s in `stop_times`, which
#' are never stations. To set the dwell times at a station, use
#' [get_children_stops()] to list its children and pass those that appear in
#' `stop_times`.
#'
#' Changed times are written in the "HH:MM:SS" format. Existing `_secs` columns
#' in `stop_times` (e.g. created with [convert_time_to_seconds()]) are updated
#' to match.
#'
#' @seealso [get_dwell_time()], [set_trip_speed()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
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
#' head(new_gtfs$stop_times[trip_id == "CPTM L07-0"])
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
#' head(gtfs$stop_times[trip_id == "CPTM L07-0"])
#'
#' @export
set_dwell_time <- function(gtfs,
                           trip_id = NULL,
                           stop_id = NULL,
                           dwell_time,
                           unit = "s",
                           from = NULL,
                           to = NULL,
                           by_reference = FALSE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
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
  } else {
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
    st[
      ,
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
      st[
        ,
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
        class = "gtfstools_time_out_of_range"
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

  if (by_reference) return(invisible(gtfs))

  gtfs$stop_times <- stop_times
  return(gtfs)
}
