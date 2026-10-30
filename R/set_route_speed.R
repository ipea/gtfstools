#' Set route average speed
#'
#' Sets the average speed of the trips of each specified `route_id`, or of a
#' segment of them, by changing the `arrival_time` and `departure_time` columns
#' in `stop_times`.
#'
#' @template gtfs
#' @param route_id A character vector including the `route_id`s to have the
#'   average speed of their trips set. `route_id`s not listed in `trips` are
#'   ignored, with a warning. If `NULL` (the default), `route_type` must be
#'   given, and the speed of every trip of these types is set.
#' @param speed A number representing the speed to be set for the trips of all
#'   `route_id`s. Must be positive and finite.
#' @inheritParams set_trip_speed
#'
#' @return If `by_reference` is set to `FALSE`, returns a GTFS object with the
#'   time columns of its `stop_times` adjusted. Else, returns a GTFS object
#'   invisibly (note that in this case the original GTFS object is altered).
#'
#' @section Details:
#' Every trip of each route, as listed in `trips`, gets the given speed, as
#' in [set_trip_speed()], whose details also apply here: the duration of each
#' trip's segment (by default, the whole trip) is set to its length divided by
#' `speed`, the times at stops inside the segment are set to `""`, and `from`
#' and `to` restrict the changes to the trips that depart from the segment's
#' first stop within the time of day. Warnings about trips that can't be
#' changed refer to their `trip_id`s. Trips without `stop_times` entries are
#' ignored.
#'
#' @seealso [set_trip_speed()], [get_trip_speed()], [get_route_speed()]
#'
#' @examplesIf requireNamespace("dplyr", quietly = TRUE)
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#' }
#' library(dplyr)
#'
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' get_route_speed(gtfs, route_id = "CPTM L07")
#'
#' new_speed_gtfs <- set_route_speed(gtfs, route_id = "CPTM L07", speed = 50)
#' get_route_speed(new_speed_gtfs, route_id = "CPTM L07")
#'
#' # set the speed only of the trips that depart within a time of day
#' poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
#' poa_gtfs <- read_gtfs(poa_path)
#'
#' poa_new_speed <- set_route_speed(
#'   poa_gtfs,
#'   route_id = "T2",
#'   speed = 25,
#'   from = "07:00:00",
#'   to = "09:00:00"
#' )
#'
#' # the arrival at the last stop of a trip that departs at 07:02 changes
#' poa_gtfs$stop_times |>
#'   filter(trip_id == "T2-1@1#702") |>
#'   slice_tail(n = 1)
#'
#' poa_new_speed$stop_times |>
#'   filter(trip_id == "T2-1@1#702") |>
#'   slice_tail(n = 1)
#' \dontshow{data.table::setDTthreads(old_dt_threads)}
#'
#' @export
set_route_speed <- function(
  gtfs,
  route_id = NULL,
  speed,
  unit = "km/h",
  first_stop = NULL,
  last_stop = NULL,
  from = NULL,
  to = NULL,
  route_type = NULL,
  by_reference = FALSE
) {
  gtfs <- assert_and_assign_gtfs_object(gtfs, by_reference = by_reference)
  if (is.null(route_id) && is.null(route_type)) {
    cli::cli_abort(
      "At least one of {.arg route_id} and {.arg route_type} must be given.",
      class = "gtfstools_missing_selection_error"
    )
  }
  checkmate::assert_character(route_id, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_number(speed, finite = TRUE)
  gtfsio::assert_field_class(
    gtfs,
    "trips",
    c("trip_id", "route_id"),
    c("character", "character")
  )

  # select the trips of the given routes that have stop times, so that
  # set_trip_speed() doesn't warn about trips without them. without route_id,
  # set_trip_speed() selects the trips of the given route types itself (and
  # doesn't warn about those that don't visit the segment)

  trip_ids <- NULL

  if (!is.null(route_id)) {
    ids <- route_id
    trips <- unique(gtfs$trips[route_id %chin% ids, .(trip_id, route_id)])
    if (is.character(gtfs$stop_times$trip_id)) {
      trips <- trips[trip_id %chin% gtfs$stop_times$trip_id]
    }
    trip_ids <- trips$trip_id
  }

  # every trip gets the same speed. the other arguments, and whether speed is
  # positive, are validated by set_trip_speed()

  result <- set_trip_speed(
    gtfs,
    trip_id = trip_ids,
    speed = speed,
    unit = unit,
    first_stop = first_stop,
    last_stop = last_stop,
    from = from,
    to = to,
    route_type = route_type,
    by_reference = by_reference
  )

  # warn about invalid routes after set_trip_speed() has validated the other
  # arguments, so that errors come first

  warn_invalid_ids(route_id, gtfs$trips$route_id, "trips", "route_id")

  if (by_reference) {
    return(invisible(result))
  }

  return(result)
}
