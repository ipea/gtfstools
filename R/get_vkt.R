#' Get vehicle-kilometres travelled
#'
#' Returns the vehicle-kilometres travelled (VKT) by each specified `route_id`:
#' the length of each of its trips, counted once for every departure of the
#' trip on every day on which its service runs. VKT can be restricted to some
#' dates and to a time of day.
#'
#' @template gtfs
#' @param route_id A character vector including the `route_id`s to have their
#'   VKT calculated. If `NULL` (the default), the function calculates the VKT
#'   of every `route_id` in the GTFS. `route_id`s not listed in `trips` are
#'   ignored, with a warning.
#' @param date A `Date` vector (including `IDate`) or a character vector of
#'   dates in the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. If given, only these
#'   dates are counted. If `NULL` (the default), every day on which the
#'   services of the routes run is counted.
#' @param from,to Strings in the `"HH:MM:SS"` format. If given (both must be),
#'   only the departures at or after `from` and at or before `to` are
#'   counted. If `NULL` (the default), every departure is counted.
#'
#' @return A `data.table` with the columns `route_id`, `n_days` (the number of
#'   counted days on which at least one counted departure of the route runs),
#'   `vkt` (the vehicle-kilometres travelled on these days, in km) and
#'   `vkt_daily_mean` (`vkt` divided by
#'   `n_days`, in km per day), sorted by `route_id`. Routes without any
#'   departure on the counted days (and within the time of day) are not
#'   included.
#'
#' @section Details:
#' The VKT of a route is the sum, over its trips, of the length of each trip
#' times its number of departures times the number of counted days on which
#' its service runs, according to the `calendar` and `calendar_dates` tables.
#' Departures are counted as in [get_route_frequency()]: trips listed in the
#' `frequencies` table depart once per headway, the other trips depart once,
#' and departures after midnight belong to the previous service day (times
#' after midnight written as early morning times are fixed first, as in
#' [get_route_frequency()]). Unlike in
#' [get_route_frequency()], the time of day includes `to`, as in
#' [get_trip_length()]. An error is raised if the `frequencies` table has
#' invalid entries for trips that run on the counted days.
#'
#' Trip lengths are calculated with [get_trip_length()], along the shape of
#' each trip from its first to its last stop, so trips to and from the depot
#' are not included. If the GTFS has no `shapes` table, the straight-line
#' distances between stops are used instead, with a warning. Trips whose
#' length is unknown (e.g. trips without a usable shape, which also raise a
#' warning, or trips listed in `frequencies` but not in `stop_times`) add
#' nothing to the VKT, but the days on which they run still count in
#' `n_days`. If no counted trip of a route has a known length, its `vkt` is
#' `NA`.
#'
#' @seealso [get_vmt()] for vehicle-miles, [get_route_frequency()],
#'   [get_trip_length()], [get_summary()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # VKT of every route over every day of the feed's calendar
#' vkt <- get_vkt(gtfs)
#' head(vkt)
#'
#' # VKT of two routes in the morning peak of a single day
#' get_vkt(
#'   gtfs,
#'   route_id = c("CPTM L07", "2002-10"),
#'   date = "2019-03-04",
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#'
#' @export
get_vkt <- function(gtfs,
                    route_id = NULL,
                    date = NULL,
                    from = NULL,
                    to = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(route_id, null.ok = TRUE, any.missing = FALSE)

  checkmate::assert_string(from, pattern = time_pattern, null.ok = TRUE)
  checkmate::assert_string(to, pattern = time_pattern, null.ok = TRUE)
  if (!is.null(date)) {
    date <- parse_dates(date)
  }

  if (xor(is.null(from), is.null(to))) {
    cli::cli_abort(
      "{.arg from} and {.arg to} must be given together.",
      class = "gtfstools_invalid_time_of_day"
    )
  }
  window <- NULL
  if (!is.null(from)) {
    window <- time_of_day_window(from, to)
  }

  gtfsio::assert_field_class(
    gtfs,
    "trips",
    c("trip_id", "route_id", "service_id"),
    rep("character", 3)
  )

  # select the trips of the relevant routes and raise warning if a given
  # route_id doesn't exist in 'trips'. the vkt is calculated by route

  trips <- gtfs$trips[, .(trip_id, service_id, group = route_id)]

  if (!is.null(route_id)) {
    warn_invalid_ids(route_id, trips$group, "trips", "route_id")

    relevant_routes <- route_id
    trips <- trips[group %chin% relevant_routes]
  }

  vkt <- calculate_vkt(gtfs, trips, date, window)
  vkt <- vkt[n_days > 0]
  data.table::setnames(vkt, "group", "route_id")
  data.table::setorderv(vkt, "route_id")

  return(vkt[])
}



#' Calculate the vehicle-kilometres travelled by groups of trips
#'
#' @template gtfs
#' @param trips A `data.table` with the columns `trip_id`, `service_id` and
#'   `group` (the group of each trip, such as its route), in the order of the
#'   `trips` table.
#' @param date A `Date` vector with the days to be counted, or `NULL` to count
#'   every day on which the services of `trips` run.
#' @param window An integer vector with the start and end of the time of day,
#'   in seconds after midnight, as returned by `time_of_day_window()`, or
#'   `NULL` to count every departure.
#' @param lengths A `data.table` with the columns `trip_id` and `length` (in
#'   km, or in the unit in which the vkt is wanted), as returned by
#'   [get_trip_length()], or `NULL` to calculate the lengths of the counted
#'   trips (in km).
#'
#' @return A `data.table` with the columns `group`, `n_days`, `vkt` and
#'   `vkt_daily_mean`, as described in [get_vkt()], with one row for each
#'   group in `trips`, in their order. Groups without any counted departure
#'   have `n_days` 0 and `NA` vkt.
#'
#' @keywords internal
calculate_vkt <- function(gtfs, trips, date, window, lengths = NULL) {
  trips <- unique(trips)
  groups <- unique(trips$group)

  # the calendar is restricted to the services of the given trips before the
  # days of each service are listed, as listing every service of a feed on
  # every day can create millions of rows. these subsets use logical vectors,
  # which, unlike %chin% inside the brackets, don't add an index to the given
  # calendar tables. 'calendar_gtfs' is a shallow copy, so the given gtfs is
  # unchanged

  relevant_services <- unique(trips$service_id)
  calendar_gtfs <- gtfs
  for (table in intersect(c("calendar", "calendar_dates"), names(gtfs))) {
    is_relevant <- gtfs[[table]]$service_id %chin% relevant_services
    calendar_gtfs[[table]] <- gtfs[[table]][is_relevant]
  }

  # the counted days are the given dates, or every day on which one of the
  # services runs. a service listed twice in 'calendar' would be listed twice
  # on the same day, hence unique()

  if (is.null(date)) {
    days <- as.integer(get_service_period(calendar_gtfs))
  } else {
    days <- unique(as.integer(date))
  }

  service_days <- unique(get_services_on_days(calendar_gtfs, days))
  days_per_service <- service_days[, .(n = .N), by = service_id]

  # only the trips whose service runs on a counted day have their departures
  # counted, so that invalid 'frequencies' entries of the other trips raise no
  # error

  runs <- trips$service_id %chin% days_per_service$service_id
  departures <- get_trip_departures(gtfs, unique(trips$trip_id[runs]))

  if (!is.null(window)) {
    departures <- departures[
      departure_secs >= window[1] & departure_secs <= window[2]
    ]
  }

  departures_per_trip <- departures[, .(n = .N), by = trip_id]

  is_counted <- runs & trips$trip_id %chin% departures_per_trip$trip_id
  counted_trips <- trips[is_counted]

  # trips listed in 'frequencies' but not in 'stop_times' have no length, and
  # passing them to get_trip_length() would raise a warning

  if (is.null(lengths)) {
    length_trips <- unique(counted_trips$trip_id)
    length_trips <- length_trips[length_trips %chin% gtfs$stop_times$trip_id]
    lengths <- get_trip_length(gtfs, trip_id = length_trips, unit = "km")
  }

  # the vkt of each trip is summed by group in the order of 'trips', so that
  # a group sums the same values in the same order regardless of the other
  # groups

  trip_vkt <- lengths$length[match(counted_trips$trip_id, lengths$trip_id)] *
    departures_per_trip$n[
      match(counted_trips$trip_id, departures_per_trip$trip_id)
    ] *
    days_per_service$n[
      match(counted_trips$service_id, days_per_service$service_id)
    ]

  vkt_by_group <- data.table::data.table(
    group = counted_trips$group,
    vkt = trip_vkt
  )
  vkt_by_group <- vkt_by_group[, .(vkt = sum_or_na(vkt)), by = group]

  # the days of a group are those on which at least one of its services with
  # counted trips runs. groups that use the same set of services (e.g. routes
  # that share weekday and weekend services) run on the same days, so the days
  # are counted once for each set, identified by the sorted indices of its
  # services, rather than once for each group, which would list the days of
  # a shared service as many times as the groups that use it

  group_services <- unique(counted_trips[, .(group, service_id)])
  group_services[, sid := match(service_id, days_per_service$service_id)]
  data.table::setorderv(group_services, c("group", "sid"))
  group_services[, service_set := paste(sid, collapse = " "), by = group]

  set_services <- unique(group_services[, .(service_set, service_id)])
  days_by_set <- service_days[
    set_services,
    on = "service_id",
    nomatch = NULL,
    allow.cartesian = TRUE,
    .(service_set, day)
  ]
  days_by_set <- days_by_set[
    ,
    .(n_days = data.table::uniqueN(day)),
    by = service_set
  ]

  group_sets <- unique(group_services[, .(group, service_set)])
  group_set <- group_sets$service_set[match(groups, group_sets$group)]
  n_days <- days_by_set$n_days[match(group_set, days_by_set$service_set)]
  n_days[is.na(n_days)] <- 0L
  vkt <- vkt_by_group$vkt[match(groups, vkt_by_group$group)]
  vkt[n_days == 0L] <- NA_real_

  vkt <- data.table::data.table(
    group = groups,
    n_days = n_days,
    vkt = vkt,
    vkt_daily_mean = vkt / n_days
  )

  return(vkt)
}
