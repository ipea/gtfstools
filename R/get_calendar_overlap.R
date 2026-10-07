#' Get calendar overlap
#'
#' Returns the periods in which all the given GTFS feeds have service, or a
#' timeline plot of each feed's service days with these periods highlighted.
#' Useful to pick a date on which several feeds can be analysed together (e.g.
#' when routing on the networks of different agencies).
#'
#' @param gtfs Either a character vector with the paths to GTFS `.zip` files
#'   or a list of GTFS objects, as created by [read_gtfs()] (a single GTFS
#'   object must be wrapped in a list).
#' @param output A string. `"df"` (the default) returns the overlap periods as
#'   a `data.table`, and `"plot"` a timeline of each feed's service days
#'   (requires the `{ggplot2}` package).
#'
#' @return If `output = "df"`, a `data.table` with one row per period of
#'   consecutive days on which all feeds have service, and the columns
#'   `start_date`, `end_date` (both included in the period) and `n_days`. It
#'   has no rows if there is no such day. If `output = "plot"`, a `ggplot`
#'   object with one bar per feed (top to bottom in the given order) spanning
#'   its service days, and the overlap periods shaded in the background.
#'
#' @section Details:
#' A feed has service on a day if at least one of its services runs on it. A
#' service runs on the days between the `start_date` and `end_date` of its
#' `calendar` entry whose weekday is flagged, minus the days removed from it
#' in `calendar_dates` (`exception_type` 2), plus the days added to it
#' (`exception_type` 1). Either table may be missing. If the feed has a `trips`
#' table with a `service_id` field, services not used by any trip are ignored.
#' `feed_info` dates are not used. A warning is raised for feeds without any
#' service day.
#'
#' Feeds are named after their file names (without the extension) or after the
#' list names. Unnamed feeds are named after their position (`"feed_1"`,
#' `"feed_2"`, etc.), and duplicated names are made unique.
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
#' get_calendar_overlap(c(spo_path, poa_path))
#'
#' # or as a list of GTFS objects, whose names are used as feed names
#' feeds <- list(spo = read_gtfs(spo_path), poa = read_gtfs(poa_path))
#' get_calendar_overlap(feeds)
#'
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   get_calendar_overlap(feeds, output = "plot")
#' }
#'
#' @export
get_calendar_overlap <- function(gtfs, output = "df") {
  checkmate::assert(
    checkmate::check_character(gtfs, min.len = 1, any.missing = FALSE),
    checkmate::check_list(gtfs, types = "gtfs", min.len = 1),
    .var.name = "gtfs"
  )
  checkmate::assert_string(output)
  checkmate::assert_names(output, subset.of = c("df", "plot"))

  if (output == "plot" && !requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort(
      "The {.pkg ggplot2} package is required when {.code output = \"plot\"}.",
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

  active_days <- lapply(feeds, get_service_period)
  names(active_days) <- feed_names

  no_service <- feed_names[lengths(active_days) == 0L]
  if (length(no_service) > 0L) {
    cli::cli_warn(
      "Feed{?s} {.val {no_service}} ha{?s/ve} no service days.",
      class = "gtfstools_no_service_days"
    )
  }

  # days are intersected as integers, which is much faster than as dates

  overlap_days <- as.Date(
    Reduce(intersect, lapply(active_days, as.integer)),
    origin = "1970-01-01"
  )
  overlap <- dates_to_periods(overlap_days)

  if (output == "df") return(overlap)

  feed_periods <- data.table::rbindlist(
    lapply(active_days, dates_to_periods),
    idcol = "feed"
  )

  # the first feed is plotted at the top. tiles span from the first day of a
  # period to the end of its last day, so that one-day periods are visible.
  # colours are okabe-ito orange (overlap) and blue (feeds)

  timeline_plot <- ggplot2::ggplot() +
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
    ggplot2::labs(
      x = "Date",
      y = NULL,
      subtitle = "Shaded: days on which all feeds have service"
    ) +
    ggplot2::theme_minimal()

  return(timeline_plot)
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
  weekday_cols <- c(
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday"
  )

  # services not used by any trip don't run (checked only if 'trips' has a
  # 'service_id' field). an empty 'trips' table therefore leaves no service days

  used_services <- NULL
  if (gtfsio::check_field_exists(gtfs, "trips", "service_id")) {
    gtfsio::assert_field_class(gtfs, "trips", "service_id", "character")
    used_services <- unique(gtfs$trips$service_id)
  }
  is_used <- function(service_id) {
    is.null(used_services) | service_id %chin% used_services
  }

  active_days <- integer(0)
  added_days <- integer(0)
  exceptions <- NULL

  if (gtfsio::check_file_exists(gtfs, "calendar_dates")) {
    gtfsio::assert_field_class(
      gtfs,
      "calendar_dates",
      c("service_id", "date", "exception_type"),
      c("character", "Date", "integer")
    )

    exceptions <- gtfs$calendar_dates[
      is_used(service_id),
      .(service_id, date = as.integer(date), exception_type)
    ]
    added_days <- exceptions[exception_type == 1L]$date
  }

  # one row per service and weekday on which it runs, with the first and last
  # days of its calendar entry as integers (entries with missing or inverted
  # dates are dropped)

  service_weekdays <- data.table::data.table(
    service_id = character(0),
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

    service_weekdays <- data.table::melt(
      gtfs$calendar[
        is_used(service_id),
        c("service_id", weekday_cols, "start_date", "end_date"),
        with = FALSE
      ],
      measure.vars = weekday_cols,
      variable.name = "weekday",
      value.name = "runs"
    )
    service_weekdays <- service_weekdays[
      runs %in% 1L & start_date <= end_date,
      .(
        service_id,
        weekday = as.integer(weekday),
        first_day = as.integer(start_date),
        last_day = as.integer(end_date)
      )
    ]
  }

  if (nrow(service_weekdays) > 0L) {

    # overlapping entries of the same weekday are merged before being expanded
    # into days, so that the number of days listed is bounded by the span of
    # the feed rather than by its number of services (calendars ending in e.g.
    # 2099 would otherwise create millions of rows)

    data.table::setorder(service_weekdays, weekday, first_day)
    service_weekdays[
      ,
      period := cumsum(
        first_day > data.table::shift(
          cummax(last_day),
          fill = -.Machine$integer.max
        )
      ),
      by = weekday
    ]
    periods <- service_weekdays[
      ,
      .(first_day = min(first_day), last_day = max(last_day)),
      by = .(weekday, period)
    ]

    # each period is expanded into its days of the given weekday only, starting
    # from the first of them. 1970-01-01 was a thursday, so (day + 3) %% 7 is 0
    # on mondays, which gives the weekday of a day (1 is monday) regardless of
    # the locale

    first_weekday <- (periods$first_day + 3L) %% 7L + 1L
    first_match <- periods$first_day + (periods$weekday - first_weekday) %% 7L
    n_matches <- (periods$last_day - first_match) %/% 7L + 1L
    period_idx <- rep(seq_len(nrow(periods)), n_matches)
    active_days <- first_match[period_idx] + 7L * (sequence(n_matches) - 1L)
  }

  # exceptions apply per service: a day is only emptied if every calendar entry
  # that runs on it belongs to a service removed from it. so, for each removal
  # day, two counts of entries are compared (duplicated entries count on both
  # sides):
  # - n_running: the entries that run on the day, from a running sum of +1 at
  #   each first day and -1 after each last day. listing the days of every
  #   entry instead could create millions of rows
  # - n_removed: the entries of the services removed from the day

  if (nrow(service_weekdays) > 0L && !is.null(exceptions)) {
    removals <- unique(
      exceptions[
        exception_type == 2L,
        .(service_id, date, weekday = (date + 3L) %% 7L + 1L)
      ]
    )

    changes <- data.table::rbindlist(
      list(
        service_weekdays[, .(weekday, day = first_day, change = 1L)],
        service_weekdays[, .(weekday, day = last_day + 1L, change = -1L)]
      )
    )
    changes <- changes[, .(change = sum(change)), keyby = .(weekday, day)]
    changes[, n_running := cumsum(change), by = weekday]

    # the count on each removal day is the one after the last change on or
    # before it

    running_counts <- changes[
      unique(removals[, .(weekday, date)]),
      on = .(weekday, day = date),
      roll = TRUE,
      .(date = i.date, n_running = x.n_running)
    ]

    removed_counts <- service_weekdays[
      removals,
      on = .(service_id, weekday, first_day <= date, last_day >= date),
      nomatch = NULL,
      .(date = i.date)
    ]
    removed_counts <- removed_counts[, .(n_removed = .N), by = date]

    day_counts <- running_counts[
      removed_counts,
      on = "date",
      nomatch = NULL
    ]
    emptied_days <- day_counts[n_running == n_removed]$date
    active_days <- setdiff(active_days, emptied_days)
  }

  # sort() also drops the days added by calendar_dates entries without a date

  active_days <- union(active_days, added_days)
  active_days <- as.Date(sort(active_days), origin = "1970-01-01")

  return(active_days)
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
