#' Get stop frequency
#'
#' Returns the number of departures and the mean headway at each specified
#' `stop_id` within a given time of day, by `service_id`. Optionally, the
#' departures can also be counted by `route_id` (and by `direction_id`, if the
#' field is present in the `trips` table).
#'
#' @template gtfs
#' @param stop_id A character vector including the `stop_id`s to have their
#'   frequencies calculated. If `NULL` (the default), the function calculates
#'   the frequency of every `stop_id` in the GTFS.
#' @param by_route A logical. Whether the departures should be counted by
#'   `route_id` (and by `direction_id`, if present in the `trips` table) at
#'   each stop. Defaults to `FALSE`, in which case the departures of every route
#'   that serves a stop are pooled together.
#' @param from A string. The starting point of the time of day, in the
#'   "HH:MM:SS" format.
#' @param to A string. The ending point of the time of day, in the "HH:MM:SS"
#'   format. Must be later than `from`.
#'
#' @return A `data.table` with the columns `stop_id`, `route_id` and
#'   `direction_id` (only if `by_route` is `TRUE`, the latter only if present
#'   in the `trips` table), `service_id`, `departures` (the number of
#'   departures from the stop within the time of day, including each departure
#'   generated from the `frequencies` table) and `mean_headway` (the mean
#'   headway within the time of day, in minutes). Stops with no departures
#'   within the time of day are not included.
#'
#' @section Details:
#' The function counts stop departures: each `stop_times` entry with a
#' departure time is a departure from its stop, except for the entry of the
#' last stop of each trip (the one with the highest `stop_sequence`), from which
#' vehicles don't depart. Entries with blank departure times (such as those of
#' stops that are not timepoints) are not counted, so their times should be
#' interpolated beforehand to count them. A stop visited twice by the same trip
#' is counted twice. Its results are therefore not comparable to those of
#' [get_route_frequency()], which counts trips.
#'
#' The `stop_times` entries of trips listed in the `frequencies` table are just
#' templates: these trips depart every `headway_secs` from `start_time` until
#' (but not including) `end_time`, and each of these departures visits the
#' template's stops with the times shifted accordingly, as in
#' [frequencies_to_stop_times()]. Trips without any departure time in
#' `stop_times` don't generate departures. An error is raised if the
#' `frequencies` table has invalid entries for the trips that serve the
#' specified stops, even if they don't have any departure time.
#'
#' The stops are those listed in `stop_times`, which are never stations. Use
#' [get_children_stops()] to get the stops of a station and sum their
#' departures.
#'
#' A departure is counted when it happens at or after `from` and before `to`, so
#' that consecutive time windows (e.g. "06:00:00"-"07:00:00" and
#' "07:00:00"-"08:00:00") don't count the same departure twice. Please note
#' that this differs from [filter_by_time_of_day()], which keeps entries whose
#' times are equal to `to`. Departures after midnight are listed with times
#' greater than "24:00:00" and belong to the previous service day, so a time
#' of day such as "24:00:00"-"26:00:00" should be used to account for them.
#'
#' The mean headway is the length of the time of day divided by the number of
#' departures. It is an average over the whole time of day, so it is larger
#' than the actual headway when service starts or ends within it. Trips with an
#' `NA` `direction_id` are grouped together.
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
#' stop_frequency <- get_stop_frequency(
#'   gtfs,
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#' head(stop_frequency)
#'
#' stop_ids <- c("18848", "18960")
#' stop_frequency <- get_stop_frequency(
#'   gtfs,
#'   stop_id = stop_ids,
#'   by_route = TRUE,
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#' stop_frequency
#'
#' @export
get_stop_frequency <- function(gtfs,
                               stop_id = NULL,
                               by_route = FALSE,
                               from,
                               to) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(stop_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_logical(by_route, any.missing = FALSE, len = 1)
  checkmate::assert_string(from, pattern = "^\\d{2}:[0-5]\\d:[0-5]\\d$")
  checkmate::assert_string(to, pattern = "^\\d{2}:[0-5]\\d:[0-5]\\d$")

  from_secs <- string_to_seconds(from)
  to_secs <- string_to_seconds(to)

  if (from_secs >= to_secs) {
    cli::cli_abort(
      paste0(
        "{.arg from} ({.val {from}}) must be earlier than {.arg to} ",
        "({.val {to}})."
      ),
      class = "gtfstools_invalid_time_of_day"
    )
  }

  # check if required fields and files exist ('frequencies' is checked by
  # get_trip_departures()). the departures are counted by stop and service,
  # and also by route and direction (if available) when by_route = TRUE

  group_cols <- c("stop_id", "service_id")
  if (by_route) {
    group_cols <- c("stop_id", "route_id", "service_id")
    if (gtfsio::check_field_exists(gtfs, "trips", "direction_id")) {
      group_cols <- c("stop_id", "route_id", "direction_id", "service_id")
    }
  }

  trips_cols <- setdiff(c("trip_id", group_cols), "stop_id")
  required_trips_cols <- setdiff(trips_cols, "direction_id")
  gtfsio::assert_field_class(
    gtfs,
    "trips",
    required_trips_cols,
    rep("character", length(required_trips_cols))
  )

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "stop_id", "stop_sequence", "departure_time"),
    c("character", "character", "integer", "character")
  )

  # select the trips that serve the relevant stops and raise warning if a given
  # stop_id doesn't exist in 'stop_times'

  if (!is.null(stop_id)) {
    invalid_stop_id <- stop_id[! stop_id %chin% gtfs$stop_times$stop_id]

    if (!identical(invalid_stop_id, character(0))) {
      cli::cli_warn(
        paste0(
          "{.file stop_times} doesn't contain the following stop_id{?s}: ",
          "{.val {invalid_stop_id}}."
        ),
        class = "gtfstools_invalid_stop_id"
      )
    }

    relevant_stops <- stop_id
    relevant_trips <- gtfs$stop_times$trip_id[
      gtfs$stop_times$stop_id %chin% relevant_stops
    ]
    relevant_trips <- unique(relevant_trips)

    stop_times <- gtfs$stop_times[
      trip_id %chin% relevant_trips,
      .(
        trip_id,
        stop_id,
        stop_sequence,
        departure_secs = string_to_seconds(departure_time)
      )
    ]
  } else {
    stop_times <- gtfs$stop_times[
      ,
      .(
        trip_id,
        stop_id,
        stop_sequence,
        departure_secs = string_to_seconds(departure_time)
      )
    ]
  }

  # each stop_times entry with a departure time is a departure from its stop,
  # except for the last stop of the trip, identified considering all its
  # entries (not only those of the relevant stops). max() and min() raise
  # warnings when evaluated on empty tables, even when grouping, hence the
  # nrow() checks below

  last_stops <- stop_times[
    !is.na(stop_sequence),
    .(trip_id, last_seq = stop_sequence)
  ]
  if (nrow(last_stops) > 0) {
    last_stops <- last_stops[, .(last_seq = max(last_seq)), by = trip_id]
  }

  stop_departures <- stop_times[!is.na(departure_secs)]
  if (!is.null(stop_id)) {
    stop_departures <- stop_departures[stop_id %chin% relevant_stops]
  }

  stop_departures[last_stops, on = "trip_id", last_seq := i.last_seq]
  stop_departures <- stop_departures[
    is.na(stop_sequence) | stop_sequence != last_seq
  ]

  # the entries of trips listed in 'frequencies' are just templates: each
  # departure generated by 'frequencies' visits the template's stops with their
  # times shifted from the template's first departure. the other entries are
  # used as they are

  frequency_trips <- character(0)
  if (gtfsio::check_file_exists(gtfs, "frequencies")) {
    frequency_trips <- unique(
      stop_times$trip_id[stop_times$trip_id %chin% gtfs$frequencies$trip_id]
    )
  }

  first_departures <- stop_times[
    trip_id %chin% frequency_trips & !is.na(departure_secs),
    .(trip_id, first_secs = departure_secs)
  ]
  if (nrow(first_departures) > 0) {
    first_departures <- first_departures[
      ,
      .(first_secs = min(first_secs)),
      by = trip_id
    ]
  }

  is_frequency_trip <- stop_departures$trip_id %chin% frequency_trips

  frequency_departures <- stop_departures[
    is_frequency_trip,
    .(trip_id, stop_id, departure_secs)
  ]
  frequency_departures[
    first_departures,
    on = "trip_id",
    secs_offset := departure_secs - i.first_secs
  ]
  frequency_departures <- get_trip_departures(gtfs, frequency_trips)[
    frequency_departures[, .(trip_id, stop_id, secs_offset)],
    on = "trip_id",
    nomatch = NULL,
    allow.cartesian = TRUE
  ]
  frequency_departures[, departure_secs := departure_secs + secs_offset]

  # count the departures within the time of day by group and calculate the mean
  # headway (in minutes). the departures are filtered before being bound
  # together, so that those outside the time of day are not copied

  departures <- rbind(
    stop_departures[
      !is_frequency_trip &
        departure_secs >= from_secs &
        departure_secs < to_secs,
      .(trip_id, stop_id, departure_secs)
    ],
    frequency_departures[
      departure_secs >= from_secs & departure_secs < to_secs,
      .(trip_id, stop_id, departure_secs)
    ]
  )

  trips <- gtfs$trips[, trips_cols, with = FALSE]
  frequencies <- trips[departures, on = "trip_id", nomatch = NULL]
  frequencies <- frequencies[
    ,
    .(departures = .N),
    keyby = group_cols
  ]
  frequencies[, mean_headway := (to_secs - from_secs) / departures / 60]

  return(frequencies[])
}
