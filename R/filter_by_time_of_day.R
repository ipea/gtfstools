#' Filter GTFS object by time of day
#'
#' Filters a GTFS object by time of day, keeping (or dropping) the
#' `stop_times` and `frequencies` entries within it, and keeping the entries
#' of the other tables related to the trips that remain.
#'
#' @template gtfs
#' @param from A string. The starting point of the time of day, in the
#' "HH:MM:SS" format.
#' @param to A string. The ending point of the time of day, in the "HH:MM:SS"
#' format.
#' @param keep A logical. Whether the entries related to the specified time of
#' day should be kept or dropped (defaults to `TRUE`, which keeps the entries).
#' @param full_trips A logical. Whether trips should be treated as immutable
#' blocks or each of its stops should be considered separately when filtering
#' the `stop_times` table (defaults to `FALSE`, which considers each stop
#' individually). Please check the details section for more information on how
#' this parameter changes the function behaviour.
#' @param update_frequencies A logical. Whether the `frequencies` table should
#' have its `start_time` and `end_time` fields updated to fit inside/outside the
#' specified time of day (defaults to `TRUE`, which updates the fields).
#'
#' @return The GTFS object passed to the `gtfs` parameter, after the filtering
#' process.
#'
#' @section Details:
#' The time of day includes both `from` and `to`.
#'
#' Times after midnight written as early morning times (e.g. `"00:30:00"`
#' instead of `"24:30:00"`), and `end_time`s earlier than `start_time`s in
#' `frequencies`, are first fixed with [fix_overnight_times()], so these
#' times are compared with the time of day as they should be, and the
#' returned GTFS has them fixed.
#'
#' Trips listed in `frequencies` are filtered through their `frequencies`
#' entries; their `stop_times` entries are templates and are kept whatever
#' their times. With `keep = TRUE`, the entries that overlap the time of day
#' are kept; with `keep = FALSE`, those entirely within it are dropped. With
#' `update_frequencies = TRUE` and `keep = TRUE`, an entry that starts before
#' `from` starts at `from` (or, if `exact_times` is 1, at its first departure
#' at or after `from`), and an entry that ends after `to` ends one second
#' after `to`, so that a departure exactly at `to` is kept. With
#' `update_frequencies = TRUE` and `keep = FALSE`, an entry that crosses
#' `from` ends at `from`, an entry that crosses `to` starts one second after
#' `to` (or, if `exact_times` is 1, at its first departure after `to`), and an
#' entry that spans the whole time of day is split in two. Entries left
#' without any departure are removed, and trips left without any entry are
#' dropped from the feed.
#'
#' The other trips are filtered through their `stop_times` entries, which are
#' within the time of day when the visit, from `arrival_time` to
#' `departure_time`, overlaps it (a blank time is ignored when the other is
#' known). With `full_trips = FALSE`, each entry is kept or dropped on its own,
#' and entries with both times blank (or, with `keep = FALSE`, either) are
#' dropped. With `full_trips = TRUE`, a trip with any entry within the time of
#' day is kept (`keep = TRUE`) or dropped (`keep = FALSE`) as a whole,
#' including its blank entries. The other tables are then filtered to the
#' trips left in `stop_times`, as in [filter_by_trip_id()], with a warning if
#' `stop_times` lists trips missing from `trips`.
#'
#' Existing `_secs` columns in `stop_times` and `frequencies` (e.g. created
#' with [convert_time_to_seconds()]) are used as-is, not recalculated from the
#' time strings.
#'
#' @family filtering functions
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # taking a look at the original frequencies and stop_times
#' head(gtfs$frequencies)
#' head(gtfs$stop_times)
#'
#' smaller_gtfs <- filter_by_time_of_day(gtfs, "05:00:00", "06:00:00")
#'
#' # filter_by_time_of_day filters the frequencies table but doesn't filter the
#' # stop_times table because they're just templates
#' head(smaller_gtfs$frequencies)
#' head(smaller_gtfs$stop_times)
#'
#' # frequencies entries are adjusted by default. use update_frequencies =
#' # FALSE to keep their original times
#' smaller_gtfs <- filter_by_time_of_day(
#'   gtfs,
#'   "05:30:00",
#'   "06:00:00",
#'   update_frequencies = FALSE
#' )
#' head(smaller_gtfs$frequencies)
#'
#' # when keep = FALSE, the behaviour of the function in general, and of
#' # update_frequencies in particular, is a bit different
#' smaller_gtfs <- filter_by_time_of_day(
#'   gtfs,
#'   "05:30:00",
#'   "06:00:00",
#'   keep = FALSE,
#'   update_frequencies = TRUE
#' )
#' head(smaller_gtfs$frequencies)
#'
#' # let's remove the frequencies table to check the behaviour of full_trips
#' gtfs$frequencies <- NULL
#' smaller_gtfs <- filter_by_time_of_day(
#'   gtfs,
#'   "05:30:00",
#'   "06:00:00"
#' )
#' head(smaller_gtfs$stop_times)
#'
#' smaller_gtfs <- filter_by_time_of_day(
#'   gtfs,
#'   "05:30:00",
#'   "06:00:00",
#'   full_trips = TRUE
#' )
#' head(smaller_gtfs$stop_times)
#' @export
filter_by_time_of_day <- function(gtfs,
                                  from,
                                  to,
                                  keep = TRUE,
                                  full_trips = FALSE,
                                  update_frequencies = TRUE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_string(from, pattern = time_pattern)
  checkmate::assert_string(to, pattern = time_pattern)
  checkmate::assert_logical(keep, len = 1, any.missing = FALSE)
  checkmate::assert_logical(full_trips, len = 1, any.missing = FALSE)
  checkmate::assert_logical(update_frequencies, len = 1, any.missing = FALSE)

  from_secs <- string_to_seconds(from)
  to_secs <- string_to_seconds(to)
  if (from_secs > to_secs) stop("'from' must be lower than 'to'.")

  # times after midnight written as early morning times are fixed first, so
  # they are compared with the time of day as they should be. the returned
  # feed keeps them fixed

  gtfs <- fix_overnight_in_call(gtfs, frequencies = TRUE)

  # if the gtfs contains a frequencies table, it's important to keep the
  # stop_times of the trips listed in there intact.
  # this is because their stop_times are only templates, and the departure and
  # arrival times listed there should not be considered as is when filtering.
  # in such case, we remove the frequencies' entries that fall outside the
  # specified period and conditionally update the entries that were kept

  frequency_trips <- character()
  lost_frequency_trips <- character()
  if (gtfsio::check_file_exists(gtfs, "frequencies")) {
    gtfsio::assert_field_class(
      gtfs,
      "frequencies",
      c("trip_id", "start_time", "end_time"),
      rep("character", 3)
    )

    original_frequency_trips <- unique(gtfs$frequencies$trip_id)

    gtfs$frequencies <- filter_frequencies(
      gtfs,
      from_secs,
      to_secs,
      keep,
      update_frequencies
    )

    frequency_trips <- unique(gtfs$frequencies$trip_id)
    lost_frequency_trips <- setdiff(original_frequency_trips, frequency_trips)
  }

  # filter the stop_times table and then filter the rest of the gtfs based on
  # the trips listed there. stop_times may describe some trips not listed in the
  # trips table, so we check for this and raise a warning if any trip is found

  gtfs$stop_times <- filter_stop_times(
    gtfs,
    from_secs,
    to_secs,
    keep,
    full_trips,
    frequency_trips
  )

  # frequency-based trips whose frequencies entries were all filtered out must
  # not be judged by their template times, so they are dropped altogether. the
  # selection is created outside of `[` for consistency with the helpers above
  # (this table is already the function's own)

  is_lost_trip <- gtfs$stop_times$trip_id %chin% lost_frequency_trips
  gtfs$stop_times <- gtfs$stop_times[which(!is_lost_trip)]

  relevant_trips <- unique(gtfs$stop_times$trip_id)
  invalid_trip_id <- relevant_trips[
    ! relevant_trips %chin% unique(gtfs$trips$trip_id)
  ]

  if (!identical(invalid_trip_id, character(0))) {
    warning(
      "'stop_times' describes trip_ids not listed in 'trips': ",
      paste0("'", invalid_trip_id, "'", collapse = ", "),
      call. = FALSE
    )
  }

  gtfs <- filter_by_trip_id(gtfs, relevant_trips)

  return(gtfs)
}


#' @keywords internal
filter_frequencies <- function(gtfs,
                               from_secs,
                               to_secs,
                               keep,
                               update_frequencies) {
  # the table is small, so it's copied: the columns added below never touch
  # the given table. the time-in-seconds columns are created only if they
  # didn't exist before, and are removed again at the end in that case

  frequencies <- data.table::copy(gtfs$frequencies)

  has_start_secs <- "start_time_secs" %chin% names(frequencies)
  has_end_secs <- "end_time_secs" %chin% names(frequencies)
  if (!has_start_secs) {
    frequencies[, start_time_secs := string_to_seconds(start_time)]
  }
  if (!has_end_secs) {
    frequencies[, end_time_secs := string_to_seconds(end_time)]
  }

  # how we filter the frequencies table depend on the 'keep' argument.
  # if we are keeping, we want to keep entries that either one of 'from' or
  # 'to' fall between start_time and end_time and the entries in which both
  # start_time and end_time are between 'from' and 'to'.
  # if we are dropping, we also want to keep the entries that either one of
  # 'from'/'to' fall between start_time and end_time (because there may be
  # trips that happen either between from and start_time or between to and
  # end_time), but want to drop the entries in which both start_time and
  # end_time are between 'from' and 'to'

  frequencies[
    ,
    `:=`(
      from_within = from_secs > start_time_secs & from_secs < end_time_secs,
      to_within = to_secs >= start_time_secs & to_secs < end_time_secs,
      within_from_to = start_time_secs >= from_secs & end_time_secs <= to_secs
    )
  ]

  if (keep) {
    filtered_frequencies <- frequencies[
      from_within == TRUE | to_within == TRUE | within_from_to == TRUE
    ]
  } else {
    filtered_frequencies <- frequencies[
      from_within == TRUE | to_within == TRUE | within_from_to == FALSE
    ]
  }

  # update the start and end time in the frequencies table if update_frequencies
  # is TRUE

  if (update_frequencies) {
    filtered_frequencies <- update_frequencies_times(
      filtered_frequencies,
      from_secs,
      to_secs,
      keep
    )
  }

  # remove the time-in-seconds columns that didn't exist before, and the
  # auxiliary columns

  if (!has_start_secs) filtered_frequencies[, start_time_secs := NULL]
  if (!has_end_secs) filtered_frequencies[, end_time_secs := NULL]

  filtered_frequencies[
    ,
    c("from_within", "to_within", "within_from_to") := NULL
  ]

  return(filtered_frequencies)
}


#' @keywords internal
update_frequencies_times <- function(filtered_frequencies,
                                     from_secs,
                                     to_secs,
                                     keep) {
  # how frequencies times should be updated depends if:
  # - exact_times is 0 or 1. if it's 0, just update start and end time to the
  # corresponding to/from. if it's 1, we need to adhere to the headway. if
  # exact_times doesn't exist, the behaviour is like when it's 0
  # - keep is TRUE or FALSE. this changes whether start/end time relates to
  # to/from.

  # the time columns in seconds are updated along with the time strings, so
  # that entries left without any departure can be removed at the end

  if (is.null(filtered_frequencies$exact_times)) {
    if (keep) {
      filtered_frequencies[from_within == TRUE, start_time_secs := from_secs]
      filtered_frequencies[
        from_within == TRUE,
        start_time := seconds_to_string(start_time_secs)
      ]
      # end_time is exclusive, so it's set to one second after 'to' to keep the
      # departure at 'to', if there is one

      filtered_frequencies[to_within == TRUE, end_time_secs := to_secs + 1L]
      filtered_frequencies[
        to_within == TRUE,
        end_time := seconds_to_string(end_time_secs)
      ]
    } else {
      # when keep = FALSE, there may be cases in which the the time of day to
      # filter is between start and end time, so we want to preserve the
      # intervals between start time and from, and between end time and to. to
      # do so, we need to identify these rows, duplicate them, and then edit
      # one by one
      filtered_frequencies <- rbind(
        filtered_frequencies,
        filtered_frequencies[to_within == TRUE & from_within == TRUE]
      )
      cols <- names(filtered_frequencies)
      filtered_frequencies[, is_duplicated := .N > 1, by = cols]

      filtered_frequencies[
        filtered_frequencies[is_duplicated == TRUE, .I[1], by = cols]$V1,
        `:=`(
          to_within = FALSE,
          is_duplicated = FALSE
        )
      ]
      filtered_frequencies[
        is_duplicated == TRUE,
        `:=`(
          from_within = FALSE,
          is_duplicated = FALSE
        )
      ]
      filtered_frequencies[, is_duplicated := NULL]

      # the rest of the filtering is pretty standard but "inverted" when
      # compared to keep = TRUE. the time of day includes 'to', so the
      # remaining entries start one second after it

      filtered_frequencies[from_within == TRUE, end_time_secs := from_secs]
      filtered_frequencies[
        from_within == TRUE,
        end_time := seconds_to_string(end_time_secs)
      ]
      filtered_frequencies[to_within == TRUE, start_time_secs := to_secs + 1L]
      filtered_frequencies[
        to_within == TRUE,
        start_time := seconds_to_string(start_time_secs)
      ]
    }
  } else {
    if (keep) {
      # if exact_times is 0, the behaviour is like when exact_times doesn't
      # exist. if it's 1, the start_time should respect the headway. we can just
      # set end_time to one second after to_secs (end_time is exclusive, so this
      # keeps the departure at 'to', if there is one) because what matters is
      # the time the trips start, but not when the frequency period finishes

      filtered_frequencies[to_within == TRUE, end_time_secs := to_secs + 1L]
      filtered_frequencies[
        to_within == TRUE,
        end_time := seconds_to_string(end_time_secs)
      ]

      filtered_frequencies[
        from_within == TRUE & !exact_times %in% 1L,
        start_time_secs := from_secs
      ]
      filtered_frequencies[
        from_within == TRUE & exact_times %in% 1L,
        start_time_secs := start_time_secs +
          ceiling((from_secs - start_time_secs) / headway_secs) * headway_secs
      ]
      filtered_frequencies[
        from_within == TRUE,
        start_time := seconds_to_string(start_time_secs)
      ]

      # the start_time adjusted to the headway may fall after 'to', in which
      # case no departure happens within the time of day. this must be checked
      # against 'to' because end_time is now one second after it

      filtered_frequencies <- filtered_frequencies[
        !(to_within == TRUE & start_time_secs > to_secs)
      ]
    } else {
      # we follow the same procedure to update the times when both from and to
      # fall within start and end_times that was followed when exact_times
      # didn't exist. except that now we also have to pay attention to the
      # headway when updating the start_time when exact_times = 1
      filtered_frequencies <- rbind(
        filtered_frequencies,
        filtered_frequencies[to_within == TRUE & from_within == TRUE]
      )
      cols <- names(filtered_frequencies)
      filtered_frequencies[, is_duplicated := .N > 1, by = cols]

      filtered_frequencies[
        filtered_frequencies[is_duplicated == TRUE, .I[1], by = cols]$V1,
        `:=`(
          to_within = FALSE,
          is_duplicated = FALSE
        )
      ]
      filtered_frequencies[
        is_duplicated == TRUE,
        `:=`(
          from_within = FALSE,
          is_duplicated = FALSE
        )
      ]
      filtered_frequencies[, is_duplicated := NULL]

      filtered_frequencies[from_within == TRUE, end_time_secs := from_secs]
      filtered_frequencies[
        from_within == TRUE,
        end_time := seconds_to_string(end_time_secs)
      ]

      # the time of day includes 'to', so the remaining entries start one
      # second after it or, with exact times, at the first departure after it

      filtered_frequencies[
        to_within == TRUE & !exact_times %in% 1L,
        start_time_secs := to_secs + 1L
      ]
      filtered_frequencies[
        to_within == TRUE & exact_times %in% 1L,
        start_time_secs := start_time_secs +
          (floor((to_secs - start_time_secs) / headway_secs) + 1) *
            headway_secs
      ]
      filtered_frequencies[
        to_within == TRUE,
        start_time := seconds_to_string(start_time_secs)
      ]
    }
  }

  # updating the start_time may yield start_times higher than the end_times,
  # or equal to them, in which case no departure is left. we remove these
  # entries. entries not updated whose start_time equals their end_time are
  # kept, since they describe a single departure

  filtered_frequencies <- filtered_frequencies[
    !(
      start_time_secs > end_time_secs |
        ((from_within | to_within) & start_time_secs == end_time_secs)
    )
  ]

  return(filtered_frequencies)
}


#' @keywords internal
filter_stop_times <- function(gtfs,
                              from_secs,
                              to_secs,
                              keep,
                              full_trips,
                              frequency_trips) {
  # the times in seconds (from the existing '_secs' columns, if any) and the
  # selections are local vectors, so the given table is never modified and
  # {data.table} doesn't add an index to it. which() is used on every
  # selection, so that a one-row table never yields a subset that shares its
  # columns

  stop_times <- gtfs$stop_times
  dep_secs <- time_secs(stop_times, "departure_time")
  arr_secs <- time_secs(stop_times, "arrival_time")

  # when filtering the stop_times table, we have to pay attention to the
  # full_trips and keep parameters. if both are TRUE, then we keep the trips
  # that have any of their stops visited inside the specified time of day. if
  # full_trips is TRUE and keep is FALSE, we drop the trips that have any of
  # their stops visited inside the time interval, and if full_trips is FALSE, we
  # keep/drop only the stops that fall outside the time interval. the
  # frequency-based trips are always kept

  is_frequency_trip <- stop_times$trip_id %chin% frequency_trips
  is_within <- (dep_secs >= from_secs | arr_secs >= from_secs) &
    (dep_secs <= to_secs | arr_secs <= to_secs)

  if (keep) {
    filtered_stop_times <- stop_times[which(is_frequency_trip | is_within)]

    if (full_trips) {
      is_kept_trip <- stop_times$trip_id %chin% filtered_stop_times$trip_id
      filtered_stop_times <- stop_times[which(is_kept_trip)]
    }
  } else {
    is_outside <- (dep_secs < from_secs & arr_secs < from_secs) |
      (dep_secs > to_secs & arr_secs > to_secs)
    filtered_stop_times <- stop_times[which(is_frequency_trip | is_outside)]

    if (full_trips) {
      # we drop exactly the trips that keep = TRUE would keep. which() treats
      # NA as FALSE, so untimed entries don't cause their trips to be dropped

      trips_to_drop <- stop_times$trip_id[which(!is_frequency_trip & is_within)]
      is_dropped_trip <- stop_times$trip_id %chin% trips_to_drop
      filtered_stop_times <- stop_times[which(!is_dropped_trip)]
    }
  }

  return(filtered_stop_times)
}
