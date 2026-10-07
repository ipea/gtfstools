#' Get route frequency
#'
#' Returns the number of departures and the mean headway of each specified
#' `route_id` within a given time of day, by `service_id` (and by
#' `direction_id`, if the field is present in the `trips` table).
#'
#' @template gtfs
#' @param route_id A character vector including the `route_id`s to have their
#'   frequencies calculated. If `NULL` (the default), the function calculates
#'   the frequency of every `route_id` in the GTFS.
#' @param from A string. The starting point of the time of day, in the
#'   "HH:MM:SS" format.
#' @param to A string. The ending point of the time of day, in the "HH:MM:SS"
#'   format. Must be later than `from`.
#'
#' @return A `data.table` with the columns `route_id`, `direction_id` (only if
#'   present in the `trips` table), `service_id`, `departures` (the number of
#'   departures within the time of day, including each departure generated
#'   from the `frequencies` table) and `mean_headway` (the mean
#'   headway within the time of day, in minutes). Routes with no departures
#'   within the time of day are not included.
#'
#' @section Details:
#' The function counts trips, not stop visits: each trip is counted once, at
#' its departure time, however many stops it visits within the time of day.
#' Its results are therefore not comparable to those of functions that count
#' the departures from each stop of a route, such as
#' `tidytransit::get_route_frequency()`.
#'
#' The departure time of a trip is the earliest departure time listed for it in
#' `stop_times` (blank times are ignored). Trips listed in the `frequencies`
#' table depart every `headway_secs` from `start_time` until (but not
#' including) `end_time`, as in [frequencies_to_stop_times()], so their
#' `stop_times` entries, which are just templates, are not used (and these
#' trips are counted even if they are not listed in `stop_times`). Trips not
#' listed in `frequencies` use their `stop_times` departure times, and trips
#' without any departure time are ignored. An error is raised if the
#' `frequencies` table has invalid entries for the specified routes.
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
#' than the actual headway when service starts or ends within it. When the
#' `trips` table does not have a `direction_id` field, the departures of both
#' directions are pooled together. Trips with an `NA` `direction_id` are
#' grouped together.
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
#' route_frequency <- get_route_frequency(
#'   gtfs,
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#' head(route_frequency)
#'
#' route_ids <- c("CPTM L07", "2002-10")
#' route_frequency <- get_route_frequency(
#'   gtfs,
#'   route_id = route_ids,
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#' route_frequency
#'
#' @export
get_route_frequency <- function(gtfs, route_id = NULL, from, to) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(route_id, null.ok = TRUE, any.missing = FALSE)
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

  # check if required fields and files exist ('stop_times' and 'frequencies'
  # are checked by get_trip_departures())

  gtfsio::assert_field_class(
    gtfs,
    "trips",
    c("trip_id", "route_id", "service_id"),
    rep("character", 3)
  )

  # select the trips of the relevant routes and raise warning if a given
  # route_id doesn't exist in 'trips'. the departures are counted by route,
  # service and direction (if available)

  group_cols <- c("route_id", "service_id")
  if (gtfsio::check_field_exists(gtfs, "trips", "direction_id")) {
    group_cols <- c("route_id", "direction_id", "service_id")
  }

  trips <- gtfs$trips[, c("trip_id", group_cols), with = FALSE]

  if (!is.null(route_id)) {
    invalid_route_id <- route_id[! route_id %chin% trips$route_id]

    if (!identical(invalid_route_id, character(0))) {
      cli::cli_warn(
        paste0(
          "{.file trips} doesn't contain the following route_id{?s}: ",
          "{.val {invalid_route_id}}."
        ),
        class = "gtfstools_invalid_route_id"
      )
    }

    relevant_routes <- route_id
    trips <- trips[route_id %chin% relevant_routes]
  }

  departures <- get_trip_departures(gtfs, trips$trip_id)

  # count the departures within the time of day by group and calculate the mean
  # headway (in minutes)

  departures <- departures[
    departure_secs >= from_secs & departure_secs < to_secs
  ]

  frequencies <- trips[departures, on = "trip_id", nomatch = NULL]
  frequencies <- frequencies[
    ,
    .(departures = .N),
    keyby = group_cols
  ]
  frequencies[, mean_headway := (to_secs - from_secs) / departures / 60]

  return(frequencies[])
}



#' Get the departure times of trips
#'
#' Returns the departure times of the specified trips, in seconds after
#' midnight. Trips listed in the `frequencies` table depart several times, as
#' generated by [get_frequencies_departures()] from the `frequencies` table.
#' Other trips depart once, at the earliest departure time listed for them in
#' `stop_times`. Trips without any departure time are not included.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#'   departures returned.
#'
#' @return A `data.table` with the columns `trip_id` and `departure_secs`.
#'
#' @keywords internal
get_trip_departures <- function(gtfs, trip_id) {
  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "departure_time"),
    rep("character", 2)
  )

  relevant_trips <- trip_id

  # the departures of trips listed in 'frequencies' come from the
  # 'frequencies' table, while their 'stop_times' entries are just templates

  frequency_trips <- character(0)
  frequency_departures <- data.table::data.table(
    trip_id = character(0),
    departure_secs = integer(0)
  )

  if (gtfsio::check_file_exists(gtfs, "frequencies")) {
    gtfsio::assert_field_class(
      gtfs,
      "frequencies",
      c("trip_id", "start_time", "end_time", "headway_secs"),
      c("character", "character", "character", "integer")
    )

    freqs <- gtfs$frequencies[
      trip_id %chin% relevant_trips,
      .(trip_id, start_time, end_time, headway_secs)
    ]
    freqs[
      ,
      `:=`(
        start_time_secs = string_to_seconds(start_time),
        end_time_secs = string_to_seconds(end_time)
      )
    ]

    frequency_trips <- unique(gtfs$frequencies$trip_id)
    frequency_departures <- get_frequencies_departures(freqs)
  }

  # the other trips depart once, at their earliest departure time

  scheduled_trips <- relevant_trips[! relevant_trips %chin% frequency_trips]
  scheduled_departures <- gtfs$stop_times[
    trip_id %chin% scheduled_trips,
    .(trip_id, departure_secs = string_to_seconds(departure_time))
  ]
  scheduled_departures <- scheduled_departures[
    ,
    .(
      departure_secs = if (all(is.na(departure_secs))) {
        NA_integer_
      } else {
        min(departure_secs, na.rm = TRUE)
      }
    ),
    by = trip_id
  ]
  scheduled_departures <- scheduled_departures[!is.na(departure_secs)]

  departures <- rbind(frequency_departures, scheduled_departures)

  return(departures)
}
