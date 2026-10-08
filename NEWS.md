# gtfstools (development version)

## Potentially breaking changes

- The new `first_stop`, `last_stop`, `from` and `to` arguments of `set_trip_speed()` come before `by_reference`, which must now be passed by name (#89).
- `filter_by_sf()`, deprecated in version 1.3.0 in favour of `filter_by_spatial_extent()`, is now defunct: calling it raises an error (class `gtfstools_defunct_filter_by_sf_error`). Use `filter_by_spatial_extent()` instead, which takes the same arguments.
- The `full_trips` argument of `filter_by_stop_id()`, deprecated in version 1.3.0, is now defunct: using it, with any value, raises an error (class `gtfstools_defunct_full_trips_error`). The function now always behaves as with the former `full_trips = FALSE`, filtering by the specified stops instead of keeping the entire trips that pass through them. To keep entire trips, subset `stop_times` by `stop_id` and pass the resulting `trip_id`s to `filter_by_trip_id()` (#75).
- The trip length and speed functions were reorganised:
  - `get_trip_length()` now returns the length of each trip from its first to its last stop, so lengths along shapes are usually shorter than before. The length of entire shapes is now returned by the new `get_shape_length()`.
  - `get_trip_speed()` and `set_trip_speed()` use these lengths, so they ignore the parts of the shapes before the first and after the last stop: speeds are usually slightly lower than before, and `set_trip_speed()` sets slightly shorter durations for the same speed.
  - The outputs of `get_trip_length()` and `get_trip_speed()` no longer have an `origin_file` column.
  - The new `method` and `by` arguments come right after `trip_id`, so `unit`, `sort_sequence` and the deprecated `file` must now be passed by name (e.g. `get_trip_length(gtfs, trip_id, unit = "m")`).
  - Without a `shapes` table or a `trips$shape_id` column, these functions now use straight-line lengths between stops, with a warning (class `gtfstools_shapes_unavailable`), instead of raising an error. Trips without a usable shape get `NA` lengths and speeds, with a warning, and are left unchanged by `set_trip_speed()`.
  - `get_trip_speed()` and `set_trip_speed()` now also require the `stops` table.
  - Lengths are now haversine distances on the `{s2}` sphere, regardless of `sf::sf_use_s2()`. They match the previous ones with `sf_use_s2(TRUE)`; with `sf_use_s2(FALSE)`, the previous ellipsoidal lengths differed by up to 0.4%.
- `get_trip_geometry()` was reorganised in the same way, so that its geometries match the lengths returned by `get_trip_length()`:
  - The new `method` argument replaces `file`. With `method = "shapes"` (the default), geometries are now the part of the trip's shape between its first and last stops, instead of the entire shape. With `method = "euclidean"`, geometries link the trip's stops along straight lines, as with the former `file = "stop_times"`. Use `convert_shapes_to_sf()` for the geometry of entire shapes.
  - Each trip now gets a single geometry, so the output no longer has an `origin_file` column. To compare both methods, call the function once with each of them.
  - `method` comes right after `trip_id`, so a `file` passed by position is now taken as `method` (`"stop_times"` raises an error). The deprecated `file` must be passed by name.
  - Both methods now require the `stop_times` and `stops` tables, and `method = "euclidean"` no longer requires `trips`. Without a `shapes` table or a `trips$shape_id` column, `method = "shapes"` uses straight lines between stops, with a warning (class `gtfstools_shapes_unavailable`), instead of raising an error.
  - Only trips listed in `stop_times` are returned, and the warning about `trip_id`s that don't exist now checks `stop_times` instead of `trips`.
  - Stops with missing coordinates, or not listed in `stops`, are now ignored, instead of producing geometries with `NA` coordinates. Trips without a usable shape (including those whose `shape_id` is blank) now get an empty geometry with `method = "shapes"`, with a warning (class `gtfstools_trips_without_shape`). Previously, trips whose `shape_id` was blank were dropped.
  - With `method = "shapes"`, the stops of each trip are now located along its shape, so the function takes about as long as `get_trip_length()`: on a feed with 15,000 trips and 920,000 `stop_times` rows, about 0.8 seconds instead of 0.02 seconds for the entire shapes. `convert_shapes_to_sf()` is still the fastest way to get the geometry of entire shapes. With `method = "euclidean"`, the function is slightly slower than with the former `file = "stop_times"` (about 1.2 times on the same feed).
- `filter_by_time_of_day(keep = TRUE, update_frequencies = TRUE)` now sets the `end_time` of `frequencies` entries that cross `to` to one second after `to` (e.g. `"07:00:01"` instead of `"07:00:00"`), see Bug fixes.
- `frequencies_to_stop_times()` no longer creates a trip departing at the `end_time` of `frequencies` entries, so entries whose duration is a multiple of `headway_secs` now yield one trip fewer (see Bug fixes).
- The `sort_sequence` argument of `convert_shapes_to_sf()`, `get_trip_geometry()`, `get_trip_length()`, `get_trip_speed()`, `get_trip_segment_duration()` and `get_stop_times_patterns()` now defaults to `TRUE`. Results only change for feeds whose `shapes` or `stop_times` are not ordered by `shape_pt_sequence`/`stop_sequence`, in which case the previous output was incorrect. As a consequence, these columns are now required by default. Use `sort_sequence = FALSE` to restore the previous behaviour (#94).
- Malformed time strings (e.g. `"5:30"`, `"abc"`, `"12:60:00"`, hours too large to be stored) are now converted to `NA` with a warning by all functions that convert times to seconds, instead of silently becoming wrong values. Blank times still become `NA` silently. `filter_by_time_of_day()` now also rejects `from`/`to` values with minutes or seconds of 60 or more.
- `get_stop_times_patterns(type = "spatiotemporal")` may return different pattern ids for feeds with blank intermediate stop times, which are now correctly accounted for (see Bug fixes).
- The `filter_by_*()` functions may now return more rows, as they no longer drop rows with blank optional keys, station entrances, generic nodes and boarding areas of kept stations and platforms, and the `agency` of single-agency feeds (see Bug fixes). `filter_by_trip_id()`, `filter_by_stop_id()`, `filter_by_spatial_extent()` and `filter_by_time_of_day()` may also return fewer `fare_attributes` and `agency` rows, as they now drop the fares whose `fare_rules` are all dropped by zone.
- Invalid dates (e.g. `20240230`) are still converted to `NA` when reading or converting feeds, but now raise a warning (class `gtfstools_invalid_date`) listing the invalid values.
- `frequencies_to_stop_times()` now raises an informative error (class `gtfstools_invalid_frequencies`) when `frequencies` has invalid entries (missing or malformed `start_time`/`end_time`, `end_time` before `start_time`, or a missing or non-positive `headway_secs` while `start_time` and `end_time` differ), and another one (class `gtfstools_empty_template`) when a trip to be converted has no `departure_time` in `stop_times`. Previously, these cases failed with obscure errors. Duplicated values in its `trip_id` argument are now converted only once.
- `filter_by_spatial_extent()` now filters the feed by the selected trips only once, instead of filtering it by shapes and by trips separately and merging the results. As a consequence, shapes not used by any trip are no longer kept, duplicated rows of the given feed are no longer removed, and rows keep the order of the given feed (see Bug fixes).

## Bug fixes

- Fixed bug in `filter_by_trip_id()` (and the filters built on it: `filter_by_stop_id()`, `filter_by_spatial_extent()` and `filter_by_time_of_day()`) that kept `fare_attributes` (and their agencies) whose `fare_rules` were all dropped by zone.
- Fixed bug in `filter_by_time_of_day()` that, with `keep = TRUE`, set the `end_time` of `frequencies` entries that cross `to` to `to`. Since `end_time` is exclusive, a departure exactly at `to` was lost when converting the filtered feed with `frequencies_to_stop_times()`, although `filter_by_time_of_day()` keeps times equal to `to`. `end_time` is now set to one second after `to`.
- Fixed bug in `frequencies_to_stop_times()` that created a trip departing at the `end_time` of `frequencies` entries whose duration is a multiple of `headway_secs`. As required by the GTFS specification, `end_time` is now exclusive: an entry from 08:00 to 09:00 with a 30 minutes headway yields trips departing at 08:00 and 08:30 only. Entries with equal `start_time` and `end_time` still yield a single trip.
- Fixed bug in `filter_by_route_id()` (and therefore `filter_by_route_type()`) that filtered `fare_rules` by `level_id`s instead of `route_id`s, dropping the kept routes' fares with `keep = TRUE` and keeping the dropped routes' fares with `keep = FALSE`.
- Fixed bug in `get_stop_times_patterns()` that ignored stop timing when identifying spatiotemporal patterns of trips with any blank stop time.
- Fixed bug in `filter_by_time_of_day()` that, with `keep = FALSE` and `full_trips = TRUE`, dropped every trip with an untimed stop, even trips entirely outside the time window.
- Fixed bug in `as_dt_gtfs()` that turned date fields that were already `Date` into `NA`.
- Fixed bug in the `filter_by_*()` functions that dropped zone `fare_rules` without `route_id`, `transfers` without `from_stop_id`/`to_stop_id` and `attributions` without `agency_id`, whose blank keys mean "applies to all".
- Fixed bug in `filter_by_trip_id()` and the other filters built on trips and routes that emptied `agency` in single-agency feeds whose `routes.agency_id` is blank or absent.
- Fixed bug in `filter_by_trip_id()`, `filter_by_route_id()`, `filter_by_service_id()`, `filter_by_shape_id()` and `filter_by_agency_id()` (and the filters built on them) that dropped station entrances, generic nodes and boarding areas of kept stations and platforms, together with their pathways and levels.
- Fixed bug in `set_trip_speed()` that identified the first stop of each trip by its row position instead of its `stop_sequence`, producing wrong times for feeds whose `stop_times` are not ordered.
- Fixed bug in `get_children_stops()` that returned rows with `NA` values for stops whose `parent_station` is `NA`.
- Fixed bug in `read_gtfs()` that kept doubled quotes (`""`) inside quoted text fields, which `write_gtfs()` then doubled again on every read/write round trip.
- Fixed bug in `set_trip_speed()` that left existing `*_secs` columns (e.g. created by `convert_time_to_seconds()`) out of sync with the updated times, so functions such as `get_trip_speed()` reported the old speeds.
- Fixed bug in `merge_gtfs()` that prefixed the `field_value` and `record_sub_id` columns of `translations`, so those translations no longer matched their records.
- Fixed bug in `get_trip_segment_duration()` that mixed up trips whose `stop_times` rows are interleaved when `sort_sequence = FALSE`. It also no longer deletes a user column named `last_stop_departure`.
- Fixed bug in `filter_by_time_of_day()` that did not update the `start_time` of `frequencies` entries with a blank `exact_times`, which should be treated as `0`.
- Fixed bug in `filter_by_time_of_day()` that returned frequency-based trips whose `frequencies` entries were all filtered out, as if they were scheduled trips.
- Fixed bug in `convert_time_to_seconds()` that checked for the wrong column before converting `end_time` and `arrival_time`, silently skipping them or raising an error when only one column of a pair was present.
- Fixed bug in `write_gtfs()` that wrote text read with `read_gtfs(encoding = "Latin-1")` back as Latin-1 instead of UTF-8, as required by the GTFS specification.
- Fixed bug in `as_dt_gtfs()` that did not convert the date fields of lists to `Date`, producing objects that `write_gtfs()` would reject.
- Fixed the documentation of `filter_by_time_of_day()`, which stated that `update_frequencies` defaults to `FALSE` (it defaults to `TRUE`).
- Fixed bug in `merge_gtfs()` that errored when columns were are of type character (unknown). PR contribution by @gmatosferreira.
- Fixed bug that was leading to drop parent station ids in `merge_gtfs()`. PR contribution by @gmatosferreira and @haneroglu.
- Fixed bug in `filter_by_spatial_extent()` that raised an error (`Can't unproject point with nan`) when a trip's stops had missing coordinates, or were not listed in `stops`. These stops are now ignored when selecting trips by their stops.
- Fixed bug in `filter_by_spatial_extent()` that, with `keep = FALSE`, kept trips selected only by their shapes or only by their stops, instead of dropping every selected trip.
- Fixed bug in `filter_by_stop_id(full_trips = FALSE)` that added a `.flagged` column to the `fare_rules` table of the given GTFS object when this table had a `contains_id` column but no `origin_id` and `destination_id` columns.
- Fixed bug in `get_stop_times_patterns()` that assigned the same pattern to trips with different sequences of stops when their `stop_id`s contained the `;` character (or `|`, with `type = "spatiotemporal"`).

## New features

- New function `stop_times_to_frequencies()`, the counterpart of `frequencies_to_stop_times()`, which converts scheduled trips into frequency-based ones (#69). Trips that share their route, service, direction, shape and sequence of stops are summarised, in each one-hour slot of the clock, by the trip that departs first and a `frequencies` entry whose `headway_secs` is based on the number of trips in that slot. The other trips are removed, so the conversion is a lossy approximation of the schedule. It is useful, for example, to make the `time_window` of `{r5r}` draw departure times for feeds without a `frequencies` table.
- New function `list_validator_versions()` which returns a df with the available CLI versions and their URLs. PR contribution by @baarthur
- New function `get_route_frequency()`, which returns the number of departures and the mean headway (in minutes) of each route within a time of day, by `service_id` (and by `direction_id`, when present in `trips`). It handles both trips listed in `frequencies`, whose departures are generated from their `start_time`, `end_time` and `headway_secs`, and scheduled trips, which depart at their earliest `stop_times` departure time. Departures are counted from `from` (included) to `to` (not included), so consecutive time windows don't count the same departure twice, and departures after midnight can be counted with times past `"24:00:00"` (#53).
- New function `get_stop_frequency()`, which returns the number of departures and the mean headway (in minutes) at each stop within a time of day, by `service_id`, and optionally by `route_id` and `direction_id` (`by_route = TRUE`). Each `stop_times` entry with a departure time counts as a departure from its stop, except for the last stop of each trip, and the entries of trips listed in `frequencies` are repeated at each of their departures. Unlike `get_route_frequency()`, which counts trips, it counts the departures from each stop, but it uses the same time of day as `get_route_frequency()`, from `from` (included) to `to` (not included).
- New function `remove_unused_ids()`, which removes unused ids from all files (#55).
- New function `get_calendar_overlap()`, which returns the periods in which all the given GTFS feeds have service, helping to pick a date on which several feeds can be analysed together (e.g. in routing and accessibility analyses). Feeds may be given as paths or as a list of GTFS objects, and `output = "plot"` returns a timeline of each feed's service days (requires `{ggplot2}`). See the new "Checking the calendar overlap of GTFS feeds" vignette (#85). Thanks @higgicd for the suggestion and the original `check_gtfs_overlap()` code.
- `frequencies_to_stop_times()` gains a `strategy` argument, which controls the departure times of the trips created from frequency-based `frequencies` entries (those whose `exact_times` is not `1`): `"exact"` (the default and previous behaviour) makes trips depart every `headway_secs` from `start_time`, while `"half_headway"` and `"random"` shift these departures by half the headway or by a random offset (#56).
- New function `get_shape_length()`, which returns the length of each shape.
- `get_trip_length()` and `get_trip_speed()` gain the `by` argument, to calculate lengths and speeds between each pair of consecutive stops (`by = "segment"`, numbered as in `get_trip_segment_duration()`), and the `method` argument, to measure along the trip's shape (`"shapes"`, handling loops correctly) or as straight lines between stops (`"euclidean"`).
- `write_gtfs()` gains a `compression_level` argument. It defaults to 6 (previously the feed was always compressed at level 9), which makes writing a feed about 2 to 3 times faster for files of very similar size. The content of the written files is unchanged.
- `set_trip_speed()` gains the `first_stop` and `last_stop` arguments, to set the speed only between two stops (later stops are shifted by the change in duration), and the `from` and `to` arguments, to change only trips that depart from the segment's first stop within a time of day (#89).
- New function `interpolate_stop_times()`, which fills blank `arrival_time`s and `departure_time`s in `stop_times`, assuming that vehicles travel at a constant speed between consecutive stops with known times. Distances between stops are measured along the trip's shape (`method = "shapes"`, the default) or as straight lines (`method = "euclidean"`), as in `get_trip_length()`. Unlike `tidytransit::interpolate_stop_times()`, it doesn't require a `shape_dist_traveled` column. Interpolated times are rounded to the nearest second, and stops before a trip's first or after its last known time are left blank, with a warning.

## Feature deprecation

- The `file` argument of `get_trip_geometry()`, `get_trip_length()` and `get_trip_speed()` is deprecated in favour of `method` (`file = "stop_times"` corresponds to `method = "euclidean"`). It is still accepted, with a warning (class `deprecated_file`), but must be passed by name.

## Notes
- gtfstools now requires `{units}` >= 1.0-1, which fixed an out-of-bounds read when converting empty vectors that was flagged by CRAN's sanitizer checks. `set_trip_speed()` also no longer converts speeds when `unit = "km/h"` or when no `trip_id` is given (#84).
- Function `download_validator()` now automatically detects the latest version available. PR contribution by @baarthur
- `get_children_stops()` is now much faster on large feeds (about 250x faster with 20,000 stops).
- Converting date fields when reading and writing feeds (`read_gtfs()`, `write_gtfs()`, `as_dt_gtfs()`) is now much faster (about 200x faster for the date conversion itself), noticeably speeding up `read_gtfs()` on feeds with large `calendar_dates` tables.
- Converting times between `"HH:MM:SS"` strings and seconds is now faster, as each distinct time is converted only once. This speeds up `convert_time_to_seconds()` (about 20 times faster on a feed with 900,000 `stop_times` rows), `filter_by_time_of_day()` (about 7 times faster on the same feed) and, to a lesser extent, the other functions that convert times.
- `get_trip_segment_duration()` and `get_trip_duration()` are much faster when `unit` is not `"s"` (about 60 and 10 times faster, respectively, on a feed with 900,000 `stop_times` rows).
- `frequencies_to_stop_times()` is much faster (about 13 times faster when converting a feed into 300,000 `stop_times` rows), as it creates all new trips at once instead of one at a time. It also no longer adds and then removes auxiliary columns from the tables of the given feed.
- `filter_by_spatial_extent()` is much faster and uses much less memory (about 25 times faster on a feed with 900,000 `stop_times` rows), as it filters the feed only once and doesn't create geometries for trips already selected by their shapes.
- `convert_sf_to_shapes()` is much faster (about 30 times faster with `calculate_distance = FALSE` and 70 times faster with `calculate_distance = TRUE` on a feed with 50,000 shape points), as it no longer casts the linestrings to points and calculates `shape_dist_traveled` with a vectorised haversine formula. Distances are calculated on the same sphere used by `{s2}`, so they match the previous results (with `sf::sf_use_s2(TRUE)`, the default) to within a micrometre. With `sf::sf_use_s2(FALSE)`, the previous version calculated ellipsoidal distances, which differ from the spherical ones by up to about 0.4%; distances are now always spherical.
- The table below shows how many times faster each function optimised above is, compared with the development version before these optimisations, on the example feeds shipped with the package (each stacked twice with `merge_gtfs()`). `get_trip_duration()` and `get_trip_segment_duration()` used `unit = "min"`, and `filter_by_spatial_extent()` used the western half of each feed's extent. The poa feed has no `frequencies` table. Differences under about 1.2 times are within measurement noise.

  | function | n times faster on poa | n times faster on spo |
  |---|---|---|
  | `convert_sf_to_shapes()` | 11.3 | 33.7 |
  | `convert_time_to_seconds()` | 5.8 | 1.3 |
  | `filter_by_spatial_extent()` | 2.9 | 1.9 |
  | `filter_by_time_of_day()` | 2.9 | 1.2 |
  | `frequencies_to_stop_times()` | – | 12.7 |
  | `get_trip_duration()` | 4.0 | 1.5 |
  | `get_trip_segment_duration()` | 50.1 | 2.8 |
  | `write_gtfs()` | 1.5 | 0.9 |
- The package documentation website moved to <https://ipea.github.io/gtfstools/> and the GitHub repository to <https://github.com/ipea/gtfstools>. All links were updated.
- The filtering vignette and the documentation now use `filter_by_spatial_extent()` instead of the defunct `filter_by_sf()`, which was moved to a "Defunct" section of the reference index.





# gtfstools 1.4.0

## New features

- `download_validator()` and `validate_gtfs()` now support using validator
  v5.0.0, v5.0.1 and v6.0.0.

## Notes

- Removed the local copies of `{cpp11}` functions, as the most recent releases
  fix the issues we were having.

# gtfstools 1.3.0

## New features

- New function `convert_sf_to_shapes()`.
- New generic function `as_dt_gtfs()` with methods for a few different classes
  (`tidygtfs`, `gtfs` and `list`).
- `{gtfstools}` functions now accepts GTFS objects created by other packages,
  such as `{gtfsio}` and `{tidytransit}`.
- `filter_by_route_type()` now accepts Google Transit's [extended route
  types](https://developers.google.com/transit/gtfs/reference/extended-route-types).
  Thanks @Ge-Rag.
- `convert_shapes_to_sf()`, `get_trip_geometry()`, `get_trip_length()`,
  `get_trip_speed()`, `get_trip_segment_duration()` and
  `get_stop_times_patterns()` now take an additional argument `sort_sequence`,
  used to indicate whether shapes/timetables should be ordered by
  `shape_pt_sequence`/`stop_sequence` when applying the functions' procedures.
- `download_validator()` and `validate_gtfs()` now support using validator
  v4.1.0 and v4.2.0.
- New parameters to `filter_by_stop_id()`: `include_children` and
  `include_parents`.

## Bug fixes

- Fixed a bug in `convert_to_standard()` in which the date fields from
  `feed_info` would not be converted back to an integer in their standard
  format (YYYYMMDD).
- Filtering functions now also filter the `transfers` table based on `trip_id`
  and `route_id`. Previously they would filter it based only on `stop_id`.
  Thanks Daniel Langbein (@langbein-daniel).
- Fixed a bug in `filter_by_route_id()` in which feeds with only one agency
  that omitted `agency_id` in `routes` and `fare_attributes` would end up with
  an empty `agency` table.
- `filter_by_sf()` now correctly throws an error when an unsupported function
  is passed to `spatial_operation`.

## Feature deprecation

- The `filter_by_stop_id()` behavior of filtering by trips that contain the
  specified stops has been deprecated. For backwards compatibility reasons,
  this behavior is still the default as of the current version and is
  controlled by the parameter `full_trips`. To actually filter by stop ids (the
  behavior that we now believe is the most appropriate), please use `full_trips
  = FALSE`. This behavior will be the default from version 2.0.0 onward. To
  achieve the old behavior, manually subset the stop_times table by `stop_id`
  and specify the `trip_id`s included in the output in `filter_by_trip_id()`.
- `filter_by_sf()` has been deprecated in favor of
  `filter_by_spatial_extent()`. For backwards compatibility reasons, usage of
  `filter_by_sf()` is still allowed as of the curent version, but the function
  will be removed from the package in version 2.0.0.

## Notes

- `validate_gtfs()` now defaults to run sequentially. Previously it would
  default to run parallelly using all available cores. Heavily inspired by
  Henrik Bengtsson post "Please Avoid detectCores() in your R packages"
  (https://www.jottr.org/2022/12/05/avoid-detectcores/).
- Improved performance of `seconds_to_string()` and, consequently, any other
  functions that use it.
- Improved performance and improved readability of most filtering functions.

# gtfstools 1.2.0

## New features

- New `validate_gtfs()` behavior. Now used to run MobilityData Canonical GTFS
  validator with a feed. The old behavior was marked as deprecated since
  v1.0.0.
- New function `download_validator()`.
- New vignette demonstrating how to validate feeds.

## Bug fixes

- Fixed a bug in `write_gtfs()` that prevented `as_dir = TRUE` to be used.
- Fixed a bug in `set_trip_speed()` that resulted in invalid stop_times tables
  when `max(stop_sequence)` was higher than the number of stops of a given
  trip. Thanks Alena Stern (@alenastern).
- Fixed a bug in `set_trip_speed()` that resulted in the speed of wrong
  trip_ids being updated because of the order that these ids would appear in
  the trips and stop_times tables. Thanks Alena Stern (@alenastern).

# gtfstools 1.1.0

## New features

- New function `convert_time_to_seconds()`.
- New function `filter_by_agency_id()`.
- New function `filter_by_service_id()`.
- New function `filter_by_time_of_day()`.
- New function `filter_by_weekday()`.
- New function `frequencies_to_stop_times()`.
- New function `get_children_stops()`.
- New function `get_stop_times_patterns()`.
- New function `get_trip_length()`.
- New parameter to `merge_gtfs()`: `prefix`. The `warnings` parameter was flagged as deprecated.
- Functions `get_parent_station()` and `get_children_stops` now accept `stop_id = NULL` to analyze all `stop_id`s in the `stops` table.

## Bug fixes

- Fixed a bug in which `get_trip_segment_duration()` would list wrong segment numbers, not necessarily starting from 1. Now segment numbers always range from 1 to N, where N is the total number of segments that compose each trip.
- Fixed a bug in `filter_by_{route,service,shape,trip}_id()` that resulted in the `agency` table not getting filtered when the specified id was `character(0)`.

## Notes

- Performance improvements to `get_trip_geometry()`, `get_trip_duration()`, `get_trip_segment_duration()` and `convert_shapes_to_sf()`.
- Stopped ordering points by `shape_pt_sequence`/`stop_sequence` in `get_trip_geometry()` and `convert_shapes_to_sf()`, since the GTFS reference says that the `stop_times` and `shapes` tables must be ordered by point/stop sequence anyway.
- Removed `{lwgeom}` from dependencies (Suggests), now that it's not required to run `get_trip_speed()` and `set_trip_speed()` anymore.
- Removed the `warnings` parameter from `read_gtfs()` and `write_gtfs()` and the `optional` and `extra` parameters from `write_gtfs()`, flagged as deprecated on gtfstools v1.0.0.
- Updated filtering vignette to demonstrate new functions.

# gtfstools 1.0.0

## New features

- New function `convert_stops_to_sf()`.
- New function `convert_shapes_to_sf()`.
- New function `filter_by_route_type()`.
- New function `filter_by_route_id()`. 
- New function `filter_by_sf()`. 
- New function `filter_by_shape_id()`.
- New function `filter_by_stop_id()`.
- New function `filter_by_trip_id()`. 
- New function `get_parent_station()`.
- New function `remove_duplicates()`.
- New parameters to `read_gtfs()`: `fields`, `skip` and `encoding`. The `warnings` parameter was flagged as deprecated.
- New parameters to `write_gtfs()`: `files`, `standard_only` and `as_dir`. They substitute the previously existent `optional` and `extra`, which were flagged as deprecated. The `warnings` parameter was flagged as deprecated too.
- New vignette exploring the filtering functions.

## Bug fixes

- `get_trip_speed()` and `set_trip_speed()` examples and tests now only run if `{lwgeom}` is installed. `{lwgeom}` is an `{sf}` "soft" dependency required by these functions, and is listed in `Suggests`. However, package checks would fail not so gracefully if it wasn't installed, which is now fixed.
- Fixed a bug in which the `crs` passed to `get_trip_geometry()` would be assigned to the result without actually reprojecting it.
- Changed the behaviour of `get_trip_geometry()` to not raise an error when the 'file' parameter is left untouched and the GTFS object doesn't contain either the shapes or the stop_times table. Closes [#29](https://github.com/ipea/gtfstools/issues/29).
- Fixed a bug that would cause `merge_gtfs()` to create objects that inherited only from `dt_gtfs` (ignoring `gtfs` and `list`).
- Fixed a bug in which `get_trip_speed()` returned `NA` speeds if the specified `trip_id` was listed in trips, but not in stop_times.
- Adjusted `set_trip_speed()` to stop raising a `max()`-related warning when none of the specified `trip_id`s exists.

## Notes

- Some utility functions previously provided by [`{gtfs2gps}`](https://github.com/ipea/gtfs2gps) will now be exported by `{gtfstools}`. Huge thanks to the whole `{gtfs2gps}` crew (Rafael Pereira @rafapereirabr, Pedro Andrade @pedro-andrade-inpe and João Bazzo @Joaobazzo)!
- The package now imports `{gtfsio}`, and many functions now heavily rely on it, such as `read_gtfs()` and `write_gtfs()`.
- Internal function `string_to_seconds()` now runs much faster thanks to Mark Padgham (@mpadge).
- `get_trip_geometry()` now runs much faster due to `data.table`-related optimizations.

## Potentially breaking changes

- Functions no longer validate GTFS objects on usage. `validate_gtfs()` will be flagged as deprecated as well, since I plan to heavily change its usability and outputs in future versions.
- `write_gtfs()` parameters went through major changes - the `optional` and `extra` params were flagged as deprecated and substituted by the more general `files` and `standard_only`.

# gtfstools 0.1.0

- Initial CRAN release.
