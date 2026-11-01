#' Get a summary of a GTFS feed
#'
#' Runs a set of diagnostics on a GTFS feed (optionally restricted to some
#' dates, routes, modes, agencies and a time of day), writes them to a report
#' with tables and figures, renders the report to HTML and opens it in the
#' browser (in interactive sessions). The diagnostics are also returned as a
#' list of `data.table`s. This function does not validate or look for quality
#' issues in the GTFS feed. To do that, use [gtfstools::validate_gtfs()].
#'
#' @param gtfs A GTFS object, as created by [read_gtfs()], or the path to a
#'   GTFS file.
#' @param date A `Date` vector (including `IDate`) or a character vector of
#'   dates in the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. If given, only the
#'   services that run on these dates are described. If `NULL` (the default),
#'   the whole period covered by the feed is described.
#' @param route_id A character vector. If given, only these routes are
#'   described. If `NULL` (the default), all routes are described.
#' @param route_type An integer vector of `route_type`s (see
#'   [filter_by_route_type()]) or, unlike in other functions, a character
#'   vector of mode names (`"tram"`, `"subway"`, `"rail"`, `"bus"`, `"ferry"`,
#'   `"cable_tram"`, `"aerial_lift"`, `"funicular"`, `"trolleybus"` and
#'   `"monorail"`, which correspond to the basic `route_type`s). If given, only
#'   routes of these modes are described. If `NULL` (the default), all modes
#'   are described.
#' @param agency_id A character vector of `agency_id`s. If given, only the
#'   services of these agencies are described. If `NULL` (the default), all
#'   agencies are described.
#' @param from,to Strings in the `"HH:MM:SS"` format. If given (both must be),
#'   only the trips that run within this time of day are described. If `NULL`
#'   (the default), the whole day is described.
#' @param output_path A string. The directory in which the report is saved
#'   (created if needed). If `NULL` (the default), a `gtfstools` directory
#'   inside [tempdir()] is used. Existing reports in this directory are
#'   overwritten.
#' @param html_preview A logical. Whether to open the HTML report in the
#'   browser, in interactive sessions (defaults to `TRUE`).
#' @param by_route_type A logical. Whether to break down the totals, speeds,
#'   distances and frequencies by transport mode (`route_type`), in addition
#'   to the whole selection (defaults to `FALSE`).
#' @param unit A string. Either `"km/h"` (the default), to report distances in
#'   km and speeds in km/h, or `"mph"`, to report them in miles and miles per
#'   hour.
#'
#' @return A named list of `data.table`s (invisibly, if the report was opened
#'   in the browser):
#'   - `files`: the tables in the feed (`file`) and their number of rows
#'     (`n_rows`), before any filtering;
#'   - `agency`: the `agency_id`, `agency_name`, `agency_timezone`,
#'     `agency_url` and `agency_lang` columns (those present in the feed) of
#'     the agencies that run the selected trips (all agencies, if the
#'     selected routes have no `agency_id`);
#'   - `services`: a single row summarising the calendar of the selected
#'     services, with the columns `start_date` and `end_date` (the first and
#'     last days with service), `n_days` (the number of days between them,
#'     both included), `n_service_days` (the number of days with service),
#'     `n_services` (the number of `service_id`s), `mean_trips_per_day` (over
#'     the days with service), `busiest_date` and `max_trips_per_day` (the day
#'     with the most trips and its number of trips) and `feed_start_date` and
#'     `feed_end_date` (from `feed_info`, `NA` if absent);
#'   - `totals`: the columns `indicator`, `value` and `unit`, with the number
#'     of agencies, routes, trips and stops, the total and mean length of the
#'     shapes and of the trips (in km), the vehicle-kilometres travelled
#'     (`vkt_total`, in km) and their mean per day (`vkt_daily_mean`, in
#'     km/day), the total duration of the trips (in hours), the mean duration
#'     of the trips (in minutes), the mean trip speed (in km/h) and the mean
#'     route headway (in minutes). The means of lengths, durations and speeds
#'     are taken over the shapes and trips whose value is known, and
#'     `vkt_daily_mean` over the days with counted departures (see Details). If
#'     `by_route_type = TRUE`, `value` is replaced by one column per mode
#'     followed by the column `all` (codes of extended `route_type`s, such as
#'     `"700"`, are non-syntactic names, so they need backticks);
#'   - `speed`, `distance` and `frequency`: summary statistics (`n`, `min`,
#'     `q25`, `median`, `mean`, `q75`, `max` and `unit`) of the trip speeds
#'     (in km/h), of the trip lengths (in km) and of the route headways (in
#'     minutes). `frequency` also has the columns `date`, `from` and `to`, with
#'     the day and the time of day in which the headways were measured. If
#'     `by_route_type = TRUE`, these tables start with a `mode` column and
#'     have one row per mode followed by the row `all`.
#'
#'   With `unit = "mph"`, distances are in miles (`mi` and `mi/day`) and speeds
#'   in miles per hour (`mph`), and the rows `vkt_total` and `vkt_daily_mean`
#'   of `totals` are named `vmt_total` and `vmt_daily_mean` (vehicle-miles
#'   travelled).
#'
#'   The report is saved as `gtfs_summary.md` and `gtfs_summary.html`
#'   (together with its figures) in `output_path`.
#'
#' @section Details:
#' The report requires the `{ggplot2}`, `{knitr}` and `{rmarkdown}` packages
#' and [Pandoc](https://pandoc.org/).
#'
#' Times after midnight written as early morning times (e.g. `"00:30:00"`
#' instead of `"24:30:00"`), and `end_time`s earlier than `start_time`s in
#' `frequencies`, are first fixed with [fix_overnight_times()], if
#' `stop_sequence` is an integer column.
#'
#' The time-of-day filter keeps whole trips (as [filter_by_time_of_day()] with
#' `full_trips = TRUE`), so trip speeds and lengths refer to whole trips.
#'
#' Trip lengths, durations and speeds are calculated with [get_trip_length()],
#' [get_trip_duration()] and [get_trip_speed()], counting each trip once,
#' however many days it runs on or departures `frequencies` lists for it.
#' Trips with a zero or negative duration count in the durations but have no
#' speed. Shape lengths count each shape used by the selected trips once, and
#' the number of stops counts the stops visited by the selected trips.
#'
#' The VKT are calculated as in [get_vkt()] (or [get_vmt()], with
#' `unit = "mph"`): the length of each selected trip counts once per departure
#' on every counted day on which its service runs. The counted days are the
#' given `date`s or, if `date` is `NULL`, every day on which the selected
#' services run; `vkt_daily_mean` is the mean over the counted days on which
#' at least one counted departure runs. With `from` and `to`, only the
#' departures at or after `from` and at or before `to` are counted, as listed
#' before the feed is filtered by time of day, so selected trips that depart
#' before `from` add nothing. `vkt_total` and `vkt_daily_mean` are `NA` if no
#' selected trip departs on the counted days (within the time of day, if
#' given). An error is raised if `frequencies` has invalid entries for
#' selected trips that run on the counted days.
#'
#' `services` and the calendar chart describe the whole calendar of the
#' selected services: with `date`, the services running on these dates are
#' kept whole (as in [filter_by_date()]), so they may cover other days too.
#' The trips per day are counted as in [get_calendar_overlap()].
#'
#' Route headways are calculated with [get_route_frequency()], by route (and
#' `direction_id`, if present in `trips`), on a single day: the one with the
#' most trips among the given `date`s or in the whole feed (the earliest, on
#' ties). They are measured within the given time of day (excluding `to`, as
#' in [get_route_frequency()], unlike the other indicators) or, without `from`
#' and `to`, from the first to the last departure of that day, rounded out to
#' whole hours. Trips of the previous service day running after midnight are
#' not counted. With `from` and `to`, headways and trips per day are counted on
#' the time-filtered feed, whose `frequencies` entries crossing `from` start
#' at `from` (unless `exact_times` is 1), so they may differ from
#' [get_route_frequency()] and [get_calendar_overlap()] on the full feed.
#'
#' With `by_route_type = TRUE`, modes are named as in the `route_type`
#' argument, extended `route_type`s by their code and trips of unknown
#' `route_type` as `"unknown"`, ordered by `route_type` with `"unknown"` last.
#' Each mode is described as if selected alone (except that all headways share
#' the same day and time of day), so stops, shapes and agencies shared by
#' modes count in each. Only the numbers of routes and trips, the total trip
#' lengths and durations and `vkt_total` (or `vmt_total`) add up to `all`.
#' Modes whose routes have blank `agency_id`s count all the agencies of the
#' selection. Trips listed in `stop_times` but not in `trips` count only in
#' `all` (and not in the VKT, as they have no service).
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' if (
#'   requireNamespace("ggplot2", quietly = TRUE) &&
#'     requireNamespace("knitr", quietly = TRUE) &&
#'     requireNamespace("rmarkdown", quietly = TRUE) &&
#'     rmarkdown::pandoc_available()
#' ) {
#'   data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#'
#'   feed_summary <- get_summary(
#'     data_path,
#'     output_path = tempdir(),
#'     html_preview = FALSE
#'   )
#'   feed_summary$totals
#'
#'   \donttest{
#'   feed_summary <- get_summary(
#'     data_path,
#'     route_type = "bus",
#'     from = "07:00:00",
#'     to = "09:00:00",
#'     output_path = tempdir(),
#'     html_preview = FALSE
#'   )
#'   feed_summary$frequency
#'
#'   feed_summary <- get_summary(
#'     data_path,
#'     output_path = tempdir(),
#'     html_preview = FALSE,
#'     by_route_type = TRUE
#'   )
#'   feed_summary$totals
#'   }
#' }
#'
#' @export
get_summary <- function(
  gtfs,
  date = NULL,
  route_id = NULL,
  route_type = NULL,
  agency_id = NULL,
  from = NULL,
  to = NULL,
  output_path = NULL,
  html_preview = TRUE,
  by_route_type = FALSE,
  unit = "km/h"
) {
  if (!report_deps_available()) {
    cli::cli_abort(
      c(
        "{.fn get_summary} requires the {.pkg ggplot2}, {.pkg knitr} and
         {.pkg rmarkdown} packages, and Pandoc.",
        "i" = "Pandoc is shipped with RStudio, or see
               {.url https://pandoc.org/installing.html}."
      ),
      class = "gtfstools_report_dependencies_error"
    )
  }

  checkmate::assert(
    checkmate::check_string(gtfs),
    checkmate::check_class(gtfs, "gtfs"),
    .var.name = "gtfs"
  )
  if (is.character(gtfs)) {
    checkmate::assert_file_exists(gtfs)
  }
  if (!is.null(date)) {
    date <- parse_dates(date)
  }
  checkmate::assert_character(route_id, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert(
    checkmate::check_null(route_type),
    checkmate::check_integerish(route_type, any.missing = FALSE, min.len = 1),
    checkmate::check_character(route_type, any.missing = FALSE, min.len = 1),
    .var.name = "route_type"
  )
  checkmate::assert_character(agency_id, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert_string(output_path, null.ok = TRUE)
  checkmate::assert_flag(html_preview)
  checkmate::assert_flag(by_route_type)
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = c("km/h", "mph")),
    combine = "and"
  )

  checkmate::assert_string(from, pattern = time_pattern, null.ok = TRUE)
  checkmate::assert_string(to, pattern = time_pattern, null.ok = TRUE)
  if (xor(is.null(from), is.null(to))) {
    cli::cli_abort(
      "{.arg from} and {.arg to} must be given together.",
      class = "gtfstools_invalid_time_of_day"
    )
  }
  if (!is.null(from) && string_to_seconds(from) >= string_to_seconds(to)) {
    cli::cli_abort(
      "{.arg from} ({.val {from}}) must be earlier than {.arg to}
       ({.val {to}}).",
      class = "gtfstools_invalid_time_of_day"
    )
  }

  mode_route_types <- c(
    tram = 0L,
    subway = 1L,
    rail = 2L,
    bus = 3L,
    ferry = 4L,
    cable_tram = 5L,
    aerial_lift = 6L,
    funicular = 7L,
    trolleybus = 11L,
    monorail = 12L
  )
  if (is.character(route_type)) {
    checkmate::assert_names(route_type, subset.of = names(mode_route_types))
    route_type_codes <- unname(mode_route_types[route_type])
  } else {
    route_type_codes <- route_type
  }

  if (is.null(output_path)) {
    output_path <- file.path(tempdir(), "gtfstools")
  }

  progress_bar <- cli::cli_progress_bar(
    total = 9,
    format = paste0(
      "{cli::pb_spin} Summarising GTFS feed {cli::pb_bar} ",
      "{cli::pb_current}/{cli::pb_total} | {cli::pb_status}"
    ),
    status = "Reading the feed"
  )

  if (is.character(gtfs)) {
    gtfs <- read_gtfs(gtfs)
  } else {
    gtfs <- assert_and_assign_gtfs_object(gtfs)
  }

  # filter_by_agency_id() doesn't filter the routes of feeds whose 'routes'
  # table has no agency_id field, so unknown agencies are caught beforehand

  if (!is.null(agency_id)) {
    invalid_agency <- agency_id[!agency_id %chin% gtfs$agency$agency_id]

    if (length(invalid_agency) > 0) {
      cli::cli_abort(
        "{.arg agency_id} contains agency_id{?s} not listed in {.file agency}:
         {.val {invalid_agency}}.",
        class = "gtfstools_invalid_agency_id_error"
      )
    }
  }

  cli::cli_progress_update(id = progress_bar, status = "Applying filters")

  # times after midnight written as early morning times are fixed once, here,
  # so the functions used below find them already fixed

  gtfs <- fix_overnight_in_call(gtfs = gtfs, frequencies = TRUE)

  feed <- gtfs
  if (!is.null(agency_id)) {
    # feeds whose routes' agency_id is missing or blank have a single agency
    # (the up-front check ensures it's the given one), so they're not filtered

    route_agencies <- feed$routes$agency_id
    route_agencies <- route_agencies[!is.na(route_agencies)]
    if (any(route_agencies != "")) {
      feed <- filter_by_agency_id(feed, agency_id)
    }
  }
  if (!is.null(route_type_codes)) {
    feed <- filter_by_route_type(feed, route_type_codes)
  }
  if (!is.null(route_id)) {
    feed <- filter_by_route_id(feed, route_id)
  }
  if (!is.null(date)) {
    feed <- filter_by_date(feed, date)
  }

  # filter_by_time_of_day() moves the start of 'frequencies' entries to 'from',
  # which shifts their departures, so the vkt counts the departures of the
  # selected trips in the feed as it was before this filter

  untimed_feed <- feed
  if (!is.null(from)) {
    feed <- filter_by_time_of_day(feed, from, to, full_trips = TRUE)
  }

  if (NROW(feed$trips) == 0) {
    cli::cli_abort(
      "No trips match the given {.arg date}, {.arg route_id},
       {.arg route_type}, {.arg agency_id}, {.arg from} and {.arg to}.",
      class = "gtfstools_empty_selection_error"
    )
  }

  is_table <- vapply(gtfs, data.table::is.data.table, logical(1))
  files <- data.table::data.table(
    file = names(gtfs)[is_table],
    n_rows = vapply(gtfs[is_table], nrow, integer(1))
  )

  agency_cols <- c(
    "agency_id",
    "agency_name",
    "agency_timezone",
    "agency_url",
    "agency_lang"
  )
  agency_table <- data.table::data.table()
  if (gtfsio::check_file_exists(feed, "agency")) {
    agency_table <- feed$agency[,
      intersect(agency_cols, names(feed$agency)),
      with = FALSE
    ]
  }

  # the agencies are narrowed to those that run the selected trips, when the
  # 'routes' table links routes to agencies. single-agency feeds often leave
  # routes' agency_id blank, in which case no narrowing is done

  if (
    gtfsio::check_field_exists(feed, "routes", "agency_id") &&
      "agency_id" %chin% names(agency_table)
  ) {
    selected_routes <- feed$routes[route_id %chin% feed$trips$route_id]
    route_agencies <- selected_routes$agency_id
    route_agencies <- route_agencies[!is.na(route_agencies)]
    route_agencies <- route_agencies[route_agencies != ""]

    if (length(route_agencies) > 0) {
      agency_table <- agency_table[agency_id %chin% route_agencies]
    }
  }
  agency_table <- unique(agency_table)

  # speeds are calculated from the lengths and durations as in
  # get_trip_speed(), so that trip geometries are only built once

  cli::cli_progress_update(
    id = progress_bar,
    status = "Calculating trip lengths"
  )

  trip_stats <- get_trip_length(feed, unit = "km")

  # with unit = "mph", the trip and shape lengths are converted to miles as
  # soon as they are calculated, so that the speeds, the vmt and every
  # distance derived from them are in miles too. calculate_vkt() must
  # therefore always be given these lengths: without them, it would calculate
  # lengths in km

  length_unit <- if (unit == "mph") "mi" else "km"
  if (unit == "mph") {
    trip_stats[, length := length / km_per_mile]
  }

  cli::cli_progress_update(
    id = progress_bar,
    status = "Calculating trip speeds"
  )

  durations <- get_trip_duration(feed, unit = "h")
  trip_stats[durations, on = "trip_id", duration := i.duration]
  trip_stats[,
    speed := data.table::fifelse(
      is.finite(duration) & duration > 0,
      length / duration,
      NA_real_
    )
  ]

  cli::cli_progress_update(id = progress_bar, status = "Calculating VKT")

  vkt_window <- NULL
  if (!is.null(from)) {
    vkt_window <- time_of_day_window(from, to)
  }
  vkt <- calculate_vkt(
    untimed_feed,
    feed$trips[, .(trip_id, service_id, group = "all")],
    date,
    vkt_window,
    lengths = trip_stats
  )

  cli::cli_progress_update(
    id = progress_bar,
    status = "Calculating shape lengths"
  )

  # only the shapes used by the selected trips are summed

  shape_lengths <- NULL
  total_shape_length <- NA_real_
  mean_shape_length <- NA_real_
  if (
    gtfsio::check_file_exists(feed, "shapes") &&
      gtfsio::check_field_exists(feed, "trips", "shape_id")
  ) {
    shape_lengths <- get_shape_length(feed)
    shape_lengths <- shape_lengths[shape_id %chin% feed$trips$shape_id]
    if (unit == "mph") {
      shape_lengths[, length := length / km_per_mile]
    }
    total_shape_length <- sum_or_na(shape_lengths$length)
    mean_shape_length <- summarise_distribution(
      shape_lengths$length,
      length_unit
    )$mean
  }

  cli::cli_progress_update(
    id = progress_bar,
    status = "Summarising services"
  )

  service_days <- get_service_days(feed)
  services <- summarise_services(feed, service_days)

  calendar_plot <- NULL
  if (nrow(service_days) > 0) {
    calendar_plot <- get_calendar_overlap(list(feed = feed), plot = TRUE)
  }

  cli::cli_progress_update(
    id = progress_bar,
    status = "Calculating route frequencies"
  )

  frequency <- summarise_route_frequency(feed, service_days, date, from, to)

  cli::cli_progress_update(id = progress_bar, status = "Writing the report")

  speed <- summarise_distribution(trip_stats$speed, unit)
  distance <- summarise_distribution(trip_stats$length, length_unit)

  totals <- data.table::data.table(
    indicator = c(
      "n_agencies",
      "n_routes",
      "n_trips",
      "n_stops",
      "total_shape_length",
      "mean_shape_length",
      "total_trip_length",
      "mean_trip_length",
      if (unit == "mph") "vmt_total" else "vkt_total",
      if (unit == "mph") "vmt_daily_mean" else "vkt_daily_mean",
      "total_trip_duration",
      "mean_trip_duration",
      "mean_trip_speed",
      "mean_route_headway"
    ),
    value = c(
      nrow(agency_table),
      data.table::uniqueN(feed$trips$route_id),
      nrow(feed$trips),
      data.table::uniqueN(feed$stop_times$stop_id),
      total_shape_length,
      mean_shape_length,
      sum_or_na(trip_stats$length),
      distance$mean,
      vkt$vkt,
      vkt$vkt_daily_mean,
      sum_or_na(trip_stats$duration),
      summarise_distribution(trip_stats$duration * 60, "min")$mean,
      speed$mean,
      frequency$stats$mean
    ),
    unit = c(
      NA, NA, NA, NA, rep(length_unit, 5), paste0(length_unit, "/day"), "h",
      "min", unit, "min"
    )
  )

  frequency_table <- cbind(
    frequency$stats,
    date = frequency$date,
    from = frequency$from,
    to = frequency$to
  )

  plot_modes <- list()
  if (by_route_type) {
    # each trip is labelled with the mode of its route. trips whose route_type
    # is unknown (missing route, field or value) are grouped as "unknown",
    # after the modes, which are ordered by route_type

    trip_ids <- feed$trips$trip_id
    trip_routes <- feed$trips$route_id
    trip_codes <- rep(NA_integer_, length(trip_ids))
    if (gtfsio::check_field_exists(feed, "routes", "route_type")) {
      trip_codes <- suppressWarnings(
        as.integer(
          feed$routes$route_type[match(trip_routes, feed$routes$route_id)]
        )
      )
    }

    trip_labels <- names(mode_route_types)[match(trip_codes, mode_route_types)]
    is_extended <- is.na(trip_labels) & !is.na(trip_codes)
    trip_labels[is_extended] <- as.character(trip_codes[is_extended])
    trip_labels[is.na(trip_labels)] <- "unknown"
    mode_labels <- unique(trip_labels[order(trip_codes, na.last = TRUE)])

    # stops are counted in a single grouped pass, which only reads the
    # 'stop_id' column of 'stop_times'

    trip_modes <- data.table::data.table(trip_id = trip_ids, mode = trip_labels)
    stop_counts <- feed$stop_times[
      trip_modes,
      on = "trip_id",
      nomatch = NULL,
      .(stop_id, mode = i.mode)
    ][, .(n_stops = data.table::uniqueN(stop_id)), by = "mode"]

    # agencies are narrowed as in the 'agency' table above: modes whose routes
    # have blank agency_ids count all the agencies

    narrow_agencies <- gtfsio::check_field_exists(
      feed,
      "routes",
      "agency_id"
    ) &&
      "agency_id" %chin% names(agency_table)
    trip_shapes <- feed$trips$shape_id

    # calculate_vkt() returns a row for every mode, including those that don't
    # run on any counted day

    mode_vkt <- calculate_vkt(
      untimed_feed,
      data.table::data.table(
        trip_id = trip_ids,
        service_id = feed$trips$service_id,
        group = trip_labels
      ),
      date,
      vkt_window,
      lengths = trip_stats
    )

    mode_stats <- lapply(
      mode_labels,
      function(group_label) {
        in_mode <- trip_labels == group_label
        mode_trips <- trip_ids[in_mode]
        mode_routes <- unique(trip_routes[in_mode])

        n_agencies <- nrow(agency_table)
        if (narrow_agencies) {
          mode_agencies <- feed$routes$agency_id[
            feed$routes$route_id %chin% mode_routes
          ]
          mode_agencies <- mode_agencies[!is.na(mode_agencies)]
          mode_agencies <- mode_agencies[mode_agencies != ""]

          if (length(mode_agencies) > 0) {
            n_agencies <- sum(agency_table$agency_id %chin% mode_agencies)
          }
        }

        n_stops <- stop_counts$n_stops[stop_counts$mode == group_label]
        if (length(n_stops) == 0) {
          n_stops <- 0L
        }

        mode_shape_lengths <- NA_real_
        if (!is.null(shape_lengths)) {
          mode_shape_lengths <- shape_lengths$length[
            shape_lengths$shape_id %chin% trip_shapes[in_mode]
          ]
        }

        in_stats <- trip_stats$trip_id %chin% mode_trips
        mode_lengths <- trip_stats$length[in_stats]
        mode_durations <- trip_stats$duration[in_stats]
        mode_headways <- frequency$headways[
          names(frequency$headways) %chin% mode_routes
        ]

        mode_speed <- summarise_distribution(trip_stats$speed[in_stats], unit)
        mode_distance <- summarise_distribution(mode_lengths, length_unit)
        mode_frequency <- summarise_distribution(mode_headways, "min")

        is_mode_vkt <- mode_vkt$group == group_label

        mode_totals <- c(
          n_agencies,
          length(mode_routes),
          length(mode_trips),
          n_stops,
          sum_or_na(mode_shape_lengths),
          summarise_distribution(mode_shape_lengths, length_unit)$mean,
          sum_or_na(mode_lengths),
          mode_distance$mean,
          mode_vkt$vkt[is_mode_vkt],
          mode_vkt$vkt_daily_mean[is_mode_vkt],
          sum_or_na(mode_durations),
          summarise_distribution(mode_durations * 60, "min")$mean,
          mode_speed$mean,
          mode_frequency$mean
        )

        return(
          list(
            totals = mode_totals,
            speed = mode_speed,
            distance = mode_distance,
            frequency = mode_frequency
          )
        )
      }
    )
    names(mode_stats) <- mode_labels

    totals <- data.table::as.data.table(
      c(
        list(indicator = totals$indicator),
        lapply(mode_stats, `[[`, "totals"),
        list(all = totals$value, unit = totals$unit)
      )
    )

    stats_by_mode <- function(stat, all_stats) {
      mode_rows <- c(lapply(mode_stats, `[[`, stat), list(all = all_stats))
      return(data.table::rbindlist(mode_rows, idcol = "mode"))
    }

    speed <- stats_by_mode("speed", speed)
    distance <- stats_by_mode("distance", distance)
    frequency_table <- cbind(
      stats_by_mode("frequency", frequency$stats),
      date = frequency$date,
      from = frequency$from,
      to = frequency$to
    )

    # the plotted values are labelled by mode with all the modes as levels, so
    # that each mode has the same colour in every figure

    stats_labels <- trip_labels[match(trip_stats$trip_id, trip_ids)]
    headway_labels <- trip_labels[
      match(names(frequency$headways), trip_routes)
    ]
    plot_modes <- list(
      distance = factor(stats_labels, levels = mode_labels),
      speed = factor(stats_labels, levels = mode_labels),
      frequency = factor(headway_labels, levels = mode_labels)
    )
  }

  result <- list(
    files = files,
    agency = agency_table,
    services = services,
    totals = totals,
    speed = speed,
    frequency = frequency_table,
    distance = distance
  )

  selection <- list(
    date = if (is.null(date)) NULL else format(date),
    route_id = route_id,
    route_type = route_type,
    agency_id = agency_id,
    time_of_day = if (is.null(from)) NULL else paste(from, "-", to)
  )
  values <- list(
    speed = trip_stats$speed,
    distance = trip_stats$length,
    frequency = frequency$headways,
    calendar = calendar_plot,
    modes = plot_modes
  )
  report_path <- write_summary_report(result, values, selection, output_path)

  cli::cli_progress_done(id = progress_bar)

  if (html_preview && interactive()) {
    utils::browseURL(report_path)
    return(invisible(result))
  }

  return(result)
}



#' Check whether the report dependencies are available
#'
#' @return `TRUE` if `{ggplot2}`, `{knitr}`, `{rmarkdown}` and Pandoc are
#'   available, `FALSE` otherwise.
#'
#' @keywords internal
report_deps_available <- function() {
  return(
    requireNamespace("ggplot2", quietly = TRUE) &&
      requireNamespace("knitr", quietly = TRUE) &&
      requireNamespace("rmarkdown", quietly = TRUE) &&
      rmarkdown::pandoc_available()
  )
}



#' Summarise a distribution
#'
#' @param x A numeric vector. `NA`s are ignored.
#' @param unit A string. The unit of `x`.
#'
#' @return A one-row `data.table` with the columns `n` (the number of non-`NA`
#'   values), `min`, `q25`, `median`, `mean`, `q75`, `max` (all `NA` if there
#'   are no non-`NA` values) and `unit`.
#'
#' @keywords internal
summarise_distribution <- function(x, unit) {
  x <- x[!is.na(x)]

  stats <- rep(NA_real_, 6)
  if (length(x) > 0) {
    quartiles <- stats::quantile(x, c(0, 0.25, 0.5, 0.75, 1), names = FALSE)
    stats <- c(quartiles[1:3], mean(x), quartiles[4:5])
  }

  distribution <- data.table::data.table(
    n = length(x),
    min = stats[1],
    q25 = stats[2],
    median = stats[3],
    mean = stats[4],
    q75 = stats[5],
    max = stats[6],
    unit = unit
  )

  return(distribution)
}



#' Summarise the calendar of the services of a feed
#'
#' @param feed A `dt_gtfs` object, already filtered.
#' @param service_days The service days of `feed`, as returned by
#'   `get_service_days()`.
#'
#' @return A one-row `data.table`, as described in the `services` element of
#'   the [get_summary()] output.
#'
#' @keywords internal
summarise_services <- function(feed, service_days) {
  has_days <- nrow(service_days) > 0
  start_date <- as.Date(NA)
  end_date <- as.Date(NA)
  busiest_date <- as.Date(NA)

  if (has_days) {
    start_date <- min(service_days$date)
    end_date <- max(service_days$date)
    busiest_date <- service_days$date[which.max(service_days$n_trips)]
  }

  # feed_info dates are read as Dates, but a feed built by hand may have them
  # as "YYYYMMDD" strings

  feed_info_date <- function(field) {
    if (!gtfsio::check_field_exists(feed, "feed_info", field)) {
      return(as.Date(NA))
    }

    value <- feed$feed_info[[field]][1]
    if (!inherits(value, "Date")) {
      value <- as.Date(as.character(value), format = "%Y%m%d")
    }

    return(value)
  }

  services <- data.table::data.table(
    start_date = start_date,
    end_date = end_date,
    n_days = as.integer(end_date - start_date) + 1L,
    n_service_days = nrow(service_days),
    n_services = data.table::uniqueN(feed$trips$service_id),
    mean_trips_per_day = if (has_days) mean(service_days$n_trips) else NA_real_,
    busiest_date = busiest_date,
    max_trips_per_day = if (has_days) {
      as.numeric(max(service_days$n_trips))
    } else {
      NA_real_
    },
    feed_start_date = feed_info_date("feed_start_date"),
    feed_end_date = feed_info_date("feed_end_date")
  )

  return(services)
}



#' Calculate the route headways of a feed on its busiest day
#'
#' @param feed A `dt_gtfs` object, already filtered.
#' @param service_days The service days of `feed`, as returned by
#'   `get_service_days()`.
#' @param date A `Date` vector, or `NULL`. The day is chosen among these dates.
#' @param from,to Strings in the `"HH:MM:SS"` format, or `NULL`, in which case
#'   the time of day spans the departures of the day, rounded out to whole
#'   hours.
#'
#' @return A list with the elements `headways` (the headway of each route and
#'   direction, in minutes, named by `route_id`), `stats` (their summary, as
#'   created by [summarise_distribution()]), `date`, `from` and `to` (the day
#'   and time of day in which the headways were measured, `NA` if there is
#'   none).
#'
#' @keywords internal
summarise_route_frequency <- function(feed, service_days, date, from, to) {
  user_dates <- date
  headways <- numeric(0)
  frequency_day <- as.Date(NA)
  frequency_from <- NA_character_
  frequency_to <- NA_character_

  if (!is.null(user_dates)) {
    service_days <- service_days[service_days$date %in% user_dates]
  }

  if (nrow(service_days) == 0) {
    cli::cli_warn(
      "The selected services run on no day, so route frequencies were not
       calculated.",
      class = "gtfstools_no_service_days"
    )
  } else {
    busiest_day <- service_days$date[which.max(service_days$n_trips)]
    day_feed <- filter_by_date(feed, busiest_day)

    # the default time of day spans the departures of the day (which include
    # those listed in 'frequencies'), and ends one hour after the last
    # departure is rounded down, because 'to' itself is excluded

    if (is.null(from)) {
      departures <- get_trip_departures(day_feed, day_feed$trips$trip_id)

      if (nrow(departures) > 0) {
        first_departure <- min(departures$departure_secs, na.rm = TRUE)
        last_departure <- max(departures$departure_secs, na.rm = TRUE)
        from <- seconds_to_string(as.integer(first_departure %/% 3600 * 3600))
        to <- seconds_to_string(
          as.integer((last_departure %/% 3600 + 1) * 3600)
        )
      }
    }

    if (!is.null(from)) {
      frequency_day <- busiest_day
      frequency_from <- from
      frequency_to <- to

      route_frequency <- get_route_frequency(day_feed, from = from, to = to)
      group_cols <- setdiff(
        names(route_frequency),
        c("service_id", "departures", "mean_headway")
      )
      route_frequency <- route_frequency[,
        .(departures = sum(departures)),
        by = group_cols
      ]

      window_minutes <- (string_to_seconds(to) - string_to_seconds(from)) / 60
      headways <- window_minutes / route_frequency$departures
      names(headways) <- route_frequency$route_id
    }
  }

  frequency <- list(
    headways = headways,
    stats = summarise_distribution(headways, "min"),
    date = frequency_day,
    from = frequency_from,
    to = frequency_to
  )

  return(frequency)
}



#' Write and render the report of get_summary()
#'
#' @param result The list of diagnostics returned by [get_summary()].
#' @param values A named list with the numeric vectors to be plotted
#'   (`speed`, `distance` and `frequency`), the calendar chart created by
#'   [get_calendar_overlap()] (`calendar`, `NULL` if there is none) and a
#'   named list with the mode of each plotted value, as factors (`modes`,
#'   empty if the values are not grouped by mode).
#' @param selection A named list with the filters used (`NULL` elements mean
#'   no filter).
#' @param output_dir A string. The directory in which the report is saved.
#'
#' @return The path to the HTML report.
#'
#' @keywords internal
write_summary_report <- function(result, values, selection, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # large numbers (e.g. the vkt) are shown in full, not in scientific notation,
  # in the tables and in the axes of the figures

  old_options <- options(scipen = 999)
  on.exit(options(old_options), add = TRUE)

  # text from the feed is escaped so that pandoc doesn't read it as markdown
  # (e.g. "$...$" as math). pipes are escaped by knitr::kable(), and the
  # escaped brackets aren't read as math because tex_math_single_backslash is
  # turned off when rendering

  md_escape <- function(x) {
    return(gsub("([\\\\`*_$<>#~^\\[\\]])", "\\\\\\1", x, perl = TRUE))
  }

  # missing strings and dates (e.g. the unit of counts) are shown as blank
  # cells

  md_table <- function(x) {
    x <- as.data.frame(x)
    is_text <- vapply(
      x,
      function(col) is.character(col) || inherits(col, "Date"),
      logical(1)
    )
    x[is_text] <- lapply(
      x[is_text],
      function(col) ifelse(is.na(col), "", md_escape(as.character(col)))
    )

    table <- knitr::kable(
      x,
      format = "pipe",
      digits = 2,
      format.args = list(drop0trailing = TRUE, big.mark = ",")
    )
    return(c("", as.character(table), ""))
  }

  # every figure uses the same theme, which is built only once because
  # building it takes a noticeable share of the report time

  report_theme <- ggplot2::theme_minimal()

  md_saved_plot <- function(plot, name) {
    plot_file <- paste0("gtfs_summary_", name, ".png")
    ggplot2::ggsave(
      file.path(output_dir, plot_file),
      plot + report_theme,
      width = 7,
      height = 4,
      dpi = 150,
      bg = "white"
    )

    return(c("", paste0("![](", plot_file, ")"), ""))
  }

  # each distribution is plotted as a histogram, unless it has no values. with
  # modes, the histograms of the modes are overlaid

  md_plot <- function(x, label, name, mode = NULL) {
    if (!is.null(mode)) {
      keep <- !is.na(x)
      if (!any(keep)) {
        return(c("", "No data to plot.", ""))
      }

      plot <- ggplot2::ggplot(
        data.frame(value = x[keep], mode = mode[keep]),
        ggplot2::aes(x = value, fill = mode)
      ) +
        ggplot2::geom_histogram(
          bins = 30,
          position = "identity",
          alpha = 0.4
        ) +
        ggplot2::scale_fill_viridis_d(drop = FALSE, end = 0.85) +
        ggplot2::labs(x = label, y = "Count", fill = "Mode")

      return(md_saved_plot(plot, name))
    }

    x <- x[!is.na(x)]
    if (length(x) == 0) {
      return(c("", "No data to plot.", ""))
    }

    plot <- ggplot2::ggplot(data.frame(value = x), ggplot2::aes(x = value)) +
      ggplot2::geom_histogram(bins = 30, fill = "#0072B2") +
      ggplot2::labs(x = label, y = "Count")

    return(md_saved_plot(plot, name))
  }

  md_calendar_plot <- function(plot) {
    if (is.null(plot)) {
      return(c("", "No service days to plot.", ""))
    }

    return(md_saved_plot(plot, "calendar"))
  }

  selection_lines <- vapply(
    names(selection),
    function(name) {
      value <- selection[[name]]
      value <- if (is.null(value)) {
        "all"
      } else {
        md_escape(paste(value, collapse = ", "))
      }
      paste0("- **", name, "**: ", value)
    },
    character(1)
  )

  # the frequency table has a row per mode when grouped by route_type, all
  # measured on the same day and time of day

  frequency <- result$frequency
  frequency_note <- if (is.na(frequency$from[1])) {
    "Route frequencies could not be calculated."
  } else {
    paste0(
      "Headways by route (and direction) on ",
      format(frequency$date[1]),
      ", between ",
      frequency$from[1],
      " and ",
      frequency$to[1],
      "."
    )
  }

  lines <- c(
    "---",
    "title: \"GTFS feed description\"",
    paste0("date: \"", format(Sys.Date()), "\""),
    "---",
    "",
    "## Selection",
    "",
    selection_lines,
    "",
    "## Files",
    md_table(result$files),
    "## Agencies",
    md_table(result$agency),
    "## Services",
    md_table(result$services),
    md_calendar_plot(values$calendar),
    "## Totals",
    md_table(result$totals),
    "## Trip speed",
    md_table(result$speed),
    md_plot(
      values$speed,
      paste0("Trip speed (", result$speed$unit[1], ")"),
      "speed",
      values$modes$speed
    ),
    "## Trip distance",
    md_table(result$distance),
    md_plot(
      values$distance,
      paste0("Trip length (", result$distance$unit[1], ")"),
      "distance",
      values$modes$distance
    ),
    "## Route frequency",
    "",
    frequency_note,
    md_table(result$frequency),
    md_plot(
      values$frequency,
      "Route headway (min)",
      "frequency",
      values$modes$frequency
    )
  )

  md_path <- file.path(output_dir, "gtfs_summary.md")
  writeLines(enc2utf8(lines), md_path, useBytes = TRUE)

  html_path <- rmarkdown::render(
    md_path,
    output_format = rmarkdown::html_document(
      md_extensions = "-tex_math_single_backslash"
    ),
    output_file = "gtfs_summary.html",
    output_dir = output_dir,
    intermediates_dir = output_dir,
    envir = new.env(),
    quiet = TRUE
  )

  return(html_path)
}
