# gtfstools (development version)

## Bug fixes

- Fixed bug in `merge_gtfs()` that errored when columns were are of type character (unknown). PR contribution by @gmatosferreira.
- Fixed bug that was leading to drop parent station ids in `merge_gtfs()`. PR contribution by @gmatosferreira and @haneroglu.

## New features

- New function `list_validator_versions()` which returns a df with the available CLI versions and their URLs. PR contribution by @baarthur

## Notes
- Function `download_validator()` now automatically detects the latest version available. PR contribution by @baarthur





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
- Changed the behaviour of `get_trip_geometry()` to not raise an error when the 'file' parameter is left untouched and the GTFS object doesn't contain either the shapes or the stop_times table. Closes [#29](https://github.com/ipeaGIT/gtfstools/issues/29).
- Fixed a bug that would cause `merge_gtfs()` to create objects that inherited only from `dt_gtfs` (ignoring `gtfs` and `list`).
- Fixed a bug in which `get_trip_speed()` returned `NA` speeds if the specified `trip_id` was listed in trips, but not in stop_times.
- Adjusted `set_trip_speed()` to stop raising a `max()`-related warning when none of the specified `trip_id`s exists.

## Notes

- Some utility functions previously provided by [`{gtfs2gps}`](https://github.com/ipeaGIT/gtfs2gps) will now be exported by `{gtfstools}`. Huge thanks to the whole `{gtfs2gps}` crew (Rafael Pereira @rafapereirabr, Pedro Andrade @pedro-andrade-inpe and João Bazzo @Joaobazzo)!
- The package now imports `{gtfsio}`, and many functions now heavily rely on it, such as `read_gtfs()` and `write_gtfs()`.
- Internal function `string_to_seconds()` now runs much faster thanks to Mark Padgham (@mpadge).
- `get_trip_geometry()` now runs much faster due to `data.table`-related optimizations.

## Potentially breaking changes

- Functions no longer validate GTFS objects on usage. `validate_gtfs()` will be flagged as deprecated as well, since I plan to heavily change its usability and outputs in future versions.
- `write_gtfs()` parameters went through major changes - the `optional` and `extra` params were flagged as deprecated and substituted by the more general `files` and `standard_only`.

# gtfstools 0.1.0

- Initial CRAN release.
