#' Set route frequency
#'
#' Sets the headway of each specified `route_id` within a given time of day, by
#' replacing its trips in that time of day with a single frequency-based trip,
#' described in the `frequencies` table.
#'
#' @template gtfs
#' @param route_id A character vector including the `route_id`s to have their
#'   frequency set.
#' @param headway A number. The headway to be set, in minutes. It is rounded
#'   to whole seconds and applies to every `route_id` (call the function once
#'   per route to set different headways).
#' @param from A string. The starting point of the time of day, in the
#'   "HH:MM:SS" format.
#' @param to A string. The ending point of the time of day, in the "HH:MM:SS"
#'   format. Must be later than `from`.
#'
#' @return A GTFS object with updated `frequencies`, `trips` and `stop_times`
#'   tables (and `transfers`, when present). If the given GTFS object has no
#'   `frequencies` table, one is created.
#'
#' @section Details:
#' The departures of the routes are grouped as in [get_route_frequency()]: by
#' `route_id`, `service_id` and `direction_id` (if present in `trips`). The
#' function changes existing service, it does not create it, so groups with no
#' departure within the time of day are not modified. In each of the other
#' groups:
#' - the trips that depart within the time of day are replaced by a single
#'   template trip: among the trips of the stop pattern (as identified by
#'   [get_stop_times_patterns()]) with the most departures within the time of
#'   day, the one that departs first. Its travel times apply to all the new
#'   departures. The trips of other patterns that depart within the time of
#'   day are removed (frequency-based ones lose their `frequencies` entries
#'   within the time of day, see below);
#' - a `frequencies` entry is added for the template, from `from` to `to`,
#'   with `headway_secs` set to `headway` and `exact_times = 0`
#'   (frequency-based service). A scheduled template thus becomes a
#'   frequency-based trip, and the `transfers` entries that refer to it now
#'   apply to all of its departures;
#' - the existing `frequencies` entries of the group's trips are clipped to the
#'   time of day, keeping the departures outside it exactly as before (when
#'   converted with [frequencies_to_stop_times()] with `strategy = "exact"`).
#'   Trips left without any departure are removed from `trips`, `stop_times`
#'   and `transfers`.
#'
#' As in [get_route_frequency()], a departure is within the time of day when
#' it happens at or after `from` and before `to`, so
#' `get_route_frequency()` reports the new headway (exactly, when the length
#' of the time of day is a multiple of `headway`). Departures after midnight
#' are listed with times greater than "24:00:00", so a time of day such as
#' "24:00:00"-"26:00:00" should be used for them. Scheduled trips that depart
#' before `from` are not changed, even if they run within the time of day.
#' Groups whose trips within the time of day have no departure time in
#' `stop_times` can't have a template, and are left unchanged with a warning.
#' Removed trips may leave unused entries in other tables, such as `shapes`
#' and `calendar`, which can be removed with [remove_unused_ids()].
#'
#' The `stop_times` table requires the `stop_id` and `stop_sequence` fields.
#' Existing `_secs` columns in `frequencies` (e.g. created with
#' [convert_time_to_seconds()]) are updated.
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' get_route_frequency(
#'   gtfs,
#'   route_id = "CPTM L07",
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#'
#' # sets a 10 minutes headway from 7 to 9 am
#' new_gtfs <- set_route_frequency(
#'   gtfs,
#'   route_id = "CPTM L07",
#'   headway = 10,
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#' get_route_frequency(
#'   new_gtfs,
#'   route_id = "CPTM L07",
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#'
#' # use frequencies_to_stop_times() to get the scheduled trips
#' new_gtfs <- frequencies_to_stop_times(new_gtfs)
#'
#' @export
set_route_frequency <- function(gtfs, route_id, headway, from, to) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(route_id, any.missing = FALSE)
  checkmate::assert_number(
    headway,
    lower = 1 / 60,
    upper = .Machine$integer.max / 60
  )
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

  headway_secs <- as.integer(round(headway * 60))

  # check if required fields and files exist ('stop_times' and 'frequencies'
  # are checked by get_trip_departures())

  gtfsio::assert_field_class(
    gtfs,
    "trips",
    c("trip_id", "route_id", "service_id"),
    rep("character", 3)
  )

  # select the trips of the relevant routes and raise warning if a given
  # route_id doesn't exist in 'trips'. the departures are grouped by route,
  # service and direction (if available), as in get_route_frequency()

  group_cols <- c("route_id", "service_id")
  if (gtfsio::check_field_exists(gtfs, "trips", "direction_id")) {
    group_cols <- c("route_id", "direction_id", "service_id")
  }

  invalid_route_id <- route_id[! route_id %chin% gtfs$trips$route_id]

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
  trips <- gtfs$trips[
    route_id %chin% relevant_routes,
    c("trip_id", group_cols),
    with = FALSE
  ]
  if (nrow(trips) == 0) return(gtfs)

  trips[, group := .GRP, by = group_cols]

  # find the departures within the time of day of each group

  departures <- get_trip_departures(gtfs, trips$trip_id)
  departures <- departures[
    departure_secs >= from_secs & departure_secs < to_secs
  ]
  departures[trips, on = "trip_id", group := i.group]

  # the template of each group is the trip that departs first among the trips
  # of its most frequent stop pattern. templates must have a departure time in
  # 'stop_times', otherwise they can't be converted by
  # frequencies_to_stop_times(). scheduled trips only depart if they do, so
  # only frequency-based trips have to be checked. only ids listed in
  # 'stop_times' are passed to get_stop_times_patterns(), so that it doesn't
  # raise a warning

  has_frequencies <- gtfsio::check_file_exists(gtfs, "frequencies")
  frequency_trips <- character(0)
  if (has_frequencies) frequency_trips <- unique(gtfs$frequencies$trip_id)

  in_window_trips <- unique(departures$trip_id)
  is_frequency_based <- in_window_trips %chin% frequency_trips

  template_stop_times <- gtfs$stop_times[
    trip_id %chin% in_window_trips[is_frequency_based],
    .(trip_id, departure_time)
  ]
  candidates <- c(
    in_window_trips[!is_frequency_based],
    unique(
      template_stop_times$trip_id[
        !is.na(string_to_seconds(template_stop_times$departure_time))
      ]
    )
  )

  if (length(candidates) > 0) {
    patterns <- get_stop_times_patterns(gtfs, trip_id = candidates)

    candidate_departures <- departures[trip_id %chin% candidates]
    candidate_departures[
      patterns,
      on = "trip_id",
      pattern_id := i.pattern_id
    ]

    pattern_count <- candidate_departures[
      ,
      .(n = .N),
      by = .(group, pattern_id)
    ]
    data.table::setorderv(
      pattern_count,
      c("group", "n", "pattern_id"),
      order = c(1L, -1L, 1L)
    )
    dominant_patterns <- pattern_count[!duplicated(group)]

    templates <- candidate_departures[
      dominant_patterns[, .(group, pattern_id)],
      on = c("group", "pattern_id")
    ]
    data.table::setorderv(templates, c("group", "departure_secs", "trip_id"))
    templates <- templates[!duplicated(group), .(group, trip_id)]
  } else {
    templates <- data.table::data.table(
      group = integer(0),
      trip_id = character(0)
    )
  }

  groups_without_template <- setdiff(departures$group, templates$group)

  if (length(groups_without_template) > 0) {
    routes_without_template <- unique(
      trips[group %in% groups_without_template]$route_id
    )

    cli::cli_warn(
      c(
        paste0(
          "The trips of {length(routes_without_template)} ",
          "route_id{?s} that depart within the time of day have no ",
          "departure time in {.file stop_times}: ",
          "{.val {routes_without_template}}."
        ),
        "i" = paste0(
          "{cli::qty(length(routes_without_template))}{?Its/Their} ",
          "frequency couldn't be set in some services or directions, which ",
          "were left unchanged."
        )
      ),
      class = "gtfstools_no_template"
    )
  }

  if (nrow(templates) == 0) return(gtfs)

  affected_trips <- trips[group %in% templates$group]$trip_id

  # clip the existing 'frequencies' entries of the affected trips to the time
  # of day. the entries that continue after the time of day restart at their
  # first departure at or after 'to', keeping their phase, so the departures
  # outside the time of day don't change. single-departure entries (whose
  # start_time and end_time are equal) within the time of day are dropped

  new_frequencies <- data.table::data.table(
    trip_id = templates$trip_id,
    start_time = from,
    end_time = to,
    headway_secs = headway_secs
  )

  if (has_frequencies) {
    is_affected <- gtfs$frequencies$trip_id %chin% affected_trips
    unaffected_frequencies <- gtfs$frequencies[!is_affected]
    to_clip <- gtfs$frequencies[is_affected]

    start <- string_to_seconds(to_clip$start_time)
    end <- string_to_seconds(to_clip$end_time)
    headways <- to_clip$headway_secs

    overlaps <- (start < to_secs & end > from_secs) |
      (start == end & start >= from_secs & start < to_secs)

    before <- to_clip[overlaps & start < from_secs]
    before[, end_time := from]

    next_departure <- start +
      (to_secs - start + headways - 1L) %/% headways * headways
    has_after <- overlaps & start != end & next_departure < end
    after <- to_clip[has_after]
    after[, start_time := seconds_to_string(next_departure[has_after])]

    if ("exact_times" %chin% names(gtfs$frequencies)) {
      new_frequencies[, exact_times := 0L]
    }

    clipped_frequencies <- rbind(
      to_clip[!overlaps],
      before,
      after,
      new_frequencies,
      fill = TRUE
    )
    clipped_frequencies <- clipped_frequencies[
      order(trip_id, string_to_seconds(start_time))
    ]

    frequencies <- rbind(
      unaffected_frequencies,
      clipped_frequencies,
      fill = TRUE
    )

    for (time_col in c("start_time", "end_time")) {
      secs_col <- paste0(time_col, "_secs")
      if (secs_col %chin% names(frequencies)) {
        data.table::set(
          frequencies,
          j = secs_col,
          value = string_to_seconds(frequencies[[time_col]])
        )
      }
    }
  } else {
    new_frequencies[, exact_times := 0L]
    frequencies <- new_frequencies
  }

  gtfs$frequencies <- frequencies

  # remove the trips that no longer depart: the scheduled trips that departed
  # within the time of day, and the frequency-based trips left without any
  # 'frequencies' entry (which would otherwise become scheduled trips)

  removable_trips <- affected_trips[! affected_trips %chin% templates$trip_id]
  is_scheduled_in_window <- removable_trips %chin% in_window_trips &
    ! removable_trips %chin% frequency_trips
  is_without_frequencies <- removable_trips %chin% frequency_trips &
    ! removable_trips %chin% frequencies$trip_id
  trips_to_remove <- removable_trips[
    is_scheduled_in_window | is_without_frequencies
  ]

  if (length(trips_to_remove) > 0) {
    `%ffilter%` <- Negate(`%chin%`)

    gtfs <- filter_trips_from_trip_id(gtfs, trips_to_remove, `%ffilter%`)
    gtfs <- filter_stop_times_from_trip_id(gtfs, trips_to_remove, `%ffilter%`)
    gtfs <- filter_transfers_from_trip_id(gtfs, trips_to_remove, `%ffilter%`)
  }

  return(gtfs)
}
