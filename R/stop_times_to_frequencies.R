#' Convert stop times to frequencies
#'
#' Converts scheduled trips, described only in `stop_times`, into
#' frequency-based trips, described in `frequencies`. Trips that follow the same
#' route and sequence of stops are summarised, in each hour of the day, by a
#' single template trip and the headway between their departures. This is a
#' lossy approximation of the original schedule.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to be converted.
#'   If `NULL` (the default), the function converts all trips listed in
#'   `stop_times` that are not already listed in `frequencies`.
#'
#' @return A GTFS object with updated `frequencies`, `stop_times` and `trips`
#'   tables (and `transfers`, when present). If the given GTFS object has no
#'   `frequencies` table, one is created.
#'
#' @section Details:
#' Trips are grouped together when they share the same `route_id`,
#' `service_id`, `direction_id` and `shape_id` (these last two only when
#' present in `trips`) and the same sequence of stops (their spatial pattern,
#' as identified by [get_stop_times_patterns()]). Each group is then split into
#' one-hour slots of the clock, from `HH:00:00` (included) to the next
#' `HH:00:00` (not included), according to the first departure time of each
#' trip. Slots after midnight are kept as such (e.g. from `"25:00:00"` to
#' `"26:00:00"`).
#'
#' In each slot with `n` trips:
#' - the trip that departs first (ties broken by `trip_id`) becomes the
#'   template. It keeps its `trip_id`, its `trips` entry and its `stop_times`
#'   entries, so travel times may differ from one hour to another. As in any
#'   frequency-based trip, only its times relative to its first departure
#'   matter;
#' - a `frequencies` entry is added for the template, from the start to the
#'   end of the slot, with `headway_secs = ceiling(3600 / n)` and
#'   `exact_times = 0` (frequency-based service);
#' - the other trips are removed from `trips`, `stop_times` and `transfers`.
#'   Their own departure times, travel times and other `trips` fields (e.g.
#'   `trip_headsign`, `block_id`) are lost. `transfers` entries that refer to
#'   the template now apply to all of its departures. Other tables that may
#'   refer to trips, such as `attributions` and `translations`, are not
#'   changed.
#'
#' Slots with a single trip are also converted (with a headway of one hour), so
#' that every converted trip becomes frequency-based. Only the trips in
#' `trip_id` are grouped and converted: other trips are never removed, even if
#' they share a group and a slot with converted ones. Trips already listed in
#' `frequencies` (with a warning, if listed in `trip_id`), trips not listed in
#' `trips` and trips without any `departure_time` are left unchanged.
#'
#' This conversion is useful for tools that treat frequency-based trips
#' differently from scheduled ones, such as the `time_window` parameter of
#' `{r5r}`, which draws departure times within the headways of frequency-based
#' trips.
#'
#' Converting the result back with [frequencies_to_stop_times()] yields the
#' same number of trips in each slot, as long as it has at most 60 trips (one
#' departure per minute). Slots with more trips yield approximately the same
#' number of trips. The departures of the new trips, however, are evenly
#' spaced from the start of the slot.
#'
#' Existing `_secs` columns in `stop_times` and `frequencies` (e.g. created
#' with [convert_time_to_seconds()]) are used as-is, not recalculated from the
#' time strings, and are filled in for the new `frequencies` entries.
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # converts all trips
#' converted_gtfs <- stop_times_to_frequencies(gtfs)
#' nrow(gtfs$trips)
#' nrow(converted_gtfs$trips)
#' head(converted_gtfs$frequencies)
#'
#' # converts only the trips of one route
#' route_trips <- gtfs$trips[route_id == gtfs$trips$route_id[1]]$trip_id
#' converted_gtfs <- stop_times_to_frequencies(gtfs, route_trips)
#'
#' # converting back yields evenly spaced scheduled trips
#' back_gtfs <- frequencies_to_stop_times(converted_gtfs)
#'
#' @export
stop_times_to_frequencies <- function(gtfs, trip_id = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  gtfsio::assert_field_class(
    gtfs,
    "trips",
    c("trip_id", "route_id", "service_id"),
    rep("character", 3)
  )
  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "departure_time"),
    rep("character", 2)
  )

  # select the trips to be converted: those listed in 'stop_times' and 'trips'
  # and not already listed in 'frequencies'

  if (!is.null(trip_id)) {
    relevant_trips <- unique(trip_id)

    invalid_trip_id <- warn_missing_ids(
      relevant_trips,
      gtfs$stop_times$trip_id,
      "stop_times",
      "trip_id"
    )
    relevant_trips <- setdiff(relevant_trips, invalid_trip_id)
  } else {
    relevant_trips <- unique(gtfs$stop_times$trip_id)
  }

  if (gtfsio::check_field_exists(gtfs, "frequencies", "trip_id")) {
    freq_based <- relevant_trips %chin% gtfs$frequencies$trip_id

    if (!is.null(trip_id) && any(freq_based)) {
      freq_based_trips <- relevant_trips[freq_based]
      n_freq_based <- length(freq_based_trips)

      cli::cli_warn(
        c(
          paste0(
            "{n_freq_based} trip_id{?s} {?is/are} already frequency-based: ",
            "{.val {freq_based_trips}}."
          ),
          "i" = paste0(
            "{cli::qty(n_freq_based)}{?It is/They are} listed in ",
            "{.file frequencies} and left unchanged."
          )
        ),
        class = "gtfstools_frequency_based_trips"
      )
    }

    relevant_trips <- relevant_trips[!freq_based]
  }

  relevant_trips <- relevant_trips[relevant_trips %chin% gtfs$trips$trip_id]

  # first step: find the first departure of each trip. the computations are
  # done on a subset of 'stop_times', so the given gtfs is not modified. trips
  # without any departure are not listed in 'trips_info', and therefore are not
  # converted

  needed_cols <- intersect(
    c("trip_id", "departure_time", "departure_time_secs"),
    names(gtfs$stop_times)
  )
  stop_times <- gtfs$stop_times[
    trip_id %chin% relevant_trips,
    ..needed_cols
  ]

  if ("departure_time_secs" %chin% names(stop_times)) {
    departure_secs <- as.integer(stop_times$departure_time_secs)
  } else {
    departure_secs <- string_to_seconds(stop_times$departure_time)
  }

  has_departure <- !is.na(departure_secs)
  if (!any(has_departure)) return(gtfs)

  trips_info <- data.table::data.table(
    trip_id = stop_times$trip_id[has_departure],
    departure_secs = departure_secs[has_departure]
  )
  trips_info <- trips_info[
    ,
    .(first_departure = min(departure_secs)),
    by = trip_id
  ]

  # second step: group the trips by route, service, direction and shape (the
  # last two only if present in 'trips'), by their sequence of stops and by the
  # hour of their first departure

  trips_idx <- data.table::chmatch(trips_info$trip_id, gtfs$trips$trip_id)
  group_cols <- intersect(
    c("route_id", "service_id", "direction_id", "shape_id"),
    names(gtfs$trips)
  )

  for (col in group_cols) {
    data.table::set(trips_info, j = col, value = gtfs$trips[[col]][trips_idx])
  }

  patterns <- get_stop_times_patterns(gtfs, trip_id = trips_info$trip_id)
  trips_info[
    ,
    pattern_id := patterns$pattern_id[
      data.table::chmatch(trip_id, patterns$trip_id)
    ]
  ]
  trips_info[, slot := first_departure %/% 3600L]

  group_cols <- c(group_cols, "pattern_id", "slot")

  # third step: the first trip of each group (ties broken by trip_id) becomes
  # the template of the frequencies entry that describes the group. the
  # headway is rounded up so that frequencies_to_stop_times(), which doesn't
  # create departures at end_time, recreates the same number of trips (as long
  # as there are at most 60 of them)

  data.table::setorderv(
    trips_info,
    c(group_cols, "first_departure", "trip_id")
  )
  trips_info[, n_trips := .N, by = group_cols]
  is_template <- data.table::rowidv(trips_info, cols = group_cols) == 1L

  templates <- trips_info[is_template]

  frequencies_to_add <- data.table::data.table(
    trip_id = templates$trip_id,
    start_time = seconds_to_string(templates$slot * 3600L),
    end_time = seconds_to_string((templates$slot + 1L) * 3600L),
    headway_secs = as.integer(ceiling(3600 / templates$n_trips)),
    exact_times = 0L
  )

  if (!is.null(gtfs$frequencies)) {
    if ("start_time_secs" %chin% names(gtfs$frequencies)) {
      frequencies_to_add[, start_time_secs := templates$slot * 3600L]
    }
    if ("end_time_secs" %chin% names(gtfs$frequencies)) {
      frequencies_to_add[, end_time_secs := (templates$slot + 1L) * 3600L]
    }

    gtfs$frequencies <- rbind(
      gtfs$frequencies,
      frequencies_to_add,
      fill = TRUE
    )
  } else {
    gtfs$frequencies <- frequencies_to_add
  }

  # fourth step: remove the trips that are not templates, which are now
  # described by the frequencies entries of their templates

  trips_to_remove <- trips_info$trip_id[!is_template]
  `%ffilter%` <- Negate(`%chin%`)

  gtfs <- filter_trips_from_trip_id(gtfs, trips_to_remove, `%ffilter%`)
  gtfs <- filter_stop_times_from_trip_id(gtfs, trips_to_remove, `%ffilter%`)
  gtfs <- filter_transfers_from_trip_id(gtfs, trips_to_remove, `%ffilter%`)

  return(gtfs)
}
