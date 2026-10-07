#' Get stop times patterns
#'
#' Identifies spatial and spatiotemporal patterns within the `stop_times`
#' table. Please see the details to understand what a "pattern" means in each of
#' these cases.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s to have their
#'   `stop_times` entries analyzed. If `NULL` (the default), the function
#'   analyses the pattern of every `trip_id` in the GTFS.
#' @param type A string specifying the type of patterns to be analyzed. Either
#'   `"spatial"` (the default) or "spatiotemporal".
#' @param sort_sequence A logical specifying whether to sort timetables by
#'   `stop_sequence`. Defaults to `TRUE`. Sorting an already ordered table is
#'   cheap, and pattern identification based on unordered timetables may result
#'   in multiple ids identifying what would be the same pattern, had the table
#'   been ordered. Set to `FALSE` only if the timetables are known to be
#'   ordered.
#'
#' @return A `data.table` associating each `trip_id` to a `pattern_id`.
#'
#' @section Details:
#' Two trips are assigned to the same spatial `pattern_id` if they travel along
#' the same sequence of stops. They are assigned to the same spatiotemporal
#' `pattern_id`, on the other hand, if they travel along the same sequence of
#' stops and they take the same time between stops. Please note that, in such
#' case, only the time between stops is taken into account, and the time that
#' the trip started is ignored (e.g. if two trips depart from stop A and follow
#' the same sequence of stops to arrive at stop B, taking both 1 hour to do so,
#' their spatiotemporal pattern will be considered the same, even if one
#' departed at 6 am and another at 7 am). Please also note that the
#' `stop_sequence` field is currently ignored - which means that two stops are
#' considered to follow the same sequence if one is listed right below the
#' other on the `stop_times` table (e.g. if trip X lists stops A followed by
#' stop B with `stop_sequence`s 1 and 2, and trip Y lists stops A followed by
#' stop B with `stop_sequence`s 1 and 3, they are assigned to the same
#' `pattern_id`).
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
#' data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
#'
#' gtfs <- read_gtfs(data_path)
#'
#' patterns <- get_stop_times_patterns(gtfs)
#' head(patterns)
#'
#' # use the trip_id argument to control which trips are analyzed
#' patterns <- get_stop_times_patterns(
#'   gtfs,
#'   trip_id = c("143765658", "143765659", "143765660")
#' )
#' patterns
#'
#' # use the type argument to control the type of pattern analyzed
#' patterns <- get_stop_times_patterns(
#'   gtfs,
#'   trip_id = c("143765658", "143765659", "143765660"),
#'   type = "spatiotemporal"
#' )
#' patterns
#'
#' @export
get_stop_times_patterns <- function(gtfs,
                                    trip_id = NULL,
                                    type = "spatial",
                                    sort_sequence = TRUE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_string(type),
    checkmate::check_names(type, subset.of = c("spatial", "spatiotemporal")),
    combine = "and"
  )
  checkmate::assert_logical(sort_sequence, any.missing = FALSE, len = 1)

  must_exist <- c("trip_id", "stop_id")
  classes <- rep("character", 2)
  if (type == "spatiotemporal") {
    must_exist <- c(must_exist, "departure_time", "arrival_time")
    classes <- c(classes, rep("character", 2))
  }
  if (sort_sequence) {
    must_exist <- c(must_exist, "stop_sequence")
    classes <- c(classes, "integer")
  }
  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    fields = must_exist,
    classes = classes
  )

  # select trips to check patterns of and raise warning if any of them doesn't
  # exist in stop_times

  if (!is.null(trip_id)) {
    relevant_trips <- trip_id

    warn_missing_ids(trip_id, gtfs$stop_times$trip_id, "stop_times", "trip_id")

    patterns <- gtfs$stop_times[trip_id %chin% relevant_trips]
  } else {
    patterns <- gtfs$stop_times
  }

  if (sort_sequence) {
    if (is.null(trip_id)) patterns <- data.table::copy(patterns)
    patterns <- data.table::setorderv(patterns, c("trip_id", "stop_sequence"))
  }

  # each trip's sequence of stops is described by integer codes instead of the
  # stop_ids themselves, because ids may contain the characters used to
  # separate them (e.g. the sequences "a;b" -> "c" and "a" -> "b;c" would both
  # be described as "a;b;c")

  stop_codes <- data.table::chmatch(patterns$stop_id, unique(patterns$stop_id))

  if (type == "spatial") {
    patterns <- patterns[
      ,
      .(data = paste0(stop_codes[.I], collapse = ";")),
      keyby = trip_id
    ]
  } else {
    if (
      !gtfsio::check_field_exists(gtfs, "stop_times", "departure_time_secs")
    ) {
      patterns[, departure_time_secs := string_to_seconds(departure_time)]
      created_departure_secs <- TRUE
    }
    if (
      !gtfsio::check_field_exists(gtfs, "stop_times", "arrival_time_secs")
    ) {
      patterns[, arrival_time_secs := string_to_seconds(arrival_time)]
      created_arrival_secs <- TRUE
    }

    patterns <- patterns[
      ,
      {
        first_departure <- if (all(is.na(departure_time_secs))) NA_integer_ else
          min(departure_time_secs, na.rm = TRUE)

        .(
          data = paste(
            stop_codes[.I],
            departure_time_secs - first_departure,
            arrival_time_secs - first_departure,
            sep = "|",
            collapse = ";"
          )
        )
      },
      keyby = trip_id
    ]

    if (
      gtfsio::check_field_exists(gtfs, "stop_times", "departure_time_secs") &&
      exists("created_departure_secs")
    ) {
      gtfs$stop_times[, departure_time_secs := NULL]
    }

    if (
      gtfsio::check_field_exists(gtfs, "stop_times", "arrival_time_secs") &&
      exists("created_arrival_secs")
    ) {
      gtfs$stop_times[, arrival_time_secs := NULL]
    }
  }

  patterns[, pattern_id := .GRP, by = data]
  patterns[, data := NULL]

  return(patterns[])
}
