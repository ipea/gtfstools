#' Get trip duration
#'
#' Returns the duration of each specified `trip_id`.
#'
#' @template gtfs
#' @param trip_id A string vector including the `trip_id`s to have their
#'   duration calculated. If `NULL` (the default) the function calculates the
#'   duration of every `trip_id` in the GTFS.
#' @param unit A string representing the time unit in which the duration is
#'   desired. One of `"s"` (seconds), `"min"` (minutes, the default), `"h"`
#'   (hours) or `"d"` (days).
#'
#' @return A `data.table` containing the duration of each specified trip.
#'
#' @section Details:
#' The duration of a trip is defined as the time difference between its last
#' arrival time and its first departure time, as specified in the `stop_times`
#' table.
#'
#' Existing `_secs` columns in `stop_times` (e.g. created with
#' [convert_time_to_seconds()]) are used as-is, not recalculated from the time
#' strings.
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#'
#' gtfs <- read_gtfs(data_path)
#'
#' trip_duration <- get_trip_duration(gtfs)
#' head(trip_duration)
#'
#' trip_ids <- c("CPTM L07-0", "2002-10-0")
#' trip_duration <- get_trip_duration(gtfs, trip_id = trip_ids)
#' trip_duration
#'
#' trip_duration <- get_trip_duration(gtfs, trip_id = trip_ids, unit = "h")
#' trip_duration
#'
#' @export
get_trip_duration <- function(gtfs, trip_id = NULL, unit = "min") {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = c("s", "min", "h", "d")),
    combine = "and"
  )

  # check if required fields and files exist

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time"),
    rep("character", 3)
  )

  # select trip_ids to get duration of and raise warning if a given trip_id
  # doesn't exist in 'stop_times'
  # also create object with filtered stop_times. if empty, return empty dt

  if (!is.null(trip_id)) {
    relevant_trips <- trip_id

    invalid_trip_id <- trip_id[! trip_id %chin% gtfs$stop_times$trip_id]

    if (!identical(invalid_trip_id, character(0))) {
      warning(
        paste0(
          "'stop_times' doesn't contain the following trip_id(s): "),
        paste0("'", invalid_trip_id, "'", collapse = ", ")
      )
    }

    if (all(gtfs$stop_times$trip_id %chin% relevant_trips)) {
      durations <- gtfs$stop_times
    } else {
      durations <- gtfs$stop_times[trip_id %chin% relevant_trips]
    }
  } else {
    durations <- gtfs$stop_times
  }

  if (nrow(durations) == 0) {
    durations <- data.table::data.table(
      trip_id = character(),
      duration = numeric()
    )

    return(durations)
  }

  # create auxiliary columns if needed

  if (!gtfsio::check_field_exists(gtfs, "stop_times", "departure_time_secs")) {
    durations[, departure_time_secs := string_to_seconds(departure_time)]
    created_departure_secs <- TRUE
  }

  if (!gtfsio::check_field_exists(gtfs, "stop_times", "arrival_time_secs")) {
    durations[, arrival_time_secs := string_to_seconds(arrival_time)]
    created_arrival_secs <- TRUE
  }

  # calculate durations

  durations <- durations[
    ,
    .(
      duration = max(arrival_time_secs, na.rm = TRUE) -
        min(departure_time_secs, na.rm = TRUE)
    ),
    keyby = trip_id
  ]

  # clean up auxiliary columns if needed

  if (
    gtfsio::check_field_exists(gtfs, "stop_times", "departure_time_secs") &
    exists("created_departure_secs")
  ) {
    gtfs$stop_times[, departure_time_secs := NULL]
  }

  if (
    gtfsio::check_field_exists(gtfs, "stop_times", "arrival_time_secs") &
    exists("created_arrival_secs")
  ) {
    gtfs$stop_times[, arrival_time_secs := NULL]
  }

  # convert duration to desired unit

  # {units} converts element by element, which is slow on long vectors, so we
  # get the conversion factor from a single value and multiply by it

  if (unit != "s") {
    unit_factor <- as.numeric(
      units::set_units(units::as_units(1, "s"), unit, mode = "standard")
    )
    durations[, duration := duration * unit_factor]
  }

  return(durations[])
}
