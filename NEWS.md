# gtfstools (development version)

## Breaking changes

- `filter_by_sf()`, deprecated in version 1.3.0, is now defunct. Use `filter_by_spatial_extent()`, which takes the same arguments.
- The `full_trips` argument of `filter_by_stop_id()`, deprecated in version 1.3.0, is now defunct, and the function always filters by the given stops. To keep entire trips, pass the `trip_id`s that serve these stops to `filter_by_trip_id()` (#75).
- `get_trip_length()` now measures each trip from its first to its last stop, instead of along its entire shape, so lengths are usually shorter. `get_trip_speed()` and `set_trip_speed()` use these lengths, so speeds are usually slightly lower, and they now also require the `stops` table. Use the new `get_shape_length()` for the length of entire shapes.
- `get_trip_geometry()` now returns, by default, the part of each trip's shape between its first and last stops, matching `get_trip_length()`, and requires the `stop_times` and `stops` tables. Use `convert_shapes_to_sf()` for entire shapes.
- `get_trip_geometry()`, `get_trip_length()` and `get_trip_speed()` now return one result per trip, without the `origin_file` column. Their new `method` argument (and `by`, in the last two) comes right after `trip_id`, so `unit`, `sort_sequence` and `file` must now be passed by name.
- The `by_reference` argument of `set_trip_speed()` must now be passed by name (#89).
- `sort_sequence` now defaults to `TRUE` in `convert_shapes_to_sf()`, `get_trip_geometry()`, `get_trip_length()`, `get_trip_speed()`, `get_trip_segment_duration()` and `get_stop_times_patterns()`, so the `shape_pt_sequence`/`stop_sequence` columns are required by default. Results only change for feeds not ordered by these columns, whose previous results were incorrect. Use `sort_sequence = FALSE` to restore the previous behaviour (#94).

## New features

- New function `filter_by_date()`, which filters a feed by the services that run on the given dates.
- New function `get_stops()`, which returns the stops visited by the given trips and/or routes.
- New function `get_stop_distances()`, which returns the great-circle distances between each pair of stops visited by the given trips and/or routes.
- New function `convert_stops_to_shapes()`, which creates shapes that link the consecutive stops of trips along straight lines, for trips not linked to a usable shape (or for the given trips), and assigns them to the trips.
- New function `get_dates()`, which returns the dates on which a feed has service, as `Date`s or as `"YYYYMMDD"` strings.
- New function `get_active_services()`, which returns the services active on the given dates.
- New function `get_start_and_end_times()`, which returns the earliest departure time and the latest arrival time in `stop_times`, optionally restricted to the given trips and dates.
- New functions `get_stop_timetable()` and `get_route_timetable()`, which return the timetables of the given stops and routes on the given dates: the stop times of the trips that run on each date, with the trip information.
- New function `get_calendar_overlap()`, which returns the number of trips each GTFS feed runs on each of its service days (counting the departures listed in `frequencies`) and whether all feeds have service on that day, helping to pick a date on which several feeds can be analysed together (e.g. in routing and accessibility analyses). With `resolution = "periods"`, it returns the periods in which all feeds have service, and `plot = TRUE` plots either result (requires `{ggplot2}`). Feeds may be given as paths or as a list of GTFS objects. See the new "Checking the calendar overlap of GTFS feeds" vignette (#85). Thanks @higgicd for the suggestion and the original `check_gtfs_overlap()` code.
- New functions `get_route_frequency()` and `get_stop_frequency()`, which return the number of departures and the mean headway of each route and at each stop within a time of day (#53).
- New function `stop_times_to_frequencies()`, the counterpart of `frequencies_to_stop_times()`, which approximates scheduled trips by frequency-based ones (#69).
- New function `interpolate_stop_times()`, which fills blank `arrival_time`s and `departure_time`s in `stop_times`, assuming a constant speed between stops with known times.
- New function `set_route_frequency()`, the editing counterpart of `get_route_frequency()`, which sets the headway of routes within a time of day by replacing their trips in it with a frequency-based template trip. Departures outside the time of day don't change.
- New functions `get_dwell_time()` and `set_dwell_time()`, which return and set how long vehicles stay at stops, optionally within a time of day. `set_dwell_time()` shifts the later times of each trip accordingly.
- New function `get_shape_length()`, which returns the length of each shape.
- New function `remove_unused_ids()`, which removes unused ids from all files (#55).
- New function `list_validator_versions()`, which lists the available validator versions. PR contribution by @baarthur.
- `get_trip_length()` and `get_trip_speed()` gain the `by` argument, to calculate lengths and speeds between consecutive stops. They and `get_trip_geometry()` gain the `method` argument, to measure along the trip's shape or as straight lines between stops. Without shapes, they now fall back to straight lines with a warning, instead of raising an error.
- `set_trip_speed()` gains the `first_stop`, `last_stop`, `from` and `to` arguments, to change speeds only between two stops and only for trips departing within a time of day (#89).
- `frequencies_to_stop_times()` gains the `strategy` argument, to shift the departures of frequency-based trips by half the headway or by a random offset (#56).
- `write_gtfs()` gains the `compression_level` argument. Its default, 6 (previously always 9), makes writing about 2 to 3 times faster for files of very similar size.

## Bug fixes

- The `filter_by_*()` functions no longer drop:
  - rows whose blank keys mean "applies to all": zone `fare_rules` without `route_id`, `transfers` without `from_stop_id`/`to_stop_id` and `attributions` without `agency_id`;
  - the `agency` of single-agency feeds whose `routes.agency_id` is blank or absent;
  - the station entrances, generic nodes and boarding areas of kept stations and platforms, with their pathways and levels.
- `filter_by_trip_id()` and the filters built on it no longer keep `fare_attributes` (and their agencies) whose `fare_rules` were all dropped by zone.
- `filter_by_route_id()` and `filter_by_route_type()` filtered `fare_rules` by `level_id` instead of `route_id`.
- `filter_by_time_of_day()`:
  - with `keep = TRUE`, now sets the `end_time` of `frequencies` entries that cross `to` to one second after `to`, so that a departure at `to` is no longer lost by `frequencies_to_stop_times()`;
  - updates the `start_time` of `frequencies` entries with a blank `exact_times`;
  - no longer returns frequency-based trips whose `frequencies` entries were all filtered out;
  - with `keep = FALSE` and `full_trips = TRUE`, no longer drops every trip with an untimed stop;
  - rejects `from`/`to` values with minutes or seconds of 60 or more.
- `filter_by_spatial_extent()` no longer errors when stops have missing coordinates, and with `keep = FALSE` drops every selected trip. It now filters the feed only once, so shapes not used by any trip are no longer kept and duplicated rows are no longer removed.
- `filter_by_stop_id()` no longer adds a `.flagged` column to the `fare_rules` table of the given feed.
- `frequencies_to_stop_times()` treats `end_time` as exclusive, as required by the GTFS specification: an entry from 08:00 to 09:00 with a 30-minute headway now yields trips at 08:00 and 08:30 only.
- Functions that convert times to seconds now convert malformed times (e.g. `"5:30"`, `"12:60:00"`) to `NA` with a warning, instead of silently returning wrong values. `convert_time_to_seconds()` also no longer skips `arrival_time` and `end_time` when only one column of a pair is present.
- `get_stop_times_patterns()` no longer ignores stop timing for spatiotemporal patterns of trips with blank stop times, and no longer merges different stop sequences whose `stop_id`s contain `;` or `|`.
- `set_trip_speed()` now identifies the first stop of each trip by `stop_sequence` instead of row position, and keeps existing `*_secs` columns in sync with the updated times.
- `get_trip_segment_duration()` no longer mixes up trips with interleaved `stop_times` rows when `sort_sequence = FALSE`.
- `get_children_stops()` no longer returns `NA` rows for stops without a `parent_station`.
- `read_gtfs()` no longer keeps doubled quotes inside quoted text fields, and `write_gtfs()` always writes text as UTF-8, also when the feed was read with `encoding = "Latin-1"`.
- `as_dt_gtfs()` no longer turns `Date` fields into `NA`, and converts the date fields of lists to `Date`.
- `merge_gtfs()` no longer prefixes the `field_value` and `record_sub_id` columns of `translations`, no longer errors with character columns of unknown type, and keeps parent station ids. PR contributions by @gmatosferreira and @haneroglu.

## Feature deprecation

- The `file` argument of `get_trip_geometry()`, `get_trip_length()` and `get_trip_speed()` is deprecated in favour of `method` (`file = "stop_times"` corresponds to `method = "euclidean"`).

## Notes

- gtfstools now requires `{units}` >= 1.0-1, which fixed an out-of-bounds read flagged by CRAN's sanitizer checks (#84).
- `download_validator()` now automatically detects the latest validator version. PR contribution by @baarthur.
- Invalid dates (e.g. `20240230`) are still converted to `NA` when reading or converting feeds, but now with a warning.
- `frequencies_to_stop_times()` now raises informative errors for invalid `frequencies` entries and for trips without a `departure_time`.
- Trip lengths are now always calculated on the `{s2}` sphere, regardless of `sf::sf_use_s2()`.
- `get_trip_geometry()` is slower with the default `method = "shapes"`, as it locates stops along shapes: on a feed with 15,000 trips and 920,000 `stop_times` rows, about 0.8 seconds instead of 0.02 seconds for the entire shapes.
- `get_stop_times_patterns()` is about 2 times faster on a feed with 1,700 `stop_times` rows, as trips are compared without building text keys from their stops and times. `get_trip_length()` and `get_trip_geometry()` also no longer build such keys when locating stops along shapes.
- `get_children_stops()` is now much faster on large feeds (about 250x faster with 20,000 stops).
- Converting date fields when reading and writing feeds (`read_gtfs()`, `write_gtfs()`, `as_dt_gtfs()`) is now much faster (about 200x faster for the date conversion itself), noticeably speeding up `read_gtfs()` on feeds with large `calendar_dates` tables.
- Converting times between `"HH:MM:SS"` strings and seconds is now faster, as each distinct time is converted only once. This speeds up `convert_time_to_seconds()` (about 20 times faster on a feed with 900,000 `stop_times` rows), `filter_by_time_of_day()` (about 7 times faster on the same feed) and, to a lesser extent, the other functions that convert times.
- `get_trip_segment_duration()` and `get_trip_duration()` are much faster when `unit` is not `"s"` (about 60 and 10 times faster, respectively, on a feed with 900,000 `stop_times` rows).
- `frequencies_to_stop_times()` is much faster (about 13 times faster when converting a feed into 300,000 `stop_times` rows), as it creates all new trips at once instead of one at a time. It also no longer adds and then removes auxiliary columns from the tables of the given feed.
- `filter_by_spatial_extent()` is much faster and uses much less memory (about 25 times faster on a feed with 900,000 `stop_times` rows), as it filters the feed only once and doesn't create geometries for trips already selected by their shapes.
- `convert_sf_to_shapes()` is much faster (about 30 times faster with `calculate_distance = FALSE` and 70 times faster with `calculate_distance = TRUE` on a feed with 50,000 shape points), as it no longer casts the linestrings to points and calculates `shape_dist_traveled` with a vectorised haversine formula. Distances are calculated on the same sphere used by `{s2}`, so they match the previous results (with `sf::sf_use_s2(TRUE)`, the default) to within a micrometre. With `sf::sf_use_s2(FALSE)`, the previous version calculated ellipsoidal distances, which differ from the spherical ones by up to about 0.4%; distances are now always spherical.
- The table below shows how many times faster each function optimised above is, compared with the development version before these optimisations, on the example feeds shipped with the package (each stacked twice with `merge_gtfs()`). `get_trip_duration()` and `get_trip_segment_duration()` used `unit = "min"`, `filter_by_spatial_extent()` used the western half of each feed's extent, and `filter_by_time_of_day()` kept the period from 07:00 to 09:00. The poa feed has no `frequencies` table. Differences under about 1.2 times are within measurement noise.

  | function | n times faster on poa | n times faster on spo |
  |---|---|---|
  | `convert_sf_to_shapes()` | 7.8 | 20.8 |
  | `convert_time_to_seconds()` | 4.3 | 1.1 |
  | `filter_by_spatial_extent()` | 5.9 | 2.3 |
  | `filter_by_time_of_day()` | 2.6 | 1.0 |
  | `frequencies_to_stop_times()` | – | 7.6 |
  | `get_stop_times_patterns()` | 2.1 | 2.1 |
  | `get_trip_duration()` | 3.6 | 1.1 |
  | `get_trip_segment_duration()` | 21.7 | 2.1 |
  | `write_gtfs()` | 1.5 | 1.6 |
- The package documentation website moved to <https://ipea.github.io/gtfstools/> and the GitHub repository to <https://github.com/ipea/gtfstools>. All links were updated.

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
