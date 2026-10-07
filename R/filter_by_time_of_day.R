#' Filter GTFS object by time of day
#'
#' Filters a GTFS object by time of day, keeping (or dropping) the relevant
#' entries in each file. Please see the details section for more information on
#' how this function filters the `frequencies` and `stop_times` tables, as well
#' as how it handles `stop_times` tables that contain trips with some empty
#' departure and arrival times.
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
#' When filtering the `frequencies` table, `filter_by_time_of_day()` respects
#' the `exact_times` field. This field indicates whether the service follows a
#' fixed schedule throughout the day or not. If it's 0 (or if it's not
#' present), the service does not follow a fixed schedule. Instead, the
#' operators try to maintain the listed headways. In such cases, if
#' `update_frequencies` is `TRUE` we just update `start_time` and `end_time` to
#' the appropriate value of `from` or `to` (which of this value is used depends
#' on `keep`). When `keep` is `TRUE`, `end_time` is set to one second after
#' `to`: as required by the GTFS specification, no trip departs at the
#' `end_time` of an entry, so this keeps a departure that happens exactly at
#' `to` (e.g. when converting the filtered feed with
#' [frequencies_to_stop_times()]).
#'
#' If `exact_times` is 1, however, operators try to strictly adhere to the start
#' times and headway. As a result, when updating the `start_time` field we need
#' to follow the listed headway. For example, take a trip that has its start
#' time listed as 06:00:00, its end time listed as 08:00:00 and its headway
#' listed as 300 secs (5 minutes). If you decide to filter the feed to keep the
#' time of day between 06:32:00 and 08:00:00 while updating `frequencies`, the
#' `start_time` field must be updated to 06:35:00 in order to preserve the
#' correct departure times of this trips, instead of simply updating it to
#' 06:32:00.
#'
#' Another things to keep an eye on when filtering the `frequencies` table is
#' that the corresponding `stop_times` entries of trips listed in the
#' `frequencies` table should not be filtered, even if their departure and
#' arrival times fall outside the specified time of day. This is because the
#' `stop_times` entries of `frequencies`' trips are just templates that describe
#' how long a segment between two stops takes, so the departure and arrival
#' times listed there do not actually represent the actual departure and
#' arrival times seen in practice. Taking the same example listed above, the
#' corresponding `stop_times` entries of that trip could describe a departure
#' from the first stop at 12:00:00 and an arrival at the second stop at
#' 12:03:00. That doesn't mean the trip will actually leave and arrive at the
#' stops at these times, but rather that it takes 3 minutes to get from the
#' first to the second stop. So when the trip departs from the first stop at
#' 06:35:00, it will get to the second at 06:38:00.
#'
#' When filtering the `stop_times` table, a few other details should be
#' observed. First, one could wish to filter a GTFS object in order to keep all
#' trips that cross a given time of day, whereas others may want to keep only
#' the specific entries that fall inside the specified time of day. For
#' example, take a trip that leaves the first stop at 06:30:00, gets to the
#' second at 06:35:00 and then gets to the third at 06:45:00. When filtering to
#' keep entire trips that cross the time of day between 06:30:00 and 06:40:00,
#' all three stops will have to be kept. If, however, you want to keep only the
#' entries that fall within the specified time of day, only the first two
#' should be kept. To control such behaviour you need to set the `full_trips`
#' parameter. When it's `TRUE`, the function behaves like the first case, and
#' when it's `FALSE`, like the second.
#'
#' When using `full_trips` in conjunction with `keep`, please note how their
#' behaviour stack. When both are `TRUE`, trips are always fully kept. When
#' `keep` is `FALSE`, however, trips are fully dropped, even if some of their
#' stops are visited outside the specified time of day.
#'
#' Finally, please note that many GTFS feeds may contain `stop_times` entries
#' with empty departure and arrival times. In such cases, filtering by time of
#' day with `full_trips` as `FALSE` will drop the entries with empty times.
#' Please set `full_trips` to `TRUE` to preserve these entries.
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
#' # frequencies entries can be adjusted using update_frequencies = TRUE
#' smaller_gtfs <- filter_by_time_of_day(
#'   gtfs,
#'   "05:30:00",
#'   "06:00:00",
#'   update_frequencies = TRUE
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
  checkmate::assert_string(from, pattern = "^\\d{2}:[0-5]\\d:[0-5]\\d$")
  checkmate::assert_string(to, pattern = "^\\d{2}:[0-5]\\d:[0-5]\\d$")
  checkmate::assert_logical(keep, len = 1, any.missing = FALSE)
  checkmate::assert_logical(full_trips, len = 1, any.missing = FALSE)
  checkmate::assert_logical(update_frequencies, len = 1, any.missing = FALSE)

  from_secs <- string_to_seconds(from)
  to_secs <- string_to_seconds(to)
  if (from_secs > to_secs) stop("'from' must be lower than 'to'.")

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
  # not be judged by their template times, so they are dropped altogether

  gtfs$stop_times <- gtfs$stop_times[!trip_id %chin% lost_frequency_trips]

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
  # conditionally create time-in-seconds columns, depending if they exist before
  # or not. if they didn't exist beforehand, they have to be removed afterwards

  if (!gtfsio::check_field_exists(gtfs, "frequencies", "start_time_secs")) {
    gtfs$frequencies[, start_time_secs := string_to_seconds(start_time)]
    created_start_secs <- TRUE
  }

  if (!gtfsio::check_field_exists(gtfs, "frequencies", "end_time_secs")) {
    gtfs$frequencies[, end_time_secs := string_to_seconds(end_time)]
    created_end_secs <- TRUE
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

  gtfs$frequencies[
    ,
    `:=`(
      from_within = from_secs > start_time_secs & from_secs < end_time_secs,
      to_within = to_secs > start_time_secs & to_secs < end_time_secs,
      within_from_to = start_time_secs >= from_secs & end_time_secs <= to_secs
    )
  ]

  if (keep) {
    filtered_frequencies <- gtfs$frequencies[
      from_within == TRUE | to_within == TRUE | within_from_to == TRUE
    ]
  } else {
    filtered_frequencies <- gtfs$frequencies[
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

  # conditionally remove time-in-seconds columns

  if (exists("created_start_secs")) {
    gtfs$frequencies[, start_time_secs := NULL]
    filtered_frequencies[, start_time_secs := NULL]
  }

  if (exists("created_end_secs")) {
    gtfs$frequencies[, end_time_secs := NULL]
    filtered_frequencies[, end_time_secs := NULL]
  }

  # and remove the auxiliary columns

  gtfs$frequencies[, c("from_within", "to_within", "within_from_to") := NULL]
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

  if (is.null(filtered_frequencies$exact_times)) {
    if (keep) {
      filtered_frequencies[
        from_within == TRUE,
        start_time := seconds_to_string(from_secs)
      ]
      # end_time is exclusive, so it's set to one second after 'to' to keep the
      # departure at 'to', if there is one

      filtered_frequencies[
        to_within == TRUE,
        end_time := seconds_to_string(to_secs + 1L)
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
      # compared to keep = TRUE
      filtered_frequencies[
        from_within == TRUE,
        end_time := seconds_to_string(from_secs)
      ]
      filtered_frequencies[
        to_within == TRUE,
        start_time := seconds_to_string(to_secs)
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

      filtered_frequencies[
        to_within == TRUE & !exact_times %in% 1L,
        start_time_secs := to_secs
      ]
      filtered_frequencies[
        to_within == TRUE & exact_times %in% 1L,
        start_time_secs := start_time_secs +
          ceiling((to_secs - start_time_secs) / headway_secs) * headway_secs
      ]
      filtered_frequencies[
        to_within == TRUE,
        start_time := seconds_to_string(start_time_secs)
      ]
    }

    # updating the start_time respecting the headway may yield start_times
    # higher than the end_times. we remove the entries in which this situation
    # happens
    filtered_frequencies <- filtered_frequencies[
      start_time_secs <= end_time_secs
    ]
  }

  return(filtered_frequencies)
}


#' @keywords internal
filter_stop_times <- function(gtfs,
                              from_secs,
                              to_secs,
                              keep,
                              full_trips,
                              frequency_trips) {
  # conditionally create time-in-seconds columns, depending if they exist before
  # or not. if they didn't exist beforehand, they have to be removed afterwards

  if (!gtfsio::check_field_exists(gtfs, "stop_times", "departure_time_secs")) {
    gtfs$stop_times[, departure_time_secs := string_to_seconds(departure_time)]
    created_departure_secs <- TRUE
  }

  if (!gtfsio::check_field_exists(gtfs, "stop_times", "arrival_time_secs")) {
    gtfs$stop_times[, arrival_time_secs := string_to_seconds(arrival_time)]
    created_arrival_secs <- TRUE
  }

  # when filtering the stop_times table, we have to pay attention to the
  # full_trips and keep parameters. if both are TRUE, then we keep the trips
  # that have any of their stops visited inside the specified time of day. if
  # full_trips is TRUE and keep is FALSE, we drop the trips that have any of
  # their stops visited inside the time interval, and if full_trips is FALSE, we
  # keep/drop only the stops that fall outside the time interval

  if (keep) {
    filtered_stop_times <- gtfs$stop_times[
      (!(trip_id %chin% frequency_trips) &
        (departure_time_secs >= from_secs | arrival_time_secs >= from_secs) &
        (departure_time_secs <= to_secs | arrival_time_secs <= to_secs)) |
      trip_id %chin% frequency_trips
    ]

    if (full_trips) {
      trips_kept <- unique(filtered_stop_times$trip_id)
      filtered_stop_times <- gtfs$stop_times[trip_id %chin% trips_kept]
    }
  } else {
    filtered_stop_times <- gtfs$stop_times[
      (!(trip_id %chin% frequency_trips) &
        ((departure_time_secs < from_secs & arrival_time_secs < from_secs) |
        (departure_time_secs > to_secs & arrival_time_secs > to_secs))) |
      trip_id %chin% frequency_trips
    ]

    if (full_trips) {
      # we drop exactly the trips that keep = TRUE would keep, using the same
      # predicate. which() treats NA as FALSE, so untimed entries don't cause
      # their trips to be dropped

      trips_to_drop <- unique(
        gtfs$stop_times[
          which(
            !(trip_id %chin% frequency_trips) &
              (departure_time_secs >= from_secs |
                 arrival_time_secs >= from_secs) &
              (departure_time_secs <= to_secs | arrival_time_secs <= to_secs)
          )
        ]$trip_id
      )
      filtered_stop_times <- gtfs$stop_times[!trip_id %chin% trips_to_drop]
    }
  }

  # conditionally remove time-in-seconds columns

  if (exists("created_departure_secs")) {
    gtfs$stop_times[, departure_time_secs := NULL]
    filtered_stop_times[, departure_time_secs := NULL]
  }

  if (exists("created_arrival_secs")) {
    gtfs$stop_times[, arrival_time_secs := NULL]
    filtered_stop_times[, arrival_time_secs := NULL]
  }

  return(filtered_stop_times)
}
