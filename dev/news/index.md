# Changelog

## gtfstools (development version)

### Bug fixes

### New features

### Notes

## gtfstools 1.4.0

CRAN release: 2025-01-08

### New features

- [`download_validator()`](https://ipeagit.github.io/gtfstools/dev/reference/download_validator.md)
  and
  [`validate_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/validate_gtfs.md)
  now support using validator v5.0.0, v5.0.1 and v6.0.0.

### Notes

- Removed the local copies of [cpp11](https://cpp11.r-lib.org)
  functions, as the most recent releases fix the issues we were having.

## gtfstools 1.3.0

CRAN release: 2024-10-07

### New features

- New function
  [`convert_sf_to_shapes()`](https://ipeagit.github.io/gtfstools/dev/reference/convert_sf_to_shapes.md).
- New generic function
  [`as_dt_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/as_dt_gtfs.md)
  with methods for a few different classes (`tidygtfs`, `gtfs` and
  `list`).
- [gtfstools](https://ipeagit.github.io/gtfstools/) functions now
  accepts GTFS objects created by other packages, such as
  [gtfsio](https://r-transit.github.io/gtfsio/) and
  [tidytransit](https://github.com/r-transit/tidytransit).
- [`filter_by_route_type()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_type.md)
  now accepts Google Transit’s [extended route
  types](https://developers.google.com/transit/gtfs/reference/extended-route-types).
  Thanks [@Ge-Rag](https://github.com/Ge-Rag).
- [`convert_shapes_to_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md),
  [`get_trip_geometry()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_geometry.md),
  [`get_trip_length()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_length.md),
  [`get_trip_speed()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_speed.md),
  [`get_trip_segment_duration()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  and
  [`get_stop_times_patterns()`](https://ipeagit.github.io/gtfstools/dev/reference/get_stop_times_patterns.md)
  now take an additional argument `sort_sequence`, used to indicate
  whether shapes/timetables should be ordered by
  `shape_pt_sequence`/`stop_sequence` when applying the functions’
  procedures.
- [`download_validator()`](https://ipeagit.github.io/gtfstools/dev/reference/download_validator.md)
  and
  [`validate_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/validate_gtfs.md)
  now support using validator v4.1.0 and v4.2.0.
- New parameters to
  [`filter_by_stop_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_stop_id.md):
  `include_children` and `include_parents`.

### Bug fixes

- Fixed a bug in
  [`convert_to_standard()`](https://ipeagit.github.io/gtfstools/dev/reference/convert_to_standard.md)
  in which the date fields from `feed_info` would not be converted back
  to an integer in their standard format (YYYYMMDD).
- Filtering functions now also filter the `transfers` table based on
  `trip_id` and `route_id`. Previously they would filter it based only
  on `stop_id`. Thanks Daniel Langbein
  ([@langbein-daniel](https://github.com/langbein-daniel)).
- Fixed a bug in
  [`filter_by_route_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_id.md)
  in which feeds with only one agency that omitted `agency_id` in
  `routes` and `fare_attributes` would end up with an empty `agency`
  table.
- [`filter_by_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_sf.md)
  now correctly throws an error when an unsupported function is passed
  to `spatial_operation`.

### Feature deprecation

- The
  [`filter_by_stop_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_stop_id.md)
  behavior of filtering by trips that contain the specified stops has
  been deprecated. For backwards compatibility reasons, this behavior is
  still the default as of the current version and is controlled by the
  parameter `full_trips`. To actually filter by stop ids (the behavior
  that we now believe is the most appropriate), please use
  `full_trips = FALSE`. This behavior will be the default from version
  2.0.0 onward. To achieve the old behavior, manually subset the
  stop_times table by `stop_id` and specify the `trip_id`s included in
  the output in
  [`filter_by_trip_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_trip_id.md).
- [`filter_by_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_sf.md)
  has been deprecated in favor of
  [`filter_by_spatial_extent()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md).
  For backwards compatibility reasons, usage of
  [`filter_by_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_sf.md)
  is still allowed as of the curent version, but the function will be
  removed from the package in version 2.0.0.

### Notes

- [`validate_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/validate_gtfs.md)
  now defaults to run sequentially. Previously it would default to run
  parallelly using all available cores. Heavily inspired by Henrik
  Bengtsson post “Please Avoid detectCores() in your R packages”
  (<https://www.jottr.org/2022/12/05/avoid-detectcores/>).
- Improved performance of
  [`seconds_to_string()`](https://ipeagit.github.io/gtfstools/dev/reference/seconds_to_string.md)
  and, consequently, any other functions that use it.
- Improved performance and improved readability of most filtering
  functions.

## gtfstools 1.2.0

CRAN release: 2022-11-24

### New features

- New
  [`validate_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/validate_gtfs.md)
  behavior. Now used to run MobilityData Canonical GTFS validator with a
  feed. The old behavior was marked as deprecated since v1.0.0.
- New function
  [`download_validator()`](https://ipeagit.github.io/gtfstools/dev/reference/download_validator.md).
- New vignette demonstrating how to validate feeds.

### Bug fixes

- Fixed a bug in
  [`write_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/write_gtfs.md)
  that prevented `as_dir = TRUE` to be used.
- Fixed a bug in
  [`set_trip_speed()`](https://ipeagit.github.io/gtfstools/dev/reference/set_trip_speed.md)
  that resulted in invalid stop_times tables when `max(stop_sequence)`
  was higher than the number of stops of a given trip. Thanks Alena
  Stern ([@alenastern](https://github.com/alenastern)).
- Fixed a bug in
  [`set_trip_speed()`](https://ipeagit.github.io/gtfstools/dev/reference/set_trip_speed.md)
  that resulted in the speed of wrong trip_ids being updated because of
  the order that these ids would appear in the trips and stop_times
  tables. Thanks Alena Stern
  ([@alenastern](https://github.com/alenastern)).

## gtfstools 1.1.0

CRAN release: 2022-05-24

### New features

- New function
  [`convert_time_to_seconds()`](https://ipeagit.github.io/gtfstools/dev/reference/convert_time_to_seconds.md).
- New function
  [`filter_by_agency_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_agency_id.md).
- New function
  [`filter_by_service_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_service_id.md).
- New function
  [`filter_by_time_of_day()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_time_of_day.md).
- New function
  [`filter_by_weekday()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_weekday.md).
- New function
  [`frequencies_to_stop_times()`](https://ipeagit.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md).
- New function
  [`get_children_stops()`](https://ipeagit.github.io/gtfstools/dev/reference/get_children_stops.md).
- New function
  [`get_stop_times_patterns()`](https://ipeagit.github.io/gtfstools/dev/reference/get_stop_times_patterns.md).
- New function
  [`get_trip_length()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_length.md).
- New parameter to
  [`merge_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/merge_gtfs.md):
  `prefix`. The `warnings` parameter was flagged as deprecated.
- Functions
  [`get_parent_station()`](https://ipeagit.github.io/gtfstools/dev/reference/get_parent_station.md)
  and `get_children_stops` now accept `stop_id = NULL` to analyze all
  `stop_id`s in the `stops` table.

### Bug fixes

- Fixed a bug in which
  [`get_trip_segment_duration()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  would list wrong segment numbers, not necessarily starting from 1. Now
  segment numbers always range from 1 to N, where N is the total number
  of segments that compose each trip.
- Fixed a bug in `filter_by_{route,service,shape,trip}_id()` that
  resulted in the `agency` table not getting filtered when the specified
  id was `character(0)`.

### Notes

- Performance improvements to
  [`get_trip_geometry()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_geometry.md),
  [`get_trip_duration()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_duration.md),
  [`get_trip_segment_duration()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  and
  [`convert_shapes_to_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md).
- Stopped ordering points by `shape_pt_sequence`/`stop_sequence` in
  [`get_trip_geometry()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  and
  [`convert_shapes_to_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md),
  since the GTFS reference says that the `stop_times` and `shapes`
  tables must be ordered by point/stop sequence anyway.
- Removed [lwgeom](https://r-spatial.github.io/lwgeom/) from
  dependencies (Suggests), now that it’s not required to run
  [`get_trip_speed()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_speed.md)
  and
  [`set_trip_speed()`](https://ipeagit.github.io/gtfstools/dev/reference/set_trip_speed.md)
  anymore.
- Removed the `warnings` parameter from
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md)
  and
  [`write_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/write_gtfs.md)
  and the `optional` and `extra` parameters from
  [`write_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/write_gtfs.md),
  flagged as deprecated on gtfstools v1.0.0.
- Updated filtering vignette to demonstrate new functions.

## gtfstools 1.0.0

CRAN release: 2021-11-16

### New features

- New function
  [`convert_stops_to_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/convert_stops_to_sf.md).
- New function
  [`convert_shapes_to_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md).
- New function
  [`filter_by_route_type()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_type.md).
- New function
  [`filter_by_route_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_id.md).
- New function
  [`filter_by_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_sf.md).
- New function
  [`filter_by_shape_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_shape_id.md).
- New function
  [`filter_by_stop_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_stop_id.md).
- New function
  [`filter_by_trip_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_trip_id.md).
- New function
  [`get_parent_station()`](https://ipeagit.github.io/gtfstools/dev/reference/get_parent_station.md).
- New function
  [`remove_duplicates()`](https://ipeagit.github.io/gtfstools/dev/reference/remove_duplicates.md).
- New parameters to
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md):
  `fields`, `skip` and `encoding`. The `warnings` parameter was flagged
  as deprecated.
- New parameters to
  [`write_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/write_gtfs.md):
  `files`, `standard_only` and `as_dir`. They substitute the previously
  existent `optional` and `extra`, which were flagged as deprecated. The
  `warnings` parameter was flagged as deprecated too.
- New vignette exploring the filtering functions.

### Bug fixes

- [`get_trip_speed()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_speed.md)
  and
  [`set_trip_speed()`](https://ipeagit.github.io/gtfstools/dev/reference/set_trip_speed.md)
  examples and tests now only run if
  [lwgeom](https://r-spatial.github.io/lwgeom/) is installed.
  [lwgeom](https://r-spatial.github.io/lwgeom/) is an
  [sf](https://r-spatial.github.io/sf/) “soft” dependency required by
  these functions, and is listed in `Suggests`. However, package checks
  would fail not so gracefully if it wasn’t installed, which is now
  fixed.
- Fixed a bug in which the `crs` passed to
  [`get_trip_geometry()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  would be assigned to the result without actually reprojecting it.
- Changed the behaviour of
  [`get_trip_geometry()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  to not raise an error when the ‘file’ parameter is left untouched and
  the GTFS object doesn’t contain either the shapes or the stop_times
  table. Closes [\#29](https://github.com/ipeaGIT/gtfstools/issues/29).
- Fixed a bug that would cause
  [`merge_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/merge_gtfs.md)
  to create objects that inherited only from `dt_gtfs` (ignoring `gtfs`
  and `list`).
- Fixed a bug in which
  [`get_trip_speed()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_speed.md)
  returned `NA` speeds if the specified `trip_id` was listed in trips,
  but not in stop_times.
- Adjusted
  [`set_trip_speed()`](https://ipeagit.github.io/gtfstools/dev/reference/set_trip_speed.md)
  to stop raising a
  [`max()`](https://rdrr.io/r/base/Extremes.html)-related warning when
  none of the specified `trip_id`s exists.

### Notes

- Some utility functions previously provided by
  [`{gtfs2gps}`](https://github.com/ipeaGIT/gtfs2gps) will now be
  exported by [gtfstools](https://ipeagit.github.io/gtfstools/). Huge
  thanks to the whole [gtfs2gps](https://github.com/ipeaGIT/gtfs2gps)
  crew (Rafael Pereira
  [@rafapereirabr](https://github.com/rafapereirabr), Pedro Andrade
  [@pedro-andrade-inpe](https://github.com/pedro-andrade-inpe) and João
  Bazzo [@Joaobazzo](https://github.com/Joaobazzo))!
- The package now imports [gtfsio](https://r-transit.github.io/gtfsio/),
  and many functions now heavily rely on it, such as
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md)
  and
  [`write_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/write_gtfs.md).
- Internal function
  [`string_to_seconds()`](https://ipeagit.github.io/gtfstools/dev/reference/string_to_seconds.md)
  now runs much faster thanks to Mark Padgham
  ([@mpadge](https://github.com/mpadge)).
- [`get_trip_geometry()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  now runs much faster due to `data.table`-related optimizations.

### Potentially breaking changes

- Functions no longer validate GTFS objects on usage.
  [`validate_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/validate_gtfs.md)
  will be flagged as deprecated as well, since I plan to heavily change
  its usability and outputs in future versions.
- [`write_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/write_gtfs.md)
  parameters went through major changes - the `optional` and `extra`
  params were flagged as deprecated and substituted by the more general
  `files` and `standard_only`.

## gtfstools 0.1.0

CRAN release: 2021-02-23

- Initial CRAN release.
