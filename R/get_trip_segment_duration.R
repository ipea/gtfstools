#' Get trip segments' duration
#'
#' Returns the duration of segments between stops of each specified `trip_id`.
#'
#' @template gtfs
#' @param trip_id A string vector including the `trip_id`s to have their
#'   segments' duration calculated. If `NULL` (the default) the function
#'   calculates the segments' duration of every `trip_id` in the GTFS.
#' @param unit A string representing the time unit in which the duration is
#'   desired. One of `"s"` (seconds), `"min"` (minutes, the default),
#'   `"h"` (hours) or `"d"` (days).
#' @param sort_sequence Deprecated; do not supply. Timetables are now always
#'   sorted by `stop_sequence`. Passing `TRUE` raises a warning, and passing
#'   `FALSE` raises an error.
#' @param from A string, in the "HH:MM:SS" format. Only segments that depart
#'   from their first stop at or after `from` are included. If `NULL` (the
#'   default), there is no lower limit.
#' @param to A string, in the "HH:MM:SS" format. Only segments that depart from
#'   their first stop at or before `to` are included. If `NULL` (the default),
#'   there is no upper limit.
#'
#' @return A `data.table` containing the segments' duration of each specified
#'   trip.
#'
#' @section Details:
#' A trip segment is defined as the path between two subsequent stops in the
#' same trip. The  duration of a segment is defined as the time difference
#' between its arrival time and its departure time, as specified in the
#' `stop_times` file.
#'
#' Existing `_secs` columns in `stop_times` (e.g. created with
#' [convert_time_to_seconds()]) are used as-is, not recalculated from the time
#' strings.
#'
#' Times after midnight written as early morning times (e.g. `"00:30:00"`
#' instead of `"24:30:00"`) are fixed with [fix_overnight_times()] before the
#' durations are calculated.
#'
#' `from` and `to` are compared with the departure time of the first stop of
#' each segment, read as the durations are (from `departure_time_secs`, if
#' present), so use times past `"24:00:00"` for departures after midnight.
#' For trips listed in `frequencies`, these are template times, not the times
#' of each departure. Segments whose departure is blank are never included
#' when `from` or `to` is given.
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
#' trip_segment_dur <- get_trip_segment_duration(gtfs)
#' head(trip_segment_dur)
#'
#' # use the trip_id argument to control which trips are analyzed
#' trip_segment_dur <- get_trip_segment_duration(gtfs, trip_id = "CPTM L07-0")
#' trip_segment_dur
#'
#' # use the unit argument to control in which unit the durations are calculated
#' trip_segment_dur <- get_trip_segment_duration(gtfs, "CPTM L07-0", unit = "s")
#' trip_segment_dur
#'
#' # use the from and to arguments to keep only the segments that depart
#' # within a time of day
#' trip_segment_dur <- get_trip_segment_duration(
#'   gtfs,
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#' head(trip_segment_dur)
#'
#' @export
get_trip_segment_duration <- function(gtfs,
                                      trip_id = NULL,
                                      unit = "min",
                                      sort_sequence,
                                      from = NULL,
                                      to = NULL) {
  if (!missing(sort_sequence)) {
    check_deprecated_sort_sequence(
      sort_sequence,
      "get_trip_segment_duration",
      "stop_sequence"
    )
  }

  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = names(dwell_unit_factors)),
    combine = "and"
  )
  window <- dwell_time_window(from, to)

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time", "stop_sequence"),
    c("character", "character", "character", "integer")
  )

  # times after midnight written as early morning times are fixed first, so
  # they don't go back

  gtfs <- fix_overnight_in_call(gtfs = gtfs, trip_id = trip_id)

  # select the trips to get the segments' durations of and raise a warning if
  # a given trip_id doesn't exist in 'stop_times'

  stop_times <- gtfs$stop_times

  if (!is.null(trip_id)) {
    warn_missing_ids(trip_id, stop_times$trip_id, "stop_times", "trip_id")

    # the selection index is created outside of `[` so that {data.table}
    # doesn't add an index to the given table

    is_relevant <- stop_times$trip_id %chin% trip_id
    stop_times <- stop_times[which(is_relevant)]
  }

  # the times in seconds go into a new table (using the existing '_secs'
  # columns, if any), so that the given 'stop_times' is never modified.
  # data.table() copies the vectors, so sorting the new table is safe

  durations <- data.table::data.table(
    trip_id = stop_times$trip_id,
    stop_sequence = stop_times$stop_sequence,
    departure_time_secs = time_secs(stop_times, "departure_time"),
    arrival_time_secs = time_secs(stop_times, "arrival_time")
  )
  data.table::setorderv(durations, c("trip_id", "stop_sequence"))

  # each stop but the last of each trip starts a segment, in the order the
  # segments are returned below. the rows of each trip are contiguous after
  # sorting, so the last stop is the last row with its trip_id (NAs included)

  is_windowed <- any(is.finite(window))
  is_last_stop <- !duplicated(durations$trip_id, fromLast = TRUE)

  if (is_windowed) {
    segment_departure <- durations$departure_time_secs[!is_last_stop]
  }

  # each segment's duration runs from the departure at its first stop to the
  # arrival at the next row, which belongs to the same trip because the last
  # stop of each trip starts no segment

  starts_segment <- !is_last_stop
  durations <- data.table::data.table(
    trip_id = durations$trip_id[starts_segment],
    segment = data.table::rowid(durations$trip_id)[starts_segment],
    duration = (
      data.table::shift(durations$arrival_time_secs, -1L) -
        durations$departure_time_secs
    )[starts_segment]
  )

  # keep only the segments that depart from their first stop within the time
  # of day

  if (is_windowed) {
    in_window <- !is.na(segment_departure) &
      segment_departure >= window[1] &
      segment_departure <= window[2]
    durations <- durations[in_window]
  }

  # multiplying by the reciprocal keeps the results identical to those of
  # earlier versions, bit for bit; dividing by the factor differs in the last
  # bit for some durations. for "s" the column keeps its class (integer,
  # unless the feed has double _secs columns)

  if (unit != "s") {
    durations[, duration := duration * (1 / dwell_unit_factors[[unit]])]
  }

  return(durations[])
}
