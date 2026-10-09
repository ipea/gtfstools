#' Get distances between stops
#'
#' Returns the distance between each pair of stops visited by the given trips
#' and/or routes.
#'
#' @template gtfs
#' @param trip_id A character vector including the `trip_id`s whose stops
#'   should be considered. If `NULL` (the default), all trips are considered.
#'   An empty vector selects no trip.
#' @param route_id A character vector including the `route_id`s whose stops
#'   should be considered. If `NULL` (the default), all routes are considered.
#'   An empty vector selects no route.
#'
#' @return A `data.table` with the columns `from_stop_id`, `to_stop_id` and
#'   `distance` (in meters), with one row for each pair of distinct stops,
#'   sorted by `from_stop_id` and `to_stop_id`. It is empty if fewer than two
#'   stops are selected.
#'
#' @section Details:
#' The stops are selected as in [get_stops()]: only the stops listed in the
#' `stop_times` entries of the selected trips are considered.
#'
#' Distances are great-circle distances ("as the crow flies") between the
#' stops' coordinates, not distances along the trips' shapes or the street
#' network.
#'
#' Each pair of stops appears only once, with the `stop_id` that comes first
#' in the C locale (the order used by `data.table`) as `from_stop_id`. If a
#' `stop_id` is listed more than once in `stops`, only its first entry is
#' used. Stops without coordinates have `NA` distances.
#'
#' The size of the result grows with the square of the number of stops: about
#' 1 GB of memory is used for 5,500 stops, and about 3 GB for 10,000 stops.
#' A warning is raised when more than 1 GB is needed, so on large feeds
#' please select only the trips or routes of interest. More than 65,536 stops
#' can't be used at once, raising an error.
#'
#' @seealso [get_stops()], [get_trip_length()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # distances between the stops visited by a trip
#' distances <- get_stop_distances(gtfs, trip_id = "CPTM L07-0")
#' head(distances)
#'
#' # distances between the stops visited by the trips of a route
#' distances <- get_stop_distances(gtfs, route_id = "CPTM L07")
#' head(distances)
#' @export
get_stop_distances <- function(gtfs, trip_id = NULL, route_id = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  gtfsio::assert_field_class(
    gtfs,
    "stops",
    c("stop_lat", "stop_lon"),
    rep("numeric", 2)
  )

  # get_stops() validates the ids, warns about missing ones and returns a new
  # table, so sorting it doesn't change the given gtfs

  stops <- get_stops(gtfs, trip_id, route_id)

  # duplicated stop_ids would create pairs of a stop with itself and repeated
  # pairs, so only their first entries are kept. the stops are sorted so that
  # each pair is listed only once

  stops <- unique(stops, by = "stop_id")
  data.table::setorderv(stops, "stop_id")

  # a data.table can't hold more than .Machine$integer.max rows. the number
  # of pairs is calculated as a double to avoid an integer overflow

  n_stops <- nrow(stops)
  n_pairs <- as.numeric(n_stops) * (n_stops - 1) / 2

  if (n_pairs > .Machine$integer.max) {
    cli::cli_abort(
      c(
        "Too many stops to calculate the distances between all of them.",
        "x" = "{n_stops} stops make {format(n_pairs, big.mark = ',',
               scientific = FALSE)} pairs.",
        "i" = "Please select fewer stops with {.arg trip_id} or
               {.arg route_id}."
      ),
      class = "gtfstools_too_many_stops"
    )
  }

  # each pair takes about 64 bytes of memory at the peak (its indices, the
  # coordinates of its two stops and its row in the result), so the user is
  # warned before large selections that may exhaust the memory

  if (n_pairs > max_stop_pairs_without_warning()) {
    memory_gb <- signif(n_pairs * 64 / 1e9, 2)

    cli::cli_warn(
      c(
        "Calculating the distances between {n_stops} stops may use a lot of
         memory.",
        "i" = "{format(n_pairs, big.mark = ',', scientific = FALSE)} pairs of
               stops need about {memory_gb} GB.",
        "i" = "Consider selecting fewer stops with {.arg trip_id} or
               {.arg route_id}."
      ),
      class = "gtfstools_many_stops_warning"
    )
  }

  # indices of all pairs i < j, which are empty if there are fewer than 2
  # stops

  from_idx <- rep.int(seq_len(n_stops), n_stops - seq_len(n_stops))
  to_idx <- sequence(n_stops - seq_len(n_stops)) + from_idx

  distances <- data.table::data.table(
    from_stop_id = stops$stop_id[from_idx],
    to_stop_id = stops$stop_id[to_idx],
    distance = rcpp_distance_haversine(
      stops$stop_lat[from_idx],
      stops$stop_lon[from_idx],
      stops$stop_lat[to_idx],
      stops$stop_lon[to_idx]
    )
  )

  return(distances)
}



#' Maximum number of stop pairs without a warning
#'
#' The number of pairs of stops above which [get_stop_distances()] warns
#' about its memory use: 15 million pairs, which take about 1 GB at the peak
#' (about 5,500 stops). A function, so tests can lower it.
#'
#' @return A number.
#'
#' @keywords internal
max_stop_pairs_without_warning <- function() {
  return(1.5e7)
}
