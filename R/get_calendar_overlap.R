#' Get calendar overlap
#'
#' Returns the periods in which all the given GTFS feeds have service, or the
#' number of trips each feed runs on each of its service days. Either result
#' can also be plotted. Useful to pick a date on which several feeds can be
#' analysed together (e.g. when routing on the networks of different
#' agencies).
#'
#' @param gtfs Either a character vector with the paths to GTFS `.zip` files
#'   or a list of GTFS objects, as created by [read_gtfs()] (a single GTFS
#'   object must be wrapped in a list).
#' @param resolution A string. `"daily"` (the default) returns the number of
#'   trips of each feed on each of its service days, and `"periods"` the
#'   periods in which all feeds have service.
#' @param plot A logical. Whether to return a plot of the result instead of
#'   the result itself (requires the `{ggplot2}` package). Defaults to `FALSE`.
#'
#' @return If `plot = FALSE` and `resolution = "periods"`, a `data.table` with
#'   one row per period of consecutive days on which all feeds have service,
#'   and the columns `start_date`, `end_date` (both included in the period) and
#'   `n_days`. It has no rows if there is no such day.
#'
#'   If `plot = FALSE` and `resolution = "daily"`, a `data.table` with one row
#'   per feed and service day, and the columns `feed`, `date`, `n_trips` (the
#'   number of trips that run on the day) and `overlap` (whether all feeds have
#'   service on the day).
#'
#'   If `plot = TRUE`, a `ggplot` object. With `resolution = "periods"`, it
#'   shows one bar per feed (top to bottom in the given order) spanning its
#'   service days. With `resolution = "daily"`, it shows the density of each
#'   feed's trips over time (weighted by the number of trips per day), one
#'   panel per feed. In both, the overlap periods are shaded.
#'
#' @section Details:
#' A feed has service on a day if at least one of its services runs on it. A
#' service runs on the days between the `start_date` and `end_date` of its
#' `calendar` entry whose weekday is flagged, minus the days removed from it
#' in `calendar_dates` (`exception_type` 2), plus the days added to it
#' (`exception_type` 1). If a service is both added and removed on a day, the
#' addition wins. Either table may be missing. If the feed has a `trips`
#' table with a `service_id` field, services not used by any trip are ignored.
#' `feed_info` dates are not used. A warning is raised for feeds without any
#' service day.
#'
#' The number of trips on a day is the number of trips of the services that
#' run on it. A trip listed in `frequencies` counts once per departure, every
#' `headway_secs` from `start_time` until (but not including) `end_time` (an
#' entry whose `start_time` and `end_time` are equal departs once), and
#' the departures of overlapping entries of the same trip are added up
#' (identical entries count once), unlike in [frequencies_to_stop_times()],
#' which keeps only their unique departures. A trip with an invalid
#' `frequencies` entry counts once, with a warning. Trips count on their
#' service day, so departures after midnight (with times later than
#' `"24:00:00"`) count on the previous day. If the feed
#' has no `trips` table with a `service_id` field, `n_trips` is `NA`, and the
#' daily plot shows the density of its service days instead.
#'
#' Feeds are named after their file names (without the extension) or after the
#' list names. Unnamed feeds are named after their position (`"feed_1"`,
#' `"feed_2"`, etc.), and duplicated names are made unique. Plots of feeds
#' spanning long periods can be zoomed in with [ggplot2::coord_cartesian()].
#'
#' @seealso [merge_gtfs()], [filter_by_service_id()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
#'
#' # feeds may be given as paths to their .zip files
#' daily_trips <- get_calendar_overlap(c(spo_path, poa_path))
#' head(daily_trips)
#'
#' # or as a list of GTFS objects, whose names are used as feed names
#' feeds <- list(spo = read_gtfs(spo_path), poa = read_gtfs(poa_path))
#' get_calendar_overlap(feeds, resolution = "periods")
#'
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   get_calendar_overlap(feeds, plot = TRUE)
#' }
#'
#' @export
get_calendar_overlap <- function(gtfs, resolution = "daily", plot = FALSE) {
  checkmate::assert(
    checkmate::check_character(gtfs, min.len = 1, any.missing = FALSE),
    checkmate::check_list(gtfs, types = "gtfs", min.len = 1),
    .var.name = "gtfs"
  )
  checkmate::assert_string(resolution)
  checkmate::assert_names(resolution, subset.of = c("periods", "daily"))
  checkmate::assert_flag(plot)

  if (plot && !requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort(
      "The {.pkg ggplot2} package is required when {.code plot = TRUE}.",
      class = "gtfstools_missing_ggplot2_error"
    )
  }

  # feeds given as paths are named after their files and read without their
  # largest tables, which are not needed. 'skip' is used instead of 'files'
  # because the latter errors when a listed file is missing

  if (is.character(gtfs)) {
    checkmate::assert_file_exists(gtfs)
    feed_names <- sub("\\.[^.]*$", "", basename(gtfs))
    feeds <- lapply(gtfs, read_gtfs, skip = c("shapes", "stop_times"))
  } else {
    feed_names <- names(gtfs)
    if (is.null(feed_names)) feed_names <- character(length(gtfs))
    feeds <- lapply(gtfs, assert_and_assign_gtfs_object)
  }

  unnamed <- feed_names %in% c("", NA)
  feed_names[unnamed] <- paste0("feed_", which(unnamed))
  feed_names <- make.unique(feed_names, sep = "_")

  service_days <- lapply(
    feeds,
    get_service_days,
    count_trips = resolution == "daily"
  )
  names(service_days) <- feed_names

  no_service <- feed_names[vapply(service_days, nrow, integer(1)) == 0L]
  if (length(no_service) > 0L) {
    cli::cli_warn(
      "Feed{?s} {.val {no_service}} ha{?s/ve} no service days.",
      class = "gtfstools_no_service_days"
    )
  }

  # days are intersected as integers, which is much faster than as dates

  overlap_days <- Reduce(
    intersect,
    lapply(service_days, function(days) as.integer(days$date))
  )
  overlap <- dates_to_periods(as.Date(overlap_days, origin = "1970-01-01"))

  if (resolution == "periods" && !plot) return(overlap)

  if (resolution == "daily") {
    daily_trips <- data.table::rbindlist(service_days, idcol = "feed")
    daily_trips[, overlap := as.integer(date) %in% overlap_days]

    if (!plot) return(daily_trips[])
  }

  # colours are okabe-ito orange (overlap) and blue (feeds)

  if (resolution == "periods") {
    feed_periods <- data.table::rbindlist(
      lapply(service_days, function(days) dates_to_periods(days$date)),
      idcol = "feed"
    )

    # the first feed is plotted at the top. tiles span from the first day of
    # a period to the end of its last day, so that one-day periods are
    # visible

    overlap_plot <- ggplot2::ggplot() +
      ggplot2::geom_rect(
        data = overlap,
        ggplot2::aes(xmin = start_date, xmax = end_date + 1),
        ymin = -Inf,
        ymax = Inf,
        fill = "#E69F00",
        alpha = 0.4
      ) +
      ggplot2::geom_tile(
        data = feed_periods,
        ggplot2::aes(x = start_date + n_days / 2, y = feed, width = n_days),
        height = 0.6,
        fill = "#0072B2"
      ) +
      ggplot2::scale_y_discrete(limits = rev(feed_names)) +
      ggplot2::labs(x = "Date", y = NULL)
  } else {
    # each feed's density weighs its days by their number of trips. days of
    # feeds without trip counts weigh 1

    daily_trips[
      ,
      `:=`(
        feed = factor(feed, levels = feed_names),
        density_weight = data.table::fifelse(is.na(n_trips), 1, n_trips)
      )
    ]

    overlap_plot <- ggplot2::ggplot() +
      ggplot2::geom_rect(
        data = overlap,
        ggplot2::aes(xmin = start_date - 0.5, xmax = end_date + 0.5),
        ymin = -Inf,
        ymax = Inf,
        fill = "#E69F00",
        alpha = 0.4
      ) +
      ggplot2::geom_density(
        data = daily_trips,
        ggplot2::aes(x = date, weight = density_weight),
        colour = "#0072B2",
        fill = "#0072B2",
        alpha = 0.6
      ) +
      ggplot2::facet_wrap(
        ggplot2::vars(feed),
        ncol = 1,
        scales = "free_y",
        drop = FALSE
      ) +
      ggplot2::labs(x = "Date", y = "Density of trips")
  }

  overlap_plot <- overlap_plot +
    ggplot2::labs(subtitle = "Shaded: days on which all feeds have service") +
    ggplot2::theme_minimal()

  return(overlap_plot)
}



#' Get the service days of a GTFS object and their number of trips
#'
#' Returns the days on which at least one service used by a trip runs (any
#' service, if `trips` has no `service_id` field), according to the `calendar`
#' and `calendar_dates` tables (either may be missing), and the number of
#' trips that run on each of them.
#'
#' @template gtfs
#' @param count_trips A logical. Whether to count the trips of each day. If
#'   `FALSE`, `n_trips` is `NA`, which is faster when only the days are needed.
#'
#' @return A `data.table` with the columns `date` and `n_trips` (`NA` if
#'   `trips` has no `service_id` field or if `count_trips = FALSE`), sorted by
#'   date, with one row per service day.
#'
#' @keywords internal
get_service_days <- function(gtfs, count_trips = TRUE) {
  weekday_cols <- c(
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday"
  )

  # each service weighs the number of trips it runs on a day. without trips,
  # or when they aren't counted, every service used by a trip (or every
  # service, without trips) weighs 1. services are referred to by their row in
  # 'service_weights' (sid), which makes the joins below faster than with
  # character ids

  has_trips <- gtfsio::check_field_exists(gtfs, "trips", "service_id")
  uses_trip_counts <- has_trips && count_trips

  if (uses_trip_counts) {
    service_weights <- get_service_weights(gtfs)
  } else {
    if (has_trips) {
      gtfsio::assert_field_class(gtfs, "trips", "service_id", "character")
      service_ids <- unique(gtfs$trips$service_id)
    } else {
      service_ids <- unique(
        c(gtfs[["calendar"]]$service_id, gtfs[["calendar_dates"]]$service_id)
      )
    }

    service_weights <- data.table::data.table(
      service_id = service_ids[!is.na(service_ids)],
      weight = 1
    )
  }

  # one row per service and weekday on which it runs, with the first and last
  # days of its calendar entry as integers (entries with missing or inverted
  # dates, and services without weight, are dropped)

  service_intervals <- data.table::data.table(
    sid = integer(0),
    weekday = integer(0),
    first_day = integer(0),
    last_day = integer(0)
  )

  if (gtfsio::check_file_exists(gtfs, "calendar")) {
    gtfsio::assert_field_class(
      gtfs,
      "calendar",
      c("service_id", weekday_cols, "start_date", "end_date"),
      c("character", rep("integer", 7), "Date", "Date")
    )

    calendar <- gtfs$calendar[
      ,
      c("service_id", weekday_cols, "start_date", "end_date"),
      with = FALSE
    ]
    calendar[, sid := match(service_id, service_weights$service_id)]

    service_intervals <- data.table::melt(
      calendar[!is.na(sid)],
      id.vars = c("sid", "start_date", "end_date"),
      measure.vars = weekday_cols,
      variable.name = "weekday",
      value.name = "runs"
    )
    service_intervals <- service_intervals[
      runs %in% 1L & start_date <= end_date,
      .(
        sid,
        weekday = as.integer(weekday),
        first_day = as.integer(start_date),
        last_day = as.integer(end_date)
      )
    ]
  }

  if (nrow(service_intervals) > 0L) {
    service_intervals <- merge_service_intervals(service_intervals)
  }

  # trips are counted on each day with a running sum by weekday, which adds
  # the weight of a service on the first day of its intervals and subtracts it
  # after the last. this splits each weekday into segments of constant weight,
  # whose days of that weekday are listed with their weight. listing the days
  # of each service instead could create millions of rows

  changes <- data.table::rbindlist(
    list(
      service_intervals[
        ,
        .(weekday, day = first_day, change = service_weights$weight[sid])
      ],
      service_intervals[
        ,
        .(weekday, day = last_day + 1L, change = -service_weights$weight[sid])
      ]
    )
  )
  changes <- changes[, .(change = sum(change)), keyby = .(weekday, day)]
  changes[
    ,
    `:=`(
      weight = cumsum(change),
      next_day = data.table::shift(day, type = "lead")
    ),
    by = weekday
  ]
  segments <- changes[weight > 0]

  # each segment is expanded into its days of the given weekday only, starting
  # from the first of them. 1970-01-01 was a thursday, so (day + 3) %% 7 + 1
  # is the weekday of a day (1 is monday), regardless of the locale

  first_weekday <- (segments$day + 3L) %% 7L + 1L
  first_match <- segments$day + (segments$weekday - first_weekday) %% 7L
  n_matches <- (segments$next_day - 1L - first_match) %/% 7L + 1L
  segment_idx <- rep(seq_len(nrow(segments)), n_matches)

  day_weights <- data.table::data.table(
    date = first_match[segment_idx] + 7L * (sequence(n_matches) - 1L),
    weight = segments$weight[segment_idx]
  )

  # exceptions apply per service: on each of its dates, an exception adds the
  # weight of its service if the service is added and doesn't run on the day
  # through the calendar, and subtracts it if the service is removed and runs
  # on it. an addition wins over a removal of the same service and day

  if (gtfsio::check_file_exists(gtfs, "calendar_dates")) {
    gtfsio::assert_field_class(
      gtfs,
      "calendar_dates",
      c("service_id", "date", "exception_type"),
      c("character", "Date", "integer")
    )

    exceptions <- gtfs$calendar_dates[
      ,
      .(
        sid = match(service_id, service_weights$service_id),
        date = as.integer(date),
        exception_type
      )
    ]
    exceptions <- exceptions[!is.na(sid) & !is.na(date)]

    if (nrow(exceptions) > 0L) {
      # max() over plain columns is used instead of any() because data.table
      # optimises it

      exceptions[
        ,
        `:=`(
          is_added = exception_type %in% 1L,
          is_removed = exception_type %in% 2L
        )
      ]
      exception_days <- exceptions[
        ,
        .(is_added = max(is_added), is_removed = max(is_removed)),
        keyby = .(sid, date)
      ]
      exception_days[, weekday := (date + 3L) %% 7L + 1L]  # as above

      # the intervals of a service on a weekday don't overlap, so each exception
      # day falls within at most one of them

      covering_interval <- service_intervals[
        exception_days,
        on = .(sid, weekday, first_day <= date, last_day >= date),
        mult = "first",
        which = TRUE
      ]
      exception_days[, is_covered := !is.na(covering_interval)]

      exception_days[
        ,
        weight := service_weights$weight[sid] *
          ((is_added | (is_covered & !is_removed)) - is_covered)
      ]

      day_weights <- rbind(day_weights, exception_days[, .(date, weight)])
    }
  }

  service_days <- day_weights[, .(weight = sum(weight)), keyby = date]
  service_days <- service_days[weight > 0]

  n_trips <- rep(NA_integer_, nrow(service_days))
  if (uses_trip_counts) n_trips <- as.integer(service_days$weight)

  service_days <- data.table::data.table(
    date = as.Date(service_days$date, origin = "1970-01-01"),
    n_trips = n_trips
  )

  return(service_days)
}



#' Get the service days of a GTFS object
#'
#' Returns the days on which at least one service used by a trip runs (any
#' service, if `trips` has no `service_id` field), according to the `calendar`
#' and `calendar_dates` tables (either may be missing).
#'
#' @template gtfs
#'
#' @return A sorted `Date` vector of unique days, empty if the feed has none.
#'
#' @keywords internal
get_service_period <- function(gtfs) {
  service_days <- get_service_days(gtfs, count_trips = FALSE)

  return(service_days$date)
}



#' Get the number of trips each service runs on a day
#'
#' Each trip counts once, except those listed in `frequencies`, which count
#' once per departure. A trip with an invalid `frequencies` entry counts once,
#' with a warning.
#'
#' @template gtfs
#'
#' @return A `data.table` with the columns `service_id` and `weight` (the
#'   number of trips, as a double).
#'
#' @keywords internal
get_service_weights <- function(gtfs) {
  gtfsio::assert_field_class(
    gtfs,
    "trips",
    c("trip_id", "service_id"),
    c("character", "character")
  )

  trips <- gtfs$trips[!is.na(service_id), .(trip_id, service_id)]
  if (anyDuplicated(trips$trip_id) > 0L) trips <- unique(trips)
  trips[, weight := 1]

  if (gtfsio::check_file_exists(gtfs, "frequencies")) {
    gtfsio::assert_field_class(
      gtfs,
      "frequencies",
      c("trip_id", "start_time", "end_time", "headway_secs"),
      c("character", "character", "character", "integer")
    )

    # the subset uses a logical vector, which, unlike %chin% inside the
    # brackets, doesn't add an index to the given table

    is_relevant <- !is.na(gtfs$frequencies$trip_id) &
      gtfs$frequencies$trip_id %chin% trips$trip_id
    frequencies <- unique(
      gtfs$frequencies[
        is_relevant,
        .(trip_id, start_time, end_time, headway_secs)
      ]
    )

    # malformed times are reported below, as invalid entries

    withCallingHandlers(
      frequencies[
        ,
        `:=`(
          start_secs = string_to_seconds(start_time),
          end_secs = string_to_seconds(end_time)
        )
      ],
      gtfstools_malformed_time = function(w) invokeRestart("muffleWarning")
    )

    # the departures of an entry are every headway_secs from start_time until
    # (but not including) end_time, as in get_frequencies_departures(). an
    # entry whose start and end times are equal departs once

    frequencies[
      ,
      is_invalid := is.na(start_secs) | is.na(end_secs) |
        is.na(headway_secs) | end_secs < start_secs |
        (headway_secs <= 0L & end_secs != start_secs)
    ]
    frequencies[
      is_invalid == FALSE,
      n_departures := data.table::fifelse(
        end_secs == start_secs,
        1,
        (end_secs - start_secs - 1) %/% headway_secs + 1
      )
    ]

    invalid_trips <- unique(frequencies[is_invalid == TRUE]$trip_id)
    if (length(invalid_trips) > 0L) {
      cli::cli_warn(
        c(
          paste0(
            "{.file frequencies} has invalid entries for ",
            "{length(invalid_trips)} trip_id{?s}: {.val {invalid_trips}}."
          ),
          "i" = "Each of these trips is counted once."
        ),
        class = "gtfstools_invalid_frequencies_warning"
      )
    }

    frequency_weights <- frequencies[
      !trip_id %chin% invalid_trips,
      .(weight = sum(n_departures)),
      by = trip_id
    ]
    # a trip_id may be listed under several services, so every row of a trip
    # gets its weight

    weight_idx <- match(trips$trip_id, frequency_weights$trip_id)
    has_weight <- which(!is.na(weight_idx))
    data.table::set(
      trips,
      i = has_weight,
      j = "weight",
      value = frequency_weights$weight[weight_idx[has_weight]]
    )
  }

  service_weights <- trips[, .(weight = sum(weight)), by = service_id]

  return(service_weights)
}



#' Merge the overlapping calendar intervals of each service and weekday
#'
#' @param service_intervals A `data.table` with the columns `sid`, `weekday`,
#'   `first_day` and `last_day` (integer days since 1970-01-01).
#'
#' @return A `data.table` with the same columns, in which the intervals of a
#'   service on a weekday don't overlap. `service_intervals` is reordered by
#'   reference.
#'
#' @keywords internal
merge_service_intervals <- function(service_intervals) {
  data.table::setorder(service_intervals, sid, weekday, first_day)

  # the intervals are merged in a single pass, without grouping. each group
  # (a service and weekday) is moved to its own range of a common axis, as
  # (group * span + day - base_day), so that a running max of the last days
  # never crosses groups. the keys are doubles, which are exact up to 2^53

  base_day <- min(service_intervals$first_day)
  span <- as.numeric(max(service_intervals$last_day)) - base_day + 2
  group_offset <- data.table::rleidv(service_intervals, c("sid", "weekday")) *
    span - base_day

  first_key <- group_offset + service_intervals$first_day
  last_key <- cummax(group_offset + service_intervals$last_day)

  starts <- which(first_key > data.table::shift(last_key, fill = -Inf))
  ends <- c(starts[-1L] - 1L, nrow(service_intervals))

  merged_intervals <- service_intervals[starts, .(sid, weekday, first_day)]
  merged_intervals[
    ,
    last_day := as.integer(last_key[ends] - group_offset[ends])
  ]

  return(merged_intervals)
}



#' Collapse days into periods of consecutive days
#'
#' @param dates A sorted `Date` vector of unique days.
#'
#' @return A `data.table` with the columns `start_date`, `end_date` and
#'   `n_days`, with one row per period of consecutive days.
#'
#' @keywords internal
dates_to_periods <- function(dates) {
  # in sorted unique dates, the date minus its position is constant within
  # each period of consecutive days

  period_id <- as.integer(dates) - seq_along(dates)
  start_date <- dates[!duplicated(period_id)]
  end_date <- dates[!duplicated(period_id, fromLast = TRUE)]

  periods <- data.table::data.table(
    start_date = start_date,
    end_date = end_date,
    n_days = as.integer(end_date - start_date) + 1L
  )

  return(periods)
}
