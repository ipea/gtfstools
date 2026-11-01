#' Fix times after midnight written as early morning times
#'
#' Rewrites the times after midnight of trips that run past it, when they are
#' written as early morning times (e.g. `"00:10:00"` after `"23:50:00"`), as
#' times past `"24:00:00"` (e.g. `"24:10:00"`), as required by the GTFS
#' specification. All gtfstools functions that calculate or edit durations
#' and speeds or use information on time of day use `fix_overnight_times()`
#' internally to fix the overnight times.
#'
#' @template gtfs
#'
#' @return A GTFS object with the time columns of its `stop_times` and the
#'   `end_time` column of its `frequencies` fixed.
#'
#' @section Details:
#' The arrival and departure times of each trip are read in order of
#' `stop_sequence`, ignoring blank times. A time more than 12 hours earlier
#' than the previous time of its trip is taken as a time after midnight, so
#' it and the later times of the trip are moved one day later (e.g.
#' `"00:10:00"` becomes `"24:10:00"`). Trips that run past a second midnight
#' are moved two days, and so on. A time more than 12 hours later than the
#' previous time of its trip undoes one of these days, so feeds that mix both
#' forms are also fixed (e.g. `"24:30:00"`, `"00:40:00"`, `"24:50:00"`
#' becomes `"24:30:00"`, `"24:40:00"`, `"24:50:00"`), and trips whose times
#' already follow the specification are left unchanged. Blank times are kept
#' blank. Only `stop_times` and `frequencies` are modified; their existing
#' `_secs` columns are updated to match.
#'
#' Times earlier than the previous time of their trip by 12 hours or less are
#' left unchanged, with a warning. Times are never moved earlier, so trips
#' with known times more than 12 hours apart that follow the specification
#' (e.g. `"06:00:00"`, `"19:30:00"`) are left unchanged. Rows with a missing
#' `trip_id` or `stop_sequence` are left unchanged, and stops with duplicated
#' `stop_sequence`s are read in the order of their rows (see
#' [remove_duplicates()]).
#'
#' Trips whose times are all written after midnight as early morning times
#' (e.g. a trip of the previous service day departing at `"00:30:00"`) can't
#' be told apart from trips of the service day and are left unchanged.
#'
#' In `frequencies`, an `end_time` earlier than the `start_time` of its row
#' is moved by whole days to the first time later than the `start_time`
#' (e.g. `"23:00:00"`-`"01:00:00"` becomes `"23:00:00"`-`"25:00:00"`). A
#' `start_time` written as an early morning time is left unchanged. The
#' template times of trips listed in `frequencies` are fixed as any other
#' times, which doesn't change their departures, since only the differences
#' between them are used.
#'
#' An error is raised if a fixed time would be later than `"9999:59:59"`.
#'
#'
#' @seealso [fix_gtfs()], [convert_time_to_seconds()]
#'
#' @examplesIf requireNamespace("dplyr", quietly = TRUE)
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#' }
#' library(dplyr)
#'
#' data_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
#'
#' gtfs <- read_gtfs(data_path)
#'
#' # this trip runs past midnight, but its last time is written as "00:02:00"
#' gtfs$stop_times |>
#'   filter(trip_id == "T2-1@1#2310", arrival_time != "") |>
#'   select(trip_id, stop_sequence, arrival_time, departure_time)
#'
#' fixed_gtfs <- fix_overnight_times(gtfs)
#'
#' fixed_gtfs$stop_times |>
#'   filter(trip_id == "T2-1@1#2310", arrival_time != "") |>
#'   select(trip_id, stop_sequence, arrival_time, departure_time)
#' \dontshow{data.table::setDTthreads(old_dt_threads)}
#'
#' @export
fix_overnight_times <- function(gtfs) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "stop_sequence", "arrival_time", "departure_time"),
    c("character", "integer", "character", "character")
  )

  if (gtfsio::check_file_exists(gtfs, "frequencies")) {
    gtfsio::assert_field_class(
      gtfs,
      "frequencies",
      c("start_time", "end_time"),
      c("character", "character")
    )
  }

  gtfs <- fix_overnight_stop_times(gtfs)
  gtfs <- fix_overnight_frequencies(gtfs)

  return(gtfs)
}


#' Fix the times after midnight of `stop_times`
#'
#' Also used by the functions that calculate speeds and durations, which fix
#' the times silently before using them.
#'
#' @param gtfs A GTFS object whose `stop_times` has the `trip_id`,
#'   `stop_sequence`, `arrival_time` and `departure_time` fields, of the
#'   classes asserted by [fix_overnight_times()].
#' @param trip_id A character vector with the `trip_id`s to fix, or `NULL`
#'   (the default) for every trip. Each trip is fixed on its own, so the
#'   functions that only use some trips fix only these.
#' @param warn Whether to warn about the times that still go back after the
#'   fix, and about malformed times.
#' @param by_reference Whether to write the fixed times into
#'   `gtfs$stop_times` itself. If `FALSE`, the table is copied before being
#'   changed.
#' @param detect_only Whether to only detect the times to fix, without fixing
#'   them.
#'
#' @return The GTFS object, or, with `detect_only = TRUE`, `TRUE` if any time
#'   would be fixed and `FALSE` otherwise.
#'
#' @keywords internal
fix_overnight_stop_times <- function(
  gtfs,
  trip_id = NULL,
  warn = TRUE,
  by_reference = FALSE,
  detect_only = FALSE
) {
  stop_times <- gtfs$stop_times

  # rows with a missing trip_id or stop_sequence can't be placed in a trip,
  # so they are left alone

  is_candidate <- !is.na(stop_times$trip_id) & !is.na(stop_times$stop_sequence)
  if (!is.null(trip_id)) {
    is_candidate <- is_candidate & stop_times$trip_id %chin% trip_id
  }

  # the rows are sorted so that the rows of each trip are contiguous. the
  # trips are sorted by their order of appearance, not by their ids, because
  # the radix sort of order() fails on ids in a native encoding with
  # non-ASCII characters (e.g. on Windows)

  rows <- which(is_candidate)
  candidate_trips <- stop_times$trip_id[rows]
  trip_number <- data.table::chmatch(candidate_trips, unique(candidate_trips))
  ord <- order(trip_number, stop_times$stop_sequence[rows], method = "radix")
  rows <- rows[ord]
  trip_number <- trip_number[ord]

  # the arrival and departure times of each stop are read in turn, so a wrap
  # between them is found too. blank times are skipped

  # only the selected rows are converted, from the existing *_secs columns
  # (as in time_secs()) or from the time strings. malformed times are
  # reported by the functions that call this one silently, so they are not
  # reported twice

  rows_secs <- function(time_col) {
    secs_col <- paste0(time_col, "_secs")
    if (secs_col %chin% names(stop_times)) {
      return(stop_times[[secs_col]][rows])
    }
    return(string_to_seconds(stop_times[[time_col]][rows]))
  }

  n_rows <- length(rows)
  secs <- withCallingHandlers(
    as.numeric(rbind(rows_secs("arrival_time"), rows_secs("departure_time"))),
    gtfstools_malformed_time = function(cnd) {
      if (!warn) invokeRestart("muffleWarning")
    }
  )
  row <- rep(rows, each = 2L)
  is_arrival <- rep(c(TRUE, FALSE), times = n_rows)

  # trips are told apart by the numbers they were sorted by, which is cheaper
  # than comparing their ids on the interleaved times

  trip_run <- rep(trip_number, each = 2L)

  is_known <- !is.na(secs)
  secs <- secs[is_known]
  row <- row[is_known]
  is_arrival <- is_arrival[is_known]
  trip_run <- trip_run[is_known]

  n <- length(secs)
  if (n == 0) {
    return(if (detect_only) FALSE else gtfs)
  }

  is_first <- c(TRUE, trip_run[-1L] != trip_run[-n])
  trip_idx <- cumsum(is_first)

  # a step back of more than 12 hours between consecutive times of a trip
  # crosses midnight, so the times after it are one day later than written.
  # a step forward of more than 12 hours undoes one of these days, so feeds
  # that mix "24:xx" and "00:xx" times are fixed too. round() rounds a step of
  # exactly 12 hours to 0

  step <- c(0, diff(secs))
  step[is_first] <- 0
  days <- cumsum(-round(step / 86400))

  # the days are counted from the start of each trip, and kept from going
  # below 0 by subtracting their running minimum within the trip, so times are
  # never moved earlier and long trips that follow the spec (e.g. "06:00:00",
  # "19:30:00") are left unchanged. each trip is shifted below all the
  # previous ones, so a single cummin() restarts at the start of each trip

  days <- days - days[is_first][trip_idx]
  trip_shift <- trip_idx * (2 * max(abs(days)) + 1)
  days <- days - (cummin(days - trip_shift) + trip_shift)
  fixed <- secs + days * 86400

  # steps that still go back are left as they are, with a warning

  is_backwards <- !is_first & c(0, diff(fixed)) < 0

  if (warn && any(is_backwards)) {
    backwards_trips <- unique(stop_times$trip_id[row[is_backwards]])
    abbreviated <- abbreviate_ids(backwards_trips)
    cli::cli_warn(
      c(
        paste0(
          "{length(backwards_trips)} trip{?s} {?has/have} times earlier ",
          "than the previous time of the trip, which {?was/were} not fixed: ",
          "{.val {abbreviated$shown}}{abbreviated$more}."
        ),
        "i" = paste0(
          "Only times that go back by more than 12 hours are taken as times ",
          "after midnight."
        )
      ),
      class = "gtfstools_backwards_times"
    )
  }

  is_changed <- days > 0
  if (detect_only) {
    return(any(is_changed))
  }
  if (!any(is_changed)) {
    return(gtfs)
  }

  # seconds_to_string() can't write times later than 9999:59:59

  is_invalid <- is_changed & fixed > max_time_secs

  if (any(is_invalid)) {
    invalid_trips <- unique(stop_times$trip_id[row[is_invalid]])
    abbreviated <- abbreviate_ids(invalid_trips)
    cli::cli_abort(
      paste0(
        "Fixing the times after midnight results in times later than ",
        "{.val 9999:59:59} in the following ",
        "{cli::qty(length(invalid_trips))}trip{?s}: ",
        "{.val {abbreviated$shown}}{abbreviated$more}."
      ),
      class = "gtfstools_time_out_of_range"
    )
  }

  if (!by_reference) {
    stop_times <- data.table::copy(stop_times)
  }

  is_arr_changed <- is_changed & is_arrival
  data.table::set(
    stop_times,
    i = row[is_arr_changed],
    j = "arrival_time",
    value = seconds_to_string(as.integer(fixed[is_arr_changed]))
  )

  is_dep_changed <- is_changed & !is_arrival
  data.table::set(
    stop_times,
    i = row[is_dep_changed],
    j = "departure_time",
    value = seconds_to_string(as.integer(fixed[is_dep_changed]))
  )

  # refresh pre-existing *_secs columns, which other functions use as-is

  refresh_secs_columns(
    stop_times,
    c("arrival_time", "departure_time"),
    unique(row[is_changed])
  )

  gtfs$stop_times <- stop_times
  return(gtfs)
}


#' Fix the end times after midnight of `frequencies`
#'
#' @param gtfs A GTFS object, whose `frequencies` is copied before being
#'   changed.
#'
#' @return The GTFS object.
#'
#' @keywords internal
fix_overnight_frequencies <- function(gtfs) {
  frequencies <- gtfs$frequencies
  if (is.null(frequencies)) {
    return(gtfs)
  }

  start <- time_secs(frequencies, "start_time")
  end <- time_secs(frequencies, "end_time")
  wrapped <- which(end < start)

  if (length(wrapped) == 0) {
    return(gtfs)
  }

  fixed <- end[wrapped] +
    86400 * (floor((start[wrapped] - end[wrapped]) / 86400) + 1)

  if (any(fixed > max_time_secs)) {
    cli::cli_abort(
      paste0(
        "Fixing the times after midnight results in times later than ",
        "{.val 9999:59:59} in {.field frequencies}."
      ),
      class = "gtfstools_time_out_of_range"
    )
  }

  frequencies <- data.table::copy(frequencies)
  data.table::set(
    frequencies,
    i = wrapped,
    j = "end_time",
    value = seconds_to_string(as.integer(fixed))
  )
  refresh_secs_columns(frequencies, "end_time", wrapped)

  gtfs$frequencies <- frequencies
  return(gtfs)
}


#' Check whether a feed has trips with times after midnight to fix
#'
#' Detects the trips whose times after midnight are written as early morning
#' times (e.g. `"00:30:00"` instead of `"24:30:00"`), as [fix_overnight_times()]
#' does, without fixing them: trips with a time more than 12 hours earlier than
#' the previous time of the trip, and `frequencies` entries whose `end_time` is
#' earlier than their `start_time`. Trips already written with times past
#' `"24:00:00"` don't count. Tables whose fields can't be checked (e.g. a
#' `stop_times` without an integer `stop_sequence`) are skipped.
#'
#' @param gtfs A GTFS object.
#'
#' @return `TRUE` if [fix_overnight_times()] would change any time, `FALSE`
#'   otherwise.
#'
#' @keywords internal
has_overnight_trips <- function(gtfs) {
  is_stop_times_valid <- gtfsio::check_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "stop_sequence", "arrival_time", "departure_time"),
    c("character", "integer", "character", "character")
  )
  # the check is silent: malformed times are reported by the functions that
  # use the times

  if (isTRUE(is_stop_times_valid)) {
    has_wrapped_times <- fix_overnight_stop_times(
      gtfs,
      warn = FALSE,
      detect_only = TRUE
    )
    if (has_wrapped_times) return(TRUE)
  }

  is_frequencies_valid <- gtfsio::check_field_class(
    gtfs,
    "frequencies",
    c("start_time", "end_time"),
    c("character", "character")
  )
  if (isTRUE(is_frequencies_valid)) {
    is_wrapped <- withCallingHandlers(
      time_secs(gtfs$frequencies, "end_time") <
        time_secs(gtfs$frequencies, "start_time"),
      gtfstools_malformed_time = function(cnd) invokeRestart("muffleWarning")
    )
    return(any(is_wrapped, na.rm = TRUE))
  }

  return(FALSE)
}


#' Fix the times after midnight silently
#'
#' Fixes the times after midnight of `stop_times` (and of `frequencies`)
#' silently, as the functions that use the times do before using them. A
#' feed whose times were already fixed is returned unchanged, without being
#' copied, so a function called by another one doesn't fix them again.
#'
#' @param gtfs A GTFS object.
#' @param trip_id A character vector with the `trip_id`s to fix, or `NULL`
#'   for every trip.
#' @param frequencies Whether to fix the `end_time`s of `frequencies` too.
#' @param by_reference Whether to write the fixed times into
#'   `gtfs$stop_times` itself.
#'
#' @return The GTFS object.
#'
#' @keywords internal
fix_overnight_in_call <- function(
  gtfs,
  trip_id = NULL,
  frequencies = FALSE,
  by_reference = FALSE
) {
  # tables whose fields can't be fixed are left as they are, and the callers'
  # own assertions report them

  is_stop_times_valid <- gtfsio::check_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "stop_sequence", "arrival_time", "departure_time"),
    c("character", "integer", "character", "character")
  )
  if (isTRUE(is_stop_times_valid)) {
    gtfs <- fix_overnight_stop_times(
      gtfs,
      trip_id,
      warn = FALSE,
      by_reference = by_reference
    )
  }

  if (frequencies) {
    is_frequencies_valid <- gtfsio::check_field_class(
      gtfs,
      "frequencies",
      c("start_time", "end_time"),
      c("character", "character")
    )
    if (isTRUE(is_frequencies_valid)) {
      gtfs <- fix_overnight_frequencies(gtfs)
    }
  }

  return(gtfs)
}
