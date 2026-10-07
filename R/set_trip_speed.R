#' Set trip average speed
#'
#' Sets the average speed of each specified `trip_id`, or of a segment of it,
#' by changing the `arrival_time` and `departure_time` columns in `stop_times`.
#'
#' @template gtfs
#' @param trip_id A string vector including the `trip_id`s to have their
#'   average speed set.
#' @param speed A numeric representing the speed to be set. Its length must
#'   either equal 1, in which case the value is recycled for all
#'   `trip_id`s, or equal `trip_id`'s length.
#' @param unit A string representing the unit in which the speed is given. One
#'   of `"km/h"` (the default) or `"m/s"`.
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
#' @param by_reference Whether to update `stop_times`' `data.table` by
#'   reference. Defaults to `FALSE`.
#'
#' @return If `by_reference` is set to `FALSE`, returns a GTFS object with the
#'   time columns of its `stop_times` adjusted. Else, returns a GTFS object
#'   invisibly (note that in this case the original GTFS object is altered).
#'
#' @section Details:
#' The duration of each trip's segment (from the departure at `first_stop` to
#' the arrival at `last_stop`; by default the whole trip) is set to its length,
#' as calculated by [get_trip_length()] along the trip's shape (or as straight
#' lines between stops, with a warning, if there are no shapes), divided by
#' `speed`. The `stops` table is required. Trips whose length is `NA` (e.g.
#' trips not linked to a shape) are left unchanged.
#'
#' The arrival and departure times at stops strictly inside the segment are set
#' to `""`, which is written as `NA` by [write_gtfs()]. Some routing software,
#' such as [OpenTripPlanner](http://www.opentripplanner.org/), interpolates
#' these times from the average speed.
#'
#' `first_stop` is matched at its first visit in `stop_sequence` order, and
#' `last_stop` at its next visit after that (which may be the same stop). Times
#' after `last_stop` are shifted by the change in the segment's duration. Dwell
#' times at `first_stop` and `last_stop` are kept, except at the trip's first
#' and last stops. Trips that don't visit `first_stop` and then `last_stop`, or
#' that have blank times there, are left unchanged with a warning. `from` and
#' `to` are compared with the `departure_time` at `first_stop` as written in
#' `stop_times`, so use times past `"24:00:00"` for departures after midnight.
#' For trips listed in `frequencies`, these are template times, not actual
#' departures. Trips whose departure there is blank are left unchanged.
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
#' gtfs_new_speed <- set_trip_speed(gtfs, trip_id = "CPTM L07-0", 50)
#' gtfs_new_speed$stop_times[trip_id == "CPTM L07-0"]
#'
#' # use the unit argument to change the speed unit
#' gtfs_new_speed <- set_trip_speed(
#'   gtfs,
#'   trip_id = "CPTM L07-0",
#'   speed = 15,
#'   unit = "m/s"
#' )
#' gtfs_new_speed$stop_times[trip_id == "CPTM L07-0"]
#'
#' # set the speed only between two stops. later stops are shifted
#' gtfs_new_speed <- set_trip_speed(
#'   gtfs,
#'   trip_id = "CPTM L07-0",
#'   speed = 30,
#'   first_stop = "18917",
#'   last_stop = "18922"
#' )
#' gtfs_new_speed$stop_times[trip_id == "CPTM L07-0"]
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
#' # the arrival at the last stop of a trip that departs at 07:02 changes
#' poa_gtfs$stop_times[trip_id == "T2-1@1#702"][.N]
#' poa_new_speed$stop_times[trip_id == "T2-1@1#702"][.N]
#'
#' # original gtfs remains unchanged
#' gtfs$stop_times[trip_id == "CPTM L07-0"]
#'
#' # when doing by reference, original gtfs is changed
#' set_trip_speed(gtfs, trip_id = "CPTM L07-0", 50, by_reference = TRUE)
#' gtfs$stop_times[trip_id == "CPTM L07-0"]
#'
#' @export
set_trip_speed <- function(gtfs,
                           trip_id,
                           speed,
                           unit = "km/h",
                           first_stop = NULL,
                           last_stop = NULL,
                           from = NULL,
                           to = NULL,
                           by_reference = FALSE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_number(speed),
    checkmate::check_numeric(speed, len = length(trip_id), any.missing = FALSE),
    combine = "or"
  )
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = c("km/h", "m/s")),
    combine = "and"
  )
  checkmate::assert_string(first_stop, min.chars = 1, null.ok = TRUE)
  checkmate::assert_string(last_stop, min.chars = 1, null.ok = TRUE)
  checkmate::assert_string(
    from,
    pattern = "^\\d{2}:[0-5]\\d:[0-5]\\d$",
    null.ok = TRUE
  )
  checkmate::assert_string(
    to,
    pattern = "^\\d{2}:[0-5]\\d:[0-5]\\d$",
    null.ok = TRUE
  )
  checkmate::assert_logical(by_reference, any.missing = FALSE, len = 1)

  from_secs <- if (is.null(from)) -Inf else string_to_seconds(from)
  to_secs <- if (is.null(to)) Inf else string_to_seconds(to)

  if (from_secs > to_secs) {
    cli::cli_abort(
      paste0(
        "{.arg from} ({.val {from}}) must not be later than {.arg to} ",
        "({.val {to}})."
      ),
      class = "gtfstools_invalid_time_of_day"
    )
  }

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time", "stop_sequence"),
    c("character", "character", "character", "integer")
  )

  # calculate the length of each segment between consecutive stops of the
  # given trip_ids. trips whose length couldn't be calculated (e.g. trips not
  # linked to a shape) are left unchanged

  segment_length <- get_trip_length(
    gtfs,
    trip_id,
    by = "segment",
    unit = "km"
  )

  # set speed adequate unit (use km/h for calculations)

  if (length(speed) == 1) speed <- rep(speed, length(trip_id))

  # issue #84 - only convert when needed, and never empty vectors (older
  # {units} versions read out of bounds when converting zero-length input)

  if (unit != "km/h" && length(speed) > 0) {
    units(speed) <- unit
    speed <- as.numeric(units::set_units(speed, "km/h"))
  }
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

    trips <- st[
      ,
      {
        start <- if (is.null(first_stop)) 1L else match(first_stop, stop_id)
        end <- if (is.null(last_stop)) {
          .N
        } else {
          which(stop_id == last_stop & pos > start)[1L]
        }
        arr_end <- arrival_time[end]
        if (is.na(arr_end) || arr_end == "") arr_end <- departure_time[end]

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

    to_warn <- without_segment & (in_window | is.na(trips$dep_secs))
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

    for (time_col in c("departure_time", "arrival_time")) {
      secs_col <- paste0(time_col, "_secs")
      if (secs_col %chin% names(stop_times)) {
        stop_times[
          st$row,
          (secs_col) := string_to_seconds(get(time_col))
        ]
      }
    }
  }

  if (by_reference) return(invisible(gtfs))

  gtfs$stop_times <- stop_times
  return(gtfs)
}
