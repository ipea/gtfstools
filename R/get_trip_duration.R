#' Get trip duration
#'
#' Returns the duration of each specified `trip_id`.
#'
#' @template gtfs
#' @param trip_id A string vector including the `trip_id`s to have their
#'   duration calculated. If `NULL` (the default) the function calculates the
#'   duration of every `trip_id` in the GTFS.
#' @param unit A string representing the time unit in which the duration is
#'   desired. One of `"s"` (seconds), `"min"` (minutes, the default), `"h"`
#'   (hours) or `"d"` (days).
#' @param from A string, in the "HH:MM:SS" format. Only trips that depart from
#'   their first stop at or after `from` are included. If `NULL` (the
#'   default), there is no lower limit.
#' @param to A string, in the "HH:MM:SS" format. Only trips that depart from
#'   their first stop at or before `to` are included. If `NULL` (the default),
#'   there is no upper limit.
#'
#' @return A `data.table` containing the duration of each specified trip.
#'
#' @section Details:
#' The duration of a trip is defined as the time difference between its last
#' arrival time and its first departure time, as specified in the `stop_times`
#' table. Trips without any arrival time or without any departure time get a
#' `NA` duration, with a warning.
#'
#' Existing `_secs` columns in `stop_times` (e.g. created with
#' [convert_time_to_seconds()]) are used as-is, not recalculated from the time
#' strings.
#'
#' Times after midnight written as early morning times (e.g. `"00:30:00"`
#' instead of `"24:30:00"`) are fixed with [fix_overnight_times()] before the
#' durations are calculated, if `stop_sequence` is an integer column (without
#' it, the times can't be ordered and are used as written).
#'
#' `from` and `to` are compared with the departure time of the first stop of
#' each trip, in `stop_sequence` order (which must then be an integer column).
#' The time is read as the durations are: from `departure_time_secs`, if
#' present, or else from `departure_time`, so use times past `"24:00:00"` for
#' departures after midnight. For trips listed in `frequencies`, these are
#' template times, not the times of each departure. Trips whose first
#' departure is blank are never included when `from` or `to` is given.
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
#' trip_duration <- get_trip_duration(gtfs)
#' head(trip_duration)
#'
#' trip_ids <- c("CPTM L07-0", "2002-10-0")
#' trip_duration <- get_trip_duration(gtfs, trip_id = trip_ids)
#' trip_duration
#'
#' trip_duration <- get_trip_duration(gtfs, trip_id = trip_ids, unit = "h")
#' trip_duration
#'
#' @export
get_trip_duration <- function(gtfs,
                              trip_id = NULL,
                              unit = "min",
                              from = NULL,
                              to = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = names(dwell_unit_factors)),
    combine = "and"
  )
  window <- dwell_time_window(from, to)
  is_windowed <- any(is.finite(window))

  # check if required fields and files exist

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time"),
    rep("character", 3)
  )

  if (is_windowed) {
    gtfsio::assert_field_class(gtfs, "stop_times", "stop_sequence", "integer")
  }

  # times after midnight written as early morning times are fixed first, so
  # they don't go back. without an integer stop_sequence the times can't be
  # ordered, so they are used as written

  gtfs <- fix_overnight_in_call(gtfs, trip_id)

  # select trip_ids to get duration of and raise warning if a given trip_id
  # doesn't exist in 'stop_times'
  # also create object with filtered stop_times. an empty selection goes
  # through the calculations below, so that the duration has the same type as
  # in non-empty results

  if (!is.null(trip_id)) {
    relevant_trips <- trip_id

    warn_missing_ids(trip_id, gtfs$stop_times$trip_id, "stop_times", "trip_id")

    # the selection index is created outside of `[` so that {data.table}
    # doesn't add an index to the original table

    is_relevant <- gtfs$stop_times$trip_id %chin% relevant_trips

    if (all(is_relevant)) {
      durations <- gtfs$stop_times
    } else {
      durations <- gtfs$stop_times[is_relevant]
    }
  } else {
    durations <- gtfs$stop_times
  }

  # keep only the trips that depart from their first stop within the time of
  # day, read as the durations are (from the '_secs' column, if any)

  if (is_windowed) {
    if (gtfsio::check_field_exists(gtfs, "stop_times", "departure_time_secs")) {
      departure <- durations$departure_time_secs
    } else {
      departure <- durations$departure_time
    }

    kept_trips <- trips_departing_within(
      durations$trip_id,
      durations$stop_sequence,
      departure,
      window
    )
    durations <- durations[durations$trip_id %chin% kept_trips]
  }

  # the times in seconds are put into a new table (using the existing '_secs'
  # columns, if any), so that the given 'stop_times' is not modified. the
  # table is built from a list, which reuses the trip_id vector instead of
  # copying it (it's only grouped below, never modified)

  has_departure_secs <- gtfsio::check_field_exists(
    gtfs,
    "stop_times",
    "departure_time_secs"
  )
  has_arrival_secs <- gtfsio::check_field_exists(
    gtfs,
    "stop_times",
    "arrival_time_secs"
  )

  durations <- data.table::setDT(
    list(
      trip_id = durations$trip_id,
      departure_time_secs = if (has_departure_secs) {
        durations$departure_time_secs
      } else {
        string_to_seconds(durations$departure_time)
      },
      arrival_time_secs = if (has_arrival_secs) {
        durations$arrival_time_secs
      } else {
        string_to_seconds(durations$arrival_time)
      }
    )
  )

  # calculate durations. trips without any arrival or departure time get a NA
  # duration. they are set aside before aggregating the other trips, since
  # max() and min() would return -Inf or Inf for them (or even fail, as these
  # values don't fit the type of integer time columns). max() and min() are
  # kept as separate expressions so that {data.table} optimises them (GForce)

  trip_ids <- unique(durations$trip_id)
  timed_trips <- intersect(
    durations$trip_id[!is.na(durations$arrival_time_secs)],
    durations$trip_id[!is.na(durations$departure_time_secs)]
  )
  trips_without_times <- trip_ids[!trip_ids %chin% timed_trips]

  if (length(trips_without_times) > 0) {
    durations <- durations[durations$trip_id %chin% timed_trips]
  }

  # {data.table} evaluates j even without rows, so the aggregation is skipped
  # when no trip has times

  if (length(timed_trips) > 0) {
    durations <- durations[
      ,
      .(
        last_arrival = max(arrival_time_secs, na.rm = TRUE),
        first_departure = min(departure_time_secs, na.rm = TRUE)
      ),
      keyby = trip_id
    ]
    durations[, duration := last_arrival - first_departure]
    durations[, c("last_arrival", "first_departure") := NULL]
  } else {
    durations <- data.table::data.table(
      trip_id = character(0),
      duration = durations$arrival_time_secs[0]
    )
  }

  if (length(trips_without_times) > 0) {
    durations <- rbind(
      durations,
      data.table::data.table(trip_id = trips_without_times),
      fill = TRUE
    )
    data.table::setkeyv(durations, "trip_id")
    cli::cli_warn(
      paste0(
        "{length(trips_without_times)} trip{?s} {?has/have} no arrival time ",
        "or no departure time, so {?its duration is/their durations are} ",
        "{.val NA}: {.val {trips_without_times}}."
      ),
      class = "gtfstools_trips_without_times"
    )
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
