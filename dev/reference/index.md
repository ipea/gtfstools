# Package index

## Input/output

- [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md)
  : Read GTFS files
- [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md)
  : Write GTFS files

## Query information from GTFS feeds

- [`get_active_services()`](https://ipea.github.io/gtfstools/dev/reference/get_active_services.md)
  : Get active services
- [`get_calendar_overlap()`](https://ipea.github.io/gtfstools/dev/reference/get_calendar_overlap.md)
  : Get calendar overlap
- [`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md)
  : Get children stops recursively
- [`get_dates()`](https://ipea.github.io/gtfstools/dev/reference/get_dates.md)
  : Get service dates
- [`get_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/get_dwell_time.md)
  : Get dwell time
- [`get_parent_station()`](https://ipea.github.io/gtfstools/dev/reference/get_parent_station.md)
  : Get parent stations recursively
- [`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md)
  : Get route frequency
- [`get_route_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_route_speed.md)
  : Get route speed
- [`get_route_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_route_timetable.md)
  : Get route timetable
- [`get_shape_length()`](https://ipea.github.io/gtfstools/dev/reference/get_shape_length.md)
  : Get shape length
- [`get_start_and_end_times()`](https://ipea.github.io/gtfstools/dev/reference/get_start_and_end_times.md)
  : Get start and end times
- [`get_stop_distances()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_distances.md)
  : Get distances between stops
- [`get_stop_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_frequency.md)
  : Get stop frequency
- [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_times_patterns.md)
  : Get stop times patterns
- [`get_stop_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_timetable.md)
  : Get stop timetable
- [`get_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_stops.md)
  : Get stops
- [`get_summary()`](https://ipea.github.io/gtfstools/dev/reference/get_summary.md)
  : Get a summary of a GTFS feed
- [`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md)
  : Get trip duration
- [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
  : Get trip length
- [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  : Get trip segments' duration
- [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  : Get trip speed
- [`get_vkt()`](https://ipea.github.io/gtfstools/dev/reference/get_vkt.md)
  : Get vehicle-kilometres travelled
- [`get_vmt()`](https://ipea.github.io/gtfstools/dev/reference/get_vmt.md)
  : Get vehicle-miles travelled

## Filter GTFS feeds

- [`filter_by_agency_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_agency_id.md)
  :

  Filter GTFS object by `agency_id`

- [`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md)
  : Filter GTFS object by date

- [`filter_by_period()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_period.md)
  : Filter GTFS object by period

- [`filter_by_route_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_id.md)
  :

  Filter GTFS object by `route_id`

- [`filter_by_route_type()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_type.md)
  :

  Filter GTFS object by `route_type` (transport mode)

- [`filter_by_service_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_service_id.md)
  :

  Filter GTFS object by `service_id`

- [`filter_by_shape_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_shape_id.md)
  :

  Filter GTFS object by `shape_id`

- [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md)
  : Filter a GTFS object using a spatial extent

- [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_stop_id.md)
  :

  Filter GTFS object by `stop_id`

- [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md)
  : Filter GTFS object by time of day

- [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_trip_id.md)
  :

  Filter GTFS object by `trip_id`

- [`filter_by_weekday()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_weekday.md)
  : Filter GTFS object by weekday

## Spatial operations

- [`convert_sf_to_shapes()`](https://ipea.github.io/gtfstools/dev/reference/convert_sf_to_shapes.md)
  :

  Convert a simple feature object into a `shapes` table

- [`crop_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/crop_gtfs.md)
  : Crop a GTFS object to a spatial extent

- [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md)
  : Filter a GTFS object using a spatial extent

- [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  : Get trip geometry

- [`get_route_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_route_geometry.md)
  : Get route geometry

- [`get_shapes_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_shapes_geometry.md)
  :

  Get the `shapes` table with spatial geometry

- [`get_stops_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_stops_geometry.md)
  :

  Get the `stops` table with spatial geometry

## Editing GTFS feeds

- [`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md)
  : Interpolate missing stop times
- [`interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_shape_dist_traveled.md)
  : Interpolate the distances travelled along shapes
- [`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md)
  : Merge GTFS files
- [`combine_nearby_stops()`](https://ipea.github.io/gtfstools/dev/reference/combine_nearby_stops.md)
  : Combine nearby stops
- [`remove_duplicates()`](https://ipea.github.io/gtfstools/dev/reference/remove_duplicates.md)
  : Remove duplicated entries
- [`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md)
  : Remove unused ids
- [`fix_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/fix_gtfs.md)
  : Fix common problems in GTFS feeds
- [`set_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_dwell_time.md)
  : Set dwell time
- [`set_min_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_min_dwell_time.md)
  : Set a minimum dwell time
- [`set_max_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_max_speed.md)
  : Set trip maximum speed
- [`set_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/set_route_frequency.md)
  : Set route frequency
- [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  : Set trip average speed
- [`set_route_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_route_speed.md)
  : Set route average speed
- [`stop_times_to_frequencies()`](https://ipea.github.io/gtfstools/dev/reference/stop_times_to_frequencies.md)
  : Convert stop times to frequencies
- [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
  : Convert frequencies to stop times

## Validate GTFS feeds

- [`download_validator()`](https://ipea.github.io/gtfstools/dev/reference/download_validator.md)
  : Download MobilityData's GTFS validator
- [`list_validator_versions()`](https://ipea.github.io/gtfstools/dev/reference/list_validator_versions.md)
  : List MobilityData's GTFS validator versions
- [`validate_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/validate_gtfs.md)
  : Validate GTFS feed

## Support functions

- [`convert_stops_to_shapes()`](https://ipea.github.io/gtfstools/dev/reference/convert_stops_to_shapes.md)
  : Convert stops into shapes
- [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md)
  : Convert time fields to seconds after midnight
- [`convert_seconds_to_time()`](https://ipea.github.io/gtfstools/dev/reference/convert_seconds_to_time.md)
  : Convert seconds after midnight to time strings

## Network analysis

- [`build_graph()`](https://ipea.github.io/gtfstools/dev/reference/build_graph.md)
  : Build a transit network graph

## Interoperability between GTFS packages

- [`as_dt_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/as_dt_gtfs.md)
  : Coerce lists and GTFS objects from other packages into
  gtfstools-compatible GTFS objects

## Deprecated and defunct

- [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md)
  :

  Convert `shapes` table to simple feature object (deprecated)

- [`convert_stops_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_stops_to_sf.md)
  :

  Convert `stops` table to simple feature object (deprecated)

- [`filter_by_sf()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_sf.md)
  :

  Filter a GTFS object using a `simple features` object (defunct)
