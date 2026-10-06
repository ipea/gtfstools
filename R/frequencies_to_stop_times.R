#' Convert frequencies to stop times
#'
#' Creates `stop_times` entries based on the frequencies specified in the
#' `frequencies` table.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#' frequencies converted to `stop_times` entries. If `NULL` (the default), the
#' function converts all trips listed in the `frequencies` table.
#' @param force Whether to convert trips specified in the `frequencies` table
#' even if they are not described in `stop_times` (defaults to `FALSE`). When
#' set to `TRUE`, these mismatched trip are removed from the `frequencies` table
#' and their correspondent entries in `trips` are substituted by what would be
#' their converted counterpart.
#'
#' @return A GTFS object with updated `frequencies`, `stop_times` and `trips`
#' tables.
#'
#' @section Details:
#' A single trip described in a `frequencies` table may yield multiple trips
#' after converting the GTFS. Let's say, for example, that the `frequencies`
#' table describes a trip called `"example_trip"`, that starts at 08:00 and
#' stops at 09:00, with a 30 minutes headway.
#'
#' In practice, that means that one trip will depart at 08:00, another at 08:30
#' and yet another at 09:00. `frequencies_to_stop_times()` appends a `"_<n>"`
#' suffix to the newly created trips to differentiate each one of them (e.g. in
#' this case, the new trips, described in the `trips` and `stop_times` tables,
#' would be called `"example_trip_1"`, `"example_trip_2"` and
#' `"example_trip_3"`).
#'
#' Existing `_secs` columns in `stop_times` and `frequencies` (e.g. created
#' with [convert_time_to_seconds()]) are used as-is, not recalculated from the
#' time strings.
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#' trip <- "CPTM L07-0"
#'
#' # converts all trips listed in the frequencies table
#' converted_gtfs <- frequencies_to_stop_times(gtfs)
#'
#' # converts only the specified trip_id
#' converted_gtfs <- frequencies_to_stop_times(gtfs, trip)
#'
#' # how the specified trip_id was described in the frequencies table
#' head(gtfs$frequencies[trip_id == trip])
#'
#' # the first row of each equivalent stop_times entry in the converted gtfs
#' equivalent_stop_times <- converted_gtfs$stop_times[grepl(trip, trip_id)]
#' equivalent_stop_times[equivalent_stop_times[, .I[1], by = trip_id]$V1]
#'
#' @export
frequencies_to_stop_times <- function(gtfs, trip_id = NULL, force = FALSE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_logical(force, len = 1, any.missing = FALSE)
  gtfsio::assert_field_class(
    gtfs,
    "frequencies",
    c("trip_id", "start_time", "end_time", "headway_secs"),
    c("character", "character", "character", "integer")
  )
  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time"),
    c("character", "character", "character")
  )

  if (!is.null(trip_id)) {
    relevant_trips <- unique(trip_id)
  } else {
    relevant_trips <- unique(gtfs$frequencies$trip_id)
  }

  # raise warning if a given trip_id doesn't exist in 'frequencies'

  if (!is.null(trip_id)) {
    invalid_trip_id <- trip_id[
      ! trip_id %chin% unique(gtfs$frequencies$trip_id)
    ]

    if (!identical(invalid_trip_id, character(0))) {
      warning(
        "'frequencies' doesn't contain the following trip_id(s): ",
        paste0("'", invalid_trip_id, "'", collapse = ", "),
        call. = FALSE
      )

      relevant_trips <- setdiff(relevant_trips, invalid_trip_id)
    }
  }

  # check if a trip exists in 'frequencies' but not in 'stop_times', and
  # conditionally remove them from the pool of trips based on 'force'

  stop_times_trips <- unique(gtfs$stop_times$trip_id)
  missing_from_stop_times <- setdiff(relevant_trips, stop_times_trips)

  if (!force) relevant_trips <- setdiff(relevant_trips, missing_from_stop_times)

  if (!identical(missing_from_stop_times, character(0))) {
    warning(
      "The following trip_id(s) are listed in 'frequencies' ",
      "but not in 'stop_times': ",
      paste0("'", missing_from_stop_times, "'", collapse = ", "),
      call. = FALSE
    )
  }

  # the conversion works on copies of the relevant rows of 'frequencies' and
  # 'stop_times', so the tables of the given gtfs are not modified. if they do
  # not exist already, create auxiliary columns that hold the start and end
  # time (in the case of frequencies) and the arrival and departure time (in the
  # case of stop_times) of each trip in seconds

  relevant_trips_dt <- data.table::data.table(trip_id = relevant_trips)

  freqs <- gtfs$frequencies[relevant_trips_dt, on = "trip_id", nomatch = 0L]

  if (!"start_time_secs" %chin% names(freqs)) {
    freqs[, start_time_secs := string_to_seconds(start_time)]
  }

  if (!"end_time_secs" %chin% names(freqs)) {
    freqs[, end_time_secs := string_to_seconds(end_time)]
  }

  templates <- gtfs$stop_times[relevant_trips_dt, on = "trip_id", nomatch = 0L]

  created_departure_secs <- !"departure_time_secs" %chin% names(templates)
  if (created_departure_secs) {
    templates[, departure_time_secs := string_to_seconds(departure_time)]
  }

  created_arrival_secs <- !"arrival_time_secs" %chin% names(templates)
  if (created_arrival_secs) {
    templates[, arrival_time_secs := string_to_seconds(arrival_time)]
  }

  # first step: figure out, based on the 'frequencies' table, what are the
  # departure times of each trip to be added to the 'stop_times' table.
  # each entry generates the departures seq(start_time, end_time, headway_secs)

  invalid_entry <- is.na(freqs$start_time_secs) |
    is.na(freqs$end_time_secs) |
    is.na(freqs$headway_secs) |
    freqs$end_time_secs < freqs$start_time_secs |
    (freqs$headway_secs <= 0L & freqs$end_time_secs != freqs$start_time_secs)

  if (any(invalid_entry)) {
    invalid_trips <- unique(freqs$trip_id[invalid_entry])
    n_invalid <- length(invalid_trips)

    cli::cli_abort(
      c(
        paste0(
          "{.file frequencies} has invalid entries for {n_invalid} ",
          "trip_id{?s}: {.val {invalid_trips}}."
        ),
        "i" = paste0(
          "Each entry must have a valid {.field start_time} and ",
          "{.field end_time}, with {.field end_time} not before ",
          "{.field start_time}, and a positive {.field headway_secs} (unless ",
          "{.field start_time} and {.field end_time} are equal)."
        )
      ),
      class = "gtfstools_invalid_frequencies"
    )
  }

  span <- freqs$end_time_secs - freqs$start_time_secs
  n_departures <- rep(1L, length(span))
  n_departures[span > 0L] <- span[span > 0L] %/% freqs$headway_secs[span > 0L] +
    1L

  # there may be some duplicated departure times if the same value is listed
  # in the upper and lower limit of two different 'frequencies' entries (e.g.
  # if the table specifies one frequency from 5am to 6am and another from 6am
  # to 7am, the 6am departure may appear in the departures generated by both
  # entries), so we keep only the unique departures of each trip.
  # each new trip is named after the original trip, with a _<n> suffix. so the
  # trip "original_trip" generates the trips "original_trip_1",
  # "original_trip_2", ..., "original_trip_<n>"

  departures <- unique(
    data.table::data.table(
      trip_id = rep(freqs$trip_id, n_departures),
      departure_secs = rep(freqs$start_time_secs, n_departures) +
        (sequence(n_departures) - 1L) * rep(freqs$headway_secs, n_departures)
    )
  )
  departures[
    ,
    new_trip_id := sprintf("%s_%d", trip_id, data.table::rowid(trip_id))
  ]

  # second step: identify the stop_times template of each relevant trip and
  # its first departure time. trips not listed in 'stop_times' (only kept when
  # force = TRUE) have no template, and therefore no stop_times entries

  templates_info <- templates[
    ,
    .(
      n_stops = .N,
      first_departure = if (all(is.na(departure_time_secs))) {
        NA_integer_
      } else {
        min(departure_time_secs, na.rm = TRUE)
      }
    ),
    by = trip_id
  ]

  if (anyNA(templates_info$first_departure)) {
    empty_templates <- templates_info[is.na(first_departure)]$trip_id
    n_empty <- length(empty_templates)

    cli::cli_abort(
      c(
        paste0(
          "Can't convert the frequencies of {n_empty} ",
          "trip_id{?s}: {.val {empty_templates}}."
        ),
        "x" = paste0(
          "{.file stop_times} has no {.field departure_time} for ",
          "{cli::qty(n_empty)}{?this trip/these trips}."
        ),
        "i" = paste0(
          "At least one departure time is needed to shift the trip's ",
          "times to each departure listed in {.file frequencies}."
        )
      ),
      class = "gtfstools_empty_template"
    )
  }

  templates_info[, first_row := cumsum(n_stops) - n_stops + 1L]

  # third step: build a "new" stop_times table by repeating each template once
  # per departure, shifting its times so that the first departure of the
  # template matches the departure of the new trip

  template_idx <- match(departures$trip_id, templates_info$trip_id)
  n_rows <- templates_info$n_stops[template_idx]
  n_rows[is.na(n_rows)] <- 0L

  seconds_to_add <- rep(
    departures$departure_secs - templates_info$first_departure[template_idx],
    n_rows
  )
  rows_to_add <- rep(templates_info$first_row[template_idx], n_rows) +
    sequence(n_rows) - 1L

  stop_times_to_add <- templates[rows_to_add]
  stop_times_to_add[
    ,
    `:=`(
      trip_id = rep(departures$new_trip_id, n_rows),
      departure_time_secs = departure_time_secs + seconds_to_add,
      arrival_time_secs = arrival_time_secs + seconds_to_add
    )
  ]
  stop_times_to_add[
    ,
    `:=`(
      departure_time = seconds_to_string(departure_time_secs),
      arrival_time = seconds_to_string(arrival_time_secs)
    )
  ]

  # fourth step: filter the original stop_times table and bind the new one to
  # it. remove the auxiliary columns if they didn't exist before the function
  # call

  if (created_departure_secs) stop_times_to_add[, departure_time_secs := NULL]
  if (created_arrival_secs) stop_times_to_add[, arrival_time_secs := NULL]

  filtered_stop_times <- gtfs$stop_times[! trip_id %chin% relevant_trips]
  gtfs$stop_times <- rbind(filtered_stop_times, stop_times_to_add)

  # fifth step: adjust the trips table to include the new trips, each one a
  # copy of its original trip

  trips_to_add <- gtfs$trips[match(departures$trip_id, gtfs$trips$trip_id)]
  trips_to_add[, trip_id := departures$new_trip_id]

  filtered_trips <- gtfs$trips[! trip_id %chin% relevant_trips]
  gtfs$trips <- rbind(filtered_trips, trips_to_add)

  # sixth step: adjust the frequencies table

  filtered_frequencies <- gtfs$frequencies[! trip_id %chin% relevant_trips]

  if (nrow(filtered_frequencies) > 0) {
    gtfs$frequencies <- filtered_frequencies
  } else {
    gtfs$frequencies <- NULL
  }

  return(gtfs)
}
