# Package index

## Input/output

- [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md)
  : Read GTFS files
- [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md)
  : Write GTFS files

## Query information from GTFS feeds

- [`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md)
  : Get children stops recursively
- [`get_parent_station()`](https://ipea.github.io/gtfstools/dev/reference/get_parent_station.md)
  : Get parent stations recursively
- [`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md)
  : Get route frequency
- [`get_shape_length()`](https://ipea.github.io/gtfstools/dev/reference/get_shape_length.md)
  : Get shape length
- [`get_stop_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_frequency.md)
  : Get stop frequency
- [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_times_patterns.md)
  : Get stop times patterns
- [`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md)
  : Get trip duration
- [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  : Get trip geometry
- [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
  : Get trip length
- [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  : Get trip segments' duration
- [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  : Get trip speed

## Filter GTFS feeds

- [`filter_by_agency_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_agency_id.md)
  :

  Filter GTFS object by `agency_id`

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

- [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md)
  :

  Convert `shapes` table to simple feature object

- [`convert_stops_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_stops_to_sf.md)
  :

  Convert `stops` table to simple feature object

- [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md)
  : Filter a GTFS object using a spatial extent

## Manipulation

- [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md)
  : Convert time fields to seconds after midnight
- [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
  : Convert frequencies to stop times
- [`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md)
  : Merge GTFS files
- [`remove_duplicates()`](https://ipea.github.io/gtfstools/dev/reference/remove_duplicates.md)
  : Remove duplicated entries
- [`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md)
  : Remove unused ids
- [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  : Set trip average speed

## Validate GTFS feeds

- [`download_validator()`](https://ipea.github.io/gtfstools/dev/reference/download_validator.md)
  : Download MobilityData's GTFS validator
- [`list_validator_versions()`](https://ipea.github.io/gtfstools/dev/reference/list_validator_versions.md)
  : List MobilityData's GTFS validator versions
- [`validate_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/validate_gtfs.md)
  : Validate GTFS feed

## Interoperability between GTFS packages

- [`as_dt_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/as_dt_gtfs.md)
  : Coerce lists and GTFS objects from other packages into
  gtfstools-compatible GTFS objects

## Defunct

- [`filter_by_sf()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_sf.md)
  :

  Filter a GTFS object using a `simple features` object (defunct)
