#' Fix common problems in GTFS feeds
#'
#' Cleans a GTFS feed in one call, by removing duplicated entries and unused
#' ids, fixing times after midnight written as early morning times, optionally
#' capping the speed of trips, filling blank stop times, optionally setting a
#' minimum dwell time at intermediate stops and recalculating the distances
#' travelled along shapes (replacing any existing ones).
#'
#' @template gtfs
#' @param max_speed A number. The maximum speed of trips, in the unit given by
#'   `speed_unit`. If `NULL` (the default), speeds are not capped.
#' @param speed_unit A string representing the unit in which `max_speed` is
#'   given. One of `"km/h"` (the default), `"m/s"` or `"mph"` (miles per hour).
#' @param min_dwell_time A non-negative number. The minimum time vehicles
#'   remain stopped at each intermediate stop of their trips, with their doors
#'   open to serve passengers, in the unit given by `dwell_time_unit`. If
#'   `NULL` (the default), dwell times are not changed.
#' @param dwell_time_unit A string representing the time unit in which
#'   `min_dwell_time` is given. One of `"s"` (seconds, the default), `"min"`
#'   (minutes), `"h"` (hours) or `"d"` (days).
#' @param overwrite_stop_times A logical. If `FALSE` (the default), only blank
#'   stop times are filled. If `TRUE`, the times of every stop between the
#'   first and the last stop of each trip are replaced by times interpolated
#'   over the distance travelled, keeping their dwell times (see the
#'   `overwrite` and `keep_dwell_times` arguments of
#'   [interpolate_stop_times()]).
#'
#' @return The fixed GTFS object.
#'
#' @section Details:
#' The feed goes through the following steps, in this order:
#'
#' 1. [remove_duplicates()] removes duplicated entries from every table;
#' 2. [remove_unused_ids()] removes the trips without `stop_times`, and the
#'    entries of every table that no remaining trip uses (see its
#'    documentation for the exceptions). Note that this removes data from the
#'    feed;
#' 3. [fix_overnight_times()] rewrites the times after midnight written as
#'    early morning times (e.g. `"00:30:00"` instead of `"24:30:00"`), so the
#'    next steps work on these trips too. Only times that go back by more
#'    than 12 hours are taken as times after midnight, and the times that
#'    still go back are left unchanged, with a warning;
#' 4. [set_max_speed()], only if `max_speed` is given, slows down the parts of
#'    trips that are faster than `max_speed`. Only spans between stops with
#'    known times are capped, and spans that still end before they start are
#'    left unchanged, with a warning;
#' 5. [interpolate_stop_times()] fills blank stop times from the times of the
#'    stops around them. Speeds are capped before interpolating, so the filled
#'    times follow the capped times. Interpolated times are rounded to the
#'    second. Stops whose times can't be interpolated are left blank, with a
#'    warning. With `overwrite_stop_times = TRUE`, the times of every
#'    intermediate stop are replaced instead, from each trip's first and last
#'    times, keeping the stops' dwell times. The trips' durations still
#'    follow the capped times, and their travel time is spread evenly over
#'    the distance;
#' 6. [set_min_dwell_time()], only if `min_dwell_time` is given, delays the
#'    departure from each intermediate stop whose dwell time is shorter than
#'    `min_dwell_time`, so that vehicles stay there for at least that long.
#'    The minimum is rounded to the second. The later times of each changed
#'    trip are shifted accordingly, so the trip ends later (for trips listed
#'    in `frequencies`, every departure gets longer). This is done after
#'    filling blank times, so the filled stops also get the minimum. Only the
#'    stops between the first and the last stop with times of each trip get
#'    the minimum, so trips keep their start times. Stops with negative dwell
#'    times (departures earlier than arrivals) also get it;
#' 7. [interpolate_shape_dist_traveled()], only if the feed has a `shapes`
#'    table and `trips` has a `shape_id` column, replaces the
#'    `shape_dist_traveled` columns of `stop_times` and `shapes` with the
#'    distances, in meters, from the start of each shape. Existing values,
#'    whatever their unit, are replaced, and stops that can't be located along
#'    their trip's shape get `NA`.
#'
#' The `trips` and `stop_times` tables are always required, and `stops` is
#' required to cap speeds, to fill blank times and to calculate the distances
#' travelled along shapes. The warnings raised are those of the functions
#' above, so some warnings (e.g. about trips not linked to a shape) may be
#' raised more than once.
#'
#' @seealso [remove_duplicates()], [remove_unused_ids()],
#'   [fix_overnight_times()], [set_max_speed()],
#'   [interpolate_stop_times()], [set_min_dwell_time()],
#'   [interpolate_shape_dist_traveled()]
#'
#' @examplesIf requireNamespace("dplyr", quietly = TRUE)
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#' }
#' library(dplyr)
#'
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#'
#' gtfs <- read_gtfs(data_path)
#'
#' fixed_gtfs <- fix_gtfs(gtfs, max_speed = 40, min_dwell_time = 30)
#'
#' # duplicated agencies were removed, and the trip is now slower and stays at
#' # least 30 seconds at each intermediate stop
#' gtfs$agency
#' fixed_gtfs$agency
#'
#' gtfs$stop_times |>
#'   filter(trip_id == "CPTM L07-0") |>
#'   slice_tail(n = 1)
#'
#' fixed_gtfs$stop_times |>
#'   filter(trip_id == "CPTM L07-0") |>
#'   slice_tail(n = 1)
#' \dontshow{data.table::setDTthreads(old_dt_threads)}
#'
#' @export
fix_gtfs <- function(
  gtfs,
  max_speed = NULL,
  speed_unit = "km/h",
  min_dwell_time = NULL,
  dwell_time_unit = "s",
  overwrite_stop_times = FALSE
) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_number(
    max_speed,
    lower = .Machine$double.eps,
    finite = TRUE,
    null.ok = TRUE
  )
  checkmate::assert(
    checkmate::check_string(speed_unit),
    checkmate::check_names(speed_unit, subset.of = c("km/h", "m/s", "mph")),
    combine = "and"
  )
  checkmate::assert(
    checkmate::check_string(dwell_time_unit),
    checkmate::check_names(
      dwell_time_unit,
      subset.of = names(dwell_unit_factors)
    ),
    combine = "and"
  )
  checkmate::assert_number(
    min_dwell_time,
    lower = 0,
    upper = max_time_secs / dwell_unit_factors[[dwell_time_unit]],
    null.ok = TRUE
  )
  checkmate::assert_logical(overwrite_stop_times, len = 1, any.missing = FALSE)

  # remove duplicates first, so the other steps don't see repeated rows
  gtfs_fixed <- remove_duplicates(gtfs)

  # remove unused ids
  gtfs_fixed <- remove_unused_ids(gtfs_fixed)

  # fix times after midnight before the steps that use the times, which skip
  # the spans that go back

  gtfs_fixed <- fix_overnight_times(gtfs = gtfs_fixed)

  # cap max speed. this is done before interpolating, so the interpolated
  # times follow the capped times

  if (!is.null(max_speed)) {
    gtfs_fixed <- set_max_speed(
      gtfs_fixed,
      max_speed = max_speed,
      unit = speed_unit
    )
  }

  # fill blank stop times, or overwrite the times of intermediate stops

  gtfs_fixed <- interpolate_stop_times(
    gtfs = gtfs_fixed,
    overwrite = overwrite_stop_times
  )

  # set a minimum dwell time at intermediate stops. this is done after
  # interpolating, so the filled stops also get it. 'stop_times' is not the
  # caller's table: the earlier steps return new tables

  if (!is.null(min_dwell_time)) {
    gtfs_fixed <- set_min_dwell_time(
      gtfs_fixed,
      min_dwell_time = min_dwell_time,
      unit = dwell_time_unit,
      by_reference = TRUE
    )
  }

  # interpolate shape_dist_traveled. feeds without shapes have nothing to be
  # measured along, so the step is skipped

  if (has_shapes(gtfs_fixed)) {
    gtfs_fixed <- interpolate_shape_dist_traveled(gtfs_fixed)
  }

  return(gtfs_fixed)
}
