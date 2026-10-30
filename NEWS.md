# gtfstools (development version)

## New features

- `interpolate_stop_times()` gains `overwrite` and `keep_dwell_times`. With `overwrite = TRUE`, the times of every stop between the first and the last stop of each trip are replaced by interpolated ones, instead of only the blank ones. By default (`keep_dwell_times = TRUE`), these stops keep their original dwell times.

## Bug fixes

- gtfstools functions now accept `dt_gtfs` objects whose tables were turned into tibbles, grouped data frames or plain data frames by other packages (e.g. after `dplyr::group_by()`), converting them back to `data.table` without modifying the input. `as_dt_gtfs()` does the same conversion. With `by_reference = TRUE`, an object with any such table now raises an informative error, since the edits can't be made by reference on a converted copy: convert it first with `as_dt_gtfs()` (#130, reported by @baarthur, who also opened PR #132).

# gtfstools 2.0.0

## Breaking changes

- With `prefix = FALSE`, the default, `merge_gtfs()` now keeps rows that are identical in every column only once and raises an error when the GTFS objects share ids whose data differ (e.g. a `stop_id` with different coordinates, or a `trip_id` with different `stop_times`), which used to produce inconsistent feeds. Merging a feed with itself now works, but merging versions of the same feed, or feeds with simple ids (e.g. both with an `agency_id` `"1"`), usually raises the error: use `prefix = TRUE`. A character `prefix` must now have unique elements.
- `filter_by_sf()` and the `full_trips` argument of `filter_by_stop_id()`, deprecated in version 1.3.0, are now defunct. Use `filter_by_spatial_extent()`, which takes the same arguments. `filter_by_stop_id()` now always keeps only the `stop_times` entries at the given stops (by default, it used to keep entire trips): to keep entire trips, pass the `trip_id`s that serve the stops to `filter_by_trip_id()` (#75).
- `get_trip_length()` now measures each trip from its first to its last stop, instead of along its entire shape, so lengths are usually shorter, and the speeds of `get_trip_speed()` and `set_trip_speed()` slightly lower. Likewise, `get_trip_geometry()` now returns, by default, the part of the shape between the first and last stops. These functions now require the `stops` table (and `get_trip_length()` and `get_trip_geometry()` also `stop_times`). Use the new `get_shape_length()` and `get_shapes_geometry()` for entire shapes.
- `get_trip_geometry()`, `get_trip_length()` and `get_trip_speed()` now return one result per trip, without the `origin_file` column. Their new `method` argument (and `by`, in the last two) comes right after `trip_id`, so `unit` and `file` must be passed by name. `get_trip_speed()` also returns `route_id` as its first column, and so requires the `trips` table.
- The `by_reference` argument of `set_trip_speed()` must now be passed by name (#89).

## Feature deprecation

- `convert_shapes_to_sf()` and `convert_stops_to_sf()` are deprecated in favour of `get_shapes_geometry()` and `get_stops_geometry()`, which take the same arguments (except `sort_sequence`) and return the same results.
- The `file` argument of `get_trip_geometry()`, `get_trip_length()` and `get_trip_speed()` is deprecated in favour of `method` (`file = "stop_times"` is `method = "euclidean"`).

## New features

- New functions to query feeds:
  - `get_summary()` summarises a feed (files, agencies, service calendar, totals including the vehicle-kilometres travelled, and the distributions of trip speeds, trip lengths and route headways), optionally restricted to some dates, routes, modes, agencies and a time of day, as a list of `data.table`s and an HTML report (requires `{ggplot2}`, `{knitr}`, `{rmarkdown}` and Pandoc). `by_route_type = TRUE` breaks results down by transport mode (#127), and `unit = "mph"` reports miles and mph.
  - `get_vkt()` and `get_vmt()` return the vehicle-kilometres (or vehicle-miles) travelled by each route, counting every departure (including those in `frequencies`) on every day its service runs, optionally restricted to some dates and a time of day.
  - `get_route_frequency()` and `get_stop_frequency()` return the number of departures and the mean headway of each route and at each stop within a time of day (#53).
  - `get_route_speed()` returns the minimum, mean, median, maximum and standard deviation of the trip speeds of each route.
  - `get_route_geometry()` returns the distinct trip geometries of each route (e.g. each direction and short-turn service), with the number of trips that follow each.
  - `get_shape_length()`, `get_shapes_geometry()` and `get_stops_geometry()` return the length of each shape and the shapes and stops as `sf` objects.
  - `get_stops()` and `get_stop_distances()` return the stops visited by the given trips and/or routes and the great-circle distances between each pair of them.
  - `get_dates()`, `get_active_services()` and `get_start_and_end_times()` return the dates with service, the services active on given dates, and the earliest departure and latest arrival times.
  - `get_stop_timetable()` and `get_route_timetable()` return the timetables of stops and routes on given dates.
  - `get_dwell_time()` returns how long vehicles stay at stops, optionally within a time of day.
  - `get_calendar_overlap()` returns the number of trips each feed runs on each service day and whether all feeds have service on it (or, with `resolution = "periods"`, the periods in which all of them do), to pick a date on which several feeds can be analysed together. `plot = TRUE` plots the result (requires `{ggplot2}`). See the new vignette "Checking the calendar overlap of GTFS feeds" (#85). Thanks @higgicd for the suggestion and the original `check_gtfs_overlap()` code.
- New functions to edit feeds:
  - `set_route_frequency()` sets the headway of routes within a time of day, replacing their trips in it with a frequency-based template trip. Departures outside the time of day don't change.
  - `set_route_speed()` sets the average speed of all trips of the given routes, as `set_trip_speed()` does for trips.
  - `set_dwell_time()`, `set_min_dwell_time()` and `set_max_speed()` set dwell times, raise dwell times at intermediate stops to a minimum and cap trip speeds, shifting the later times of each trip accordingly. The dwell times can be set within a time of day, and speeds capped only between two stops or for trips departing within a time of day, as in `set_trip_speed()`. Like `set_trip_speed()` and `set_route_speed()`, they and `set_route_frequency()` can be restricted to some transport modes with `route_type`.
  - `interpolate_stop_times()` fills blank arrival and departure times, assuming a constant speed between stops with known times.
  - `interpolate_shape_dist_traveled()` (re)calculates `shape_dist_traveled` in `stop_times` and `shapes`, in meters.
  - `stop_times_to_frequencies()`, the counterpart of `frequencies_to_stop_times()`, approximates scheduled trips by frequency-based ones (#69).
  - `convert_stops_to_shapes()` creates straight-line shapes between consecutive stops for trips without a usable shape.
  - `combine_nearby_stops()` combines the stops within a given distance of each other (after merging platforms into their stations), updating every file that refers to them. Entrances, generic nodes, boarding areas and `pathways` are removed.
  - `crop_gtfs()` crops a feed to a spatial extent. Unlike `filter_by_spatial_extent()`, which keeps entire trips, it cuts the trips that leave the extent (interpolating blank times at their new ends and shifting their `frequencies`) and, by default, trims their shapes (#44). Thanks @luukvdmeer for the proposal and discussion.
  - `remove_unused_ids()` removes unused ids from all files (#55).
  - `fix_gtfs()` cleans a feed in one call: it removes duplicated rows and unused ids, interpolates blank stop times, recalculates `shape_dist_traveled` in feeds with shapes, and optionally caps trip speeds and sets a minimum dwell time.
- New function `build_graph()`, which builds a frequency-based transit network from the trips departing within a time of day, as General Modeling Network Specification (GMNS) tables or as an `{igraph}` or `{tidygraph}` graph, with in-vehicle, boarding, alighting and walking transfer links. See the new vignette "Building transit network graphs".
- New functions `filter_by_date()` and `filter_by_period()`, which keep the services that run on given dates or in a period. By default (`trim = TRUE`), `filter_by_period()` trims the calendars to the period.
- New function `convert_seconds_to_time()`, the counterpart of `convert_time_to_seconds()`.
- New function `list_validator_versions()`. PR contribution by @baarthur.
- `get_trip_length()` and `get_trip_speed()` gain the `by` argument, to calculate lengths and speeds between consecutive stops. They and `get_trip_geometry()` gain the `method` argument, to measure along shapes or along straight lines between stops, and, without shapes, now fall back to straight lines with a warning instead of an error.
- `set_trip_speed()` gains `first_stop`, `last_stop`, `from` and `to`, to change speeds only between two stops and for trips departing within a time of day (#89), and `route_type`, so `trip_id` is now optional.
- `get_trip_speed()` and `set_trip_speed()` accept `unit = "mph"`.
- `get_trip_speed()`, `get_route_speed()`, `get_trip_duration()`, `get_trip_length()` and `get_trip_segment_duration()` gain `from` and `to`, as in `get_dwell_time()`, to include only the trips (or segments) that depart within a time of day.
- `frequencies_to_stop_times()` gains `strategy`, to shift departures by half the headway or by a random offset (#56).
- `write_gtfs()` gains `compression_level`. Its default, 6 (previously always 9), makes writing about 2 to 3 times faster, with files of very similar size.
- The `path` argument of `download_validator()` now defaults to `tempdir()`.
- New vignettes "Editing GTFS feeds", "Querying GTFS feeds" and "Mapping GTFS feeds".

## Bug fixes

- `merge_gtfs()`:
  - no longer prefixes ids with `"NA_"` when the GTFS objects are passed with names (e.g. `merge_gtfs(a = gtfs1, b = gtfs2, prefix = TRUE)`);
  - no longer prefixes the `field_value` and `record_sub_id` columns of `translations`, no longer errors with character columns of unknown type, and keeps parent station ids. PR contributions by @gmatosferreira and @haneroglu.
- `merge_gtfs()` and `remove_duplicates()` no longer corrupt elements that are not tables, such as the `locations` of GTFS-Flex feeds (`merge_gtfs()` leaves them out, with a warning).
- `download_validator()` and `list_validator_versions()` now fail gracefully on network problems, as CRAN requires: they retry transient failures and then inform with a message (class `gtfstools_validator_download_failure`) and invisibly return `NULL`, instead of raising an error (`download_validator()` used to raise a misleading "invalid URL" one). A version that doesn't exist raises an error of class `gtfstools_invalid_validator_version`.
- `download_validator()` downloads the validator once instead of twice, doesn't go online when an explicit `version` is already in `path`, and shows a progress bar with `quiet = FALSE`. `list_validator_versions()` returns its result visibly.
- `get_trip_duration()`, `get_trip_segment_duration()`, `filter_by_time_of_day()`, `filter_by_stop_id()` and `frequencies_to_stop_times()` no longer add temporary columns to the tables of the given feed.
- The `filter_by_*()` functions no longer drop:
  - rows whose blank keys mean "applies to all": zone `fare_rules` without `route_id`, `transfers` without `from_stop_id`/`to_stop_id` and `attributions` without `agency_id`;
  - the `agency` of single-agency feeds whose `routes.agency_id` is blank or absent;
  - the station entrances, generic nodes and boarding areas of kept stations and platforms, with their pathways and levels;
  - every `fare_attributes` entry of feeds without `fare_rules`. In multi-agency feeds, they keep the fares of the agencies whose routes were kept, and those without an agency.
- `filter_by_agency_id()` now keeps the `fare_attributes` without an `agency_id`.
- `filter_by_trip_id()`, `filter_by_service_id()`, `filter_by_shape_id()` and the functions built on them no longer keep `fare_attributes` (and their agencies) whose `fare_rules` were all dropped by zone.
- `filter_by_route_id()` and `filter_by_route_type()` filtered `fare_rules` by `level_id` instead of `route_id`.
- `filter_by_time_of_day()`:
  - with `keep = TRUE`, sets the `end_time` of `frequencies` entries that cross `to` to one second after it, so `frequencies_to_stop_times()` no longer loses a departure at `to`;
  - keeps `frequencies` entries that start exactly at `to` (this also affects `get_summary()`);
  - with `keep = FALSE`, drops a departure at `to`, and removes entries left without departures;
  - updates the `start_time` of `frequencies` entries with a blank `exact_times`, and no longer returns frequency-based trips whose entries were all filtered out;
  - with `keep = FALSE` and `full_trips = TRUE`, no longer drops every trip with an untimed stop;
  - rejects `from`/`to` with minutes or seconds of 60 or more;
  - no longer modifies the `frequencies` table of the given feed when all of its entries are selected.
- `filter_by_spatial_extent()` no longer errors when stops have missing coordinates, drops every selected trip with `keep = FALSE`, no longer keeps unused shapes nor removes duplicated rows, and treats a `bbox` as a rectangle in longitude and latitude, instead of a slightly larger polygon with curved edges. It no longer accepts `sf::st_equals_exact()` and `sf::st_is_within_distance()` as `spatial_operation`, since they always failed.
- `frequencies_to_stop_times()` treats `end_time` as exclusive, as the GTFS specification requires (from 08:00 to 09:00 every 30 minutes now yields 08:00 and 08:30 only), and sets arrivals that a dwell time at the first stop would put before 00:00:00 to 00:00:00, instead of raising an error.
- Malformed times (e.g. `"5:30"`, `"12:60:00"`) and non-ASCII strings marked as `"bytes"` are converted to `NA` with a warning, instead of wrong values or an error. `convert_time_to_seconds()` no longer skips `arrival_time` and `end_time` when only one column of a pair is present.
- `get_stop_times_patterns()` no longer ignores stop timing in the spatiotemporal patterns of trips with blank stop times, and no longer merges different stop sequences whose `stop_id`s contain `;` or `|`.
- `set_trip_speed()` identifies the first stop of each trip by `stop_sequence` instead of row position, keeps existing `*_secs` columns in sync, and raises an error when `speed` is zero, negative or infinite, or when a trip is given different speeds.
- `get_trip_duration()` returns `NA` with a warning (also raised by `get_trip_speed()`) for trips without any arrival or departure time, instead of `-Inf` or an error.
- Functions that measure trips along shapes raise an informative error when a used shape has a blank `shape_id`. `get_trip_length()`, `get_trip_speed()` and `get_trip_geometry()` ignore `stop_times` entries with a missing or blank `trip_id`, which used to shift the segments of other trips with `by = "segment"`.
- `get_children_stops()` no longer returns `NA` rows for stops without a `parent_station`.
- `read_gtfs()` no longer keeps doubled quotes inside quoted text fields, and `write_gtfs()` always writes UTF-8, also for feeds read with `encoding = "Latin-1"`.
- `as_dt_gtfs()` no longer turns `Date` fields into `NA`, and converts the date fields of lists to `Date`.
- The documentation of `filter_by_stop_id()` now says that it keeps (or drops) the `stop_times` entries at the given stops, not entire trips.
- `convert_shapes_to_sf()`, `get_trip_geometry()`, `get_trip_length()`, `get_trip_speed()`, `get_trip_segment_duration()` and `get_stop_times_patterns()` now always order `shapes` and `stop_times` by `shape_pt_sequence`/`stop_sequence`, which are therefore required. Results only change for feeds not ordered by these columns, which were previously wrong. Their `sort_sequence` argument is deprecated: `TRUE` raises a warning and `FALSE` an error (#94).

## Notes

- Many functions are faster. The table below shows how many times faster than in version 1.4.0 each function of that version is, on the example feeds `poa` and `spo` stacked twice with `merge_gtfs()` (up to 46,000 `stop_times` rows), with the default number of threads. Values below 1 mean slower, and ~1 a difference under 1.2 times (measurement noise); functions not listed are ~1 on both feeds, except `get_children_stops()` and `get_parent_station()` (the feeds have no `parent_station`), `validate_gtfs()` and `download_validator()`, which were not measured. `poa` has no `frequencies`. Functions marked with † now do different work (see "Breaking changes"): `merge_gtfs()` checks the ids shared by the GTFS objects (with `prefix = TRUE`, it is 1.2 to 1.8 times faster), and `get_trip_geometry()` cuts shapes at the trips' first and last stops. On these small feeds, fixed costs dominate: `as_dt_gtfs()` now converts integer dates (about 1 to 2 milliseconds), `filter_by_trip_id()` and `filter_by_weekday()` take about 7 milliseconds more, and the deprecated `convert_shapes_to_sf()` and `convert_stops_to_sf()` raise a warning, while their replacements, `get_shapes_geometry()` and `get_stops_geometry()`, are about as fast as they were.

  | function | n times faster on poa | n times faster on spo |
  |---|---|---|
  | `as_dt_gtfs()` | 0.3 | 0.7 |
  | `convert_sf_to_shapes()` | 11 | 65 |
  | `convert_shapes_to_sf()` | 0.1 | 0.4 |
  | `convert_stops_to_sf()` | 0.2 | 0.4 |
  | `convert_time_to_seconds()` | 3.1 | 1.7 |
  | `filter_by_agency_id()` | ~1 | 1.3 |
  | `filter_by_route_id()` | ~1 | 3.3 |
  | `filter_by_route_type()` | ~1 | 2.5 |
  | `filter_by_shape_id()` | 0.7 | 1.3 |
  | `filter_by_spatial_extent()` | 2.5 | 3.1 |
  | `filter_by_stop_id()` | 3.6 | 3.0 |
  | `filter_by_time_of_day()` | 1.4 | 1.7 |
  | `filter_by_trip_id()` | 0.6 | 0.6 |
  | `filter_by_weekday()` | 0.7 | 0.7 |
  | `frequencies_to_stop_times()` | – | 12 |
  | `get_stop_times_patterns()` | 1.4 | ~1 |
  | `get_trip_duration()` | 3.1 | ~1 |
  | `get_trip_geometry()`† | 0.8 | ~1 |
  | `get_trip_length()`† | 1.9 | ~1 |
  | `get_trip_segment_duration()` | 64 | 7.9 |
  | `get_trip_speed()`† | 1.4 | ~1 |
  | `merge_gtfs()`† | 0.1 | 0.1 |
  | `read_gtfs()` | 1.4 | 1.8 |
  | `set_trip_speed()`† | 1.4 | ~1 |
  | `write_gtfs()` | 1.2 | 2.4 |

  Most gains grow with feed size: on a feed with 900,000 `stop_times` rows, `convert_time_to_seconds()` is about 20 times faster, `filter_by_spatial_extent()` 25 times, `filter_by_time_of_day()` 7 times, and `get_trip_segment_duration()` and `get_trip_duration()` (when `unit` isn't `"s"`) 60 and 10 times. `merge_gtfs()` with `prefix` is about 2.3 times faster with 1.15 million `stop_times` rows, `get_children_stops()` about 250 times faster with 20,000 stops, and `read_gtfs()` is much faster on feeds with large `calendar_dates` tables.
- `get_trip_length()`, `get_trip_geometry()`, `get_shape_length()`, `get_stop_distances()` and the functions that use them run their C++ code in parallel, with `data.table::getDTthreads()` threads (set with `data.table::setDTthreads()`), or on a single thread where the compiler doesn't support OpenMP. Results don't depend on the number of threads.
- Trip lengths are always calculated on the `{s2}` sphere, regardless of `sf::sf_use_s2()`. `convert_sf_to_shapes()` also calculates distances on that sphere: they match the previous ones within a micrometre with `sf::sf_use_s2(TRUE)` (the default), and differ by up to about 0.4% from the ellipsoidal ones previously calculated with `sf::sf_use_s2(FALSE)`.
- gtfstools no longer depends on `{units}` (#84). `set_trip_speed()` now converts speeds in m/s or mph with exact factors, so in rare borderline cases a new time may be one second earlier than in version 1.4.0.
- `download_validator()` detects the latest validator version automatically. PR contribution by @baarthur.
- Invalid dates (e.g. `20240230`) are still converted to `NA`, but now with a warning.
- `frequencies_to_stop_times()` raises informative errors for invalid `frequencies` entries and trips without a `departure_time`.
- The warnings about `route_id`s, `trip_id`s and `stop_id`s not found in a feed (classes `gtfstools_invalid_route_id`, `gtfstools_invalid_trip_id` and `gtfstools_invalid_stop_id`) list each missing id once.
- The documentation website moved to <https://ipea.github.io/gtfstools/> and the GitHub repository to <https://github.com/ipea/gtfstools>.

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
  `filter_by_sf()` is still allowed as of the current version, but the function
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
