#' Set trip average speed
#'
#' Sets the average speed of each specified `trip_id` by changing the
#' `arrival_time` and `departure_time` columns in `stop_times`.
#'
#' @template gtfs
#' @param trip_id A string vector including the `trip_id`s to have their
#'   average speed set.
#' @param speed A numeric representing the speed to be set. Its length must
#'   either equal 1, in which case the value is recycled for all
#'   `trip_id`s, or equal `trip_id`'s length.
#' @param unit A string representing the unit in which the speed is given. One
#'   of `"km/h"` (the default) or `"m/s"`.
#' @param by_reference Whether to update `stop_times`' `data.table` by
#'   reference. Defaults to `FALSE`.
#'
#' @return If `by_reference` is set to `FALSE`, returns a GTFS object with the
#'   time columns of its `stop_times` adjusted. Else, returns a GTFS object
#'   invisibly (note that in this case the original GTFS object is altered).
#'
#' @section Details:
#' The average speed is calculated as the difference between the arrival time
#' at the last stop minus the departure time at the first top, over the trip's
#' length (as calculated via [get_trip_geometry()], based on the `shapes`
#' file). The arrival and departure times at all other stops (i.e. not the
#' first neither the last) are set as `""`, which is written as `NA` with
#' [write_gtfs()]. Some transport routing software, such as
#' [OpenTripPlanner](http://www.opentripplanner.org/), support specifying stop
#' times like so. In such cases, they estimate arrival/departure times at the
#' others stops based on the average speed as well. We plan to add that feature
#' to this function in the future.
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
#' gtfs_new_speed <- set_trip_speed(gtfs, trip_id = "CPTM L07-0", 50)
#' gtfs_new_speed$stop_times[trip_id == "CPTM L07-0"]
#'
#' # use the unit argument to change the speed unit
#' gtfs_new_speed <- set_trip_speed(
#'   gtfs,
#'   trip_id = "CPTM L07-0",
#'   speed = 15,
#'   unit = "m/s"
#' )
#' gtfs_new_speed$stop_times[trip_id == "CPTM L07-0"]
#'
#' # original gtfs remains unchanged
#' gtfs$stop_times[trip_id == "CPTM L07-0"]
#'
#' # when doing by reference, original gtfs is changed
#' set_trip_speed(gtfs, trip_id = "CPTM L07-0", 50, by_reference = TRUE)
#' gtfs$stop_times[trip_id == "CPTM L07-0"]
#'
#' @export
set_trip_speed <- function(gtfs,
                           trip_id,
                           speed,
                           unit = "km/h",
                           by_reference = FALSE) {
  env <- environment()

  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(trip_id, any.missing = FALSE)
  checkmate::assert(
    checkmate::check_number(speed),
    checkmate::check_numeric(speed, len = length(trip_id), any.missing = FALSE),
    combine = "or"
  )
  checkmate::assert(
    checkmate::check_string(unit),
    checkmate::check_names(unit, subset.of = c("km/h", "m/s")),
    combine = "and"
  )
  checkmate::assert_logical(by_reference, any.missing = FALSE, len = 1)

  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "arrival_time", "departure_time", "stop_sequence"),
    c("character", "character", "character", "integer")
  )

  # calculate the length of each given trip_id

  trip_length <- get_trip_geometry(gtfs, trip_id, file = "shapes")
  trip_length_ids <- trip_length$trip_id
  trip_length <- sf::st_length(trip_length)
  trip_length <- as.numeric(units::set_units(trip_length, "km"))
  names(trip_length) <- trip_length_ids

  # set speed adequate unit (use km/h for calculations)

  if (length(speed) == 1) speed <- rep(speed, length(trip_id))

  units(speed) <- unit
  speed <- as.numeric(units::set_units(speed, "km/h"))
  names(speed) <- trip_id

  # calculate each trip duration (in hours) based on its length and given
  # desired speed. calculate only of those 'trip_id's that exist in 'stop_times'

  trip_duration <- trip_length[trip_length_ids] / speed[trip_length_ids]

  # if by_reference is set to FALSE, make a copy of stop_times

  if (by_reference) {
    stop_times <- gtfs$stop_times
  } else {
    stop_times <- data.table::copy(gtfs$stop_times)
  }

  # find index of:
  # - all stops relative to given trip_ids
  # - first and last stops of each given trip_id
  # - the difference of above objects (thus the intermediate entries)

  desired_trips_index <- stop_times[, .I[trip_id %chin% trip_length_ids]]

  min_stops_index_df <- stop_times[
    trip_id %chin% trip_length_ids,
    .I[which.min(stop_sequence)],
    by = trip_id
  ]
  min_stops_index <- min_stops_index_df$V1
  names(min_stops_index) <- min_stops_index_df$trip_id

  # issue #37 - max() raises a warning if it receives a integer(0), which
  # happens when none of the specified 'trip_id's exist in the gtfs object

  if (identical(trip_length_ids, character(0))) {
    max_stops_index <- 0
  } else {
    max_stops_index_df <- stop_times[
      trip_id %chin% trip_length_ids,
      .I[stop_sequence == max(stop_sequence)],
      by = trip_id
    ]
    max_stops_index <- max_stops_index_df$V1
    names(max_stops_index) <- max_stops_index_df$trip_id
  }

  # substitute given 'trip_id's intermediate stops arrival and departure time
  # by ""

  na_time_stops_index <- setdiff(
    desired_trips_index,
    c(min_stops_index, max_stops_index)
  )

  stop_times[na_time_stops_index, `:=`(arrival_time = "", departure_time = "")]

  # make sure that first stop arrival_time equals departure_time and save value

  stop_times[min_stops_index, arrival_time := departure_time]

  first_departure <- stop_times[min_stops_index, departure_time]
  first_departure <- string_to_seconds(first_departure)
  names(first_departure) <- names(min_stops_index)

  # substitute last stop arrival and departure_time by first_departure plus
  # duration

  trip_duration_secs <- as.integer(trip_duration * 3600)
  names(trip_duration_secs) <- names(trip_duration)

  last_arrival  <- first_departure[trip_length_ids] +
    trip_duration_secs[trip_length_ids]
  last_arrival  <- seconds_to_string(last_arrival)
  names(last_arrival) <- trip_length_ids

  stop_times[
    max_stops_index,
    `:=`(
      arrival_time = last_arrival[names(max_stops_index)],
      departure_time = last_arrival[names(max_stops_index)]
    )
  ]

  if (by_reference) return(invisible(gtfs))

  gtfs$stop_times <- stop_times
  return(gtfs)
}
