# Changelog

## gtfstools (development version)

### Breaking changes

- With `prefix = FALSE`, the default,
  [`merge_gtfs()`](https://ipea.github.io/gtfstools/reference/merge_gtfs.md)
  now keeps rows that are identical in every column only once and raises
  an error when the GTFS objects share ids whose data differ (e.g. a
  `stop_id` with different coordinates, or a `trip_id` with different
  `stop_times`), which used to produce inconsistent feeds. Merging a
  feed with itself now works, but merging versions of the same feed, or
  feeds with simple ids (e.g. both with an `agency_id` `"1"`), usually
  raises the error: use `prefix = TRUE`. A character `prefix` must now
  have unique elements.
- [`filter_by_sf()`](https://ipea.github.io/gtfstools/reference/filter_by_sf.md)
  and the `full_trips` argument of
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/reference/filter_by_stop_id.md),
  deprecated in version 1.3.0, are now defunct. Use
  [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/reference/filter_by_spatial_extent.md),
  which takes the same arguments.
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/reference/filter_by_stop_id.md)
  now always keeps only the `stop_times` entries at the given stops (by
  default, it used to keep entire trips): to keep entire trips, pass the
  `trip_id`s that serve the stops to
  [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/reference/filter_by_trip_id.md)
  ([\#75](https://github.com/ipea/gtfstools/issues/75)).
- [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md)
  now measures each trip from its first to its last stop, instead of
  along its entire shape, so lengths are usually shorter, and the speeds
  of
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md)
  and
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
  slightly lower. Likewise,
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md)
  now returns, by default, the part of the shape between the first and
  last stops. These functions now require the `stops` table (and
  [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md)
  and
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md)
  also `stop_times`). Use the new
  [`get_shape_length()`](https://ipea.github.io/gtfstools/reference/get_shape_length.md)
  and
  [`get_shapes_geometry()`](https://ipea.github.io/gtfstools/reference/get_shapes_geometry.md)
  for entire shapes.
- [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md),
  [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md)
  and
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md)
  now return one result per trip, without the `origin_file` column.
  Their new `method` argument (and `by`, in the last two) comes right
  after `trip_id`, so `unit` and `file` must be passed by name.
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md)
  also returns `route_id` as its first column, and so requires the
  `trips` table.
- The `by_reference` argument of
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
  must now be passed by name
  ([\#89](https://github.com/ipea/gtfstools/issues/89)).
- [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_shapes_to_sf.md),
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md),
  [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md),
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md),
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_segment_duration.md)
  and
  [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/reference/get_stop_times_patterns.md)
  now always order `shapes` and `stop_times` by
  `shape_pt_sequence`/`stop_sequence`, which are therefore required.
  Results only change for feeds not ordered by these columns, which were
  previously wrong. Their `sort_sequence` argument is deprecated: `TRUE`
  raises a warning and `FALSE` an error
  ([\#94](https://github.com/ipea/gtfstools/issues/94)).

### Feature deprecation

- [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_shapes_to_sf.md)
  and
  [`convert_stops_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_stops_to_sf.md)
  are deprecated in favour of
  [`get_shapes_geometry()`](https://ipea.github.io/gtfstools/reference/get_shapes_geometry.md)
  and
  [`get_stops_geometry()`](https://ipea.github.io/gtfstools/reference/get_stops_geometry.md),
  which take the same arguments (except `sort_sequence`) and return the
  same results.
- The `file` argument of
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md),
  [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md)
  and
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md)
  is deprecated in favour of `method` (`file = "stop_times"` is
  `method = "euclidean"`).

### New features

- New functions to query feeds:
  - [`get_summary()`](https://ipea.github.io/gtfstools/reference/get_summary.md)
    summarises a feed (files, agencies, service calendar, totals
    including the vehicle-kilometres travelled, and the distributions of
    trip speeds, trip lengths and route headways), optionally restricted
    to some dates, routes, modes, agencies and a time of day, as a list
    of `data.table`s and an HTML report (requires
    [ggplot2](https://ggplot2.tidyverse.org),
    [knitr](https://yihui.org/knitr/),
    [rmarkdown](https://github.com/rstudio/rmarkdown) and Pandoc).
    `by_route_type = TRUE` breaks results down by transport mode
    ([\#127](https://github.com/ipea/gtfstools/issues/127)), and
    `unit = "mph"` reports miles and mph.
  - [`get_vkt()`](https://ipea.github.io/gtfstools/reference/get_vkt.md)
    and
    [`get_vmt()`](https://ipea.github.io/gtfstools/reference/get_vmt.md)
    return the vehicle-kilometres (or vehicle-miles) travelled by each
    route, counting every departure (including those in `frequencies`)
    on every day its service runs, optionally restricted to some dates
    and a time of day.
  - [`get_route_frequency()`](https://ipea.github.io/gtfstools/reference/get_route_frequency.md)
    and
    [`get_stop_frequency()`](https://ipea.github.io/gtfstools/reference/get_stop_frequency.md)
    return the number of departures and the mean headway of each route
    and at each stop within a time of day
    ([\#53](https://github.com/ipea/gtfstools/issues/53)).
  - [`get_route_speed()`](https://ipea.github.io/gtfstools/reference/get_route_speed.md)
    returns the minimum, mean, median, maximum and standard deviation of
    the trip speeds of each route.
  - [`get_route_geometry()`](https://ipea.github.io/gtfstools/reference/get_route_geometry.md)
    returns the distinct trip geometries of each route (e.g. each
    direction and short-turn service), with the number of trips that
    follow each.
  - [`get_shape_length()`](https://ipea.github.io/gtfstools/reference/get_shape_length.md),
    [`get_shapes_geometry()`](https://ipea.github.io/gtfstools/reference/get_shapes_geometry.md)
    and
    [`get_stops_geometry()`](https://ipea.github.io/gtfstools/reference/get_stops_geometry.md)
    return the length of each shape and the shapes and stops as `sf`
    objects.
  - [`get_stops()`](https://ipea.github.io/gtfstools/reference/get_stops.md)
    and
    [`get_stop_distances()`](https://ipea.github.io/gtfstools/reference/get_stop_distances.md)
    return the stops visited by the given trips and/or routes and the
    great-circle distances between each pair of them.
  - [`get_dates()`](https://ipea.github.io/gtfstools/reference/get_dates.md),
    [`get_active_services()`](https://ipea.github.io/gtfstools/reference/get_active_services.md)
    and
    [`get_start_and_end_times()`](https://ipea.github.io/gtfstools/reference/get_start_and_end_times.md)
    return the dates with service, the services active on given dates,
    and the earliest departure and latest arrival times.
  - [`get_stop_timetable()`](https://ipea.github.io/gtfstools/reference/get_stop_timetable.md)
    and
    [`get_route_timetable()`](https://ipea.github.io/gtfstools/reference/get_route_timetable.md)
    return the timetables of stops and routes on given dates.
  - [`get_dwell_time()`](https://ipea.github.io/gtfstools/reference/get_dwell_time.md)
    returns how long vehicles stay at stops, optionally within a time of
    day.
  - [`get_calendar_overlap()`](https://ipea.github.io/gtfstools/reference/get_calendar_overlap.md)
    returns the number of trips each feed runs on each service day and
    whether all feeds have service on it (or, with
    `resolution = "periods"`, the periods in which all of them do), to
    pick a date on which several feeds can be analysed together.
    `plot = TRUE` plots the result (requires
    [ggplot2](https://ggplot2.tidyverse.org)). See the new vignette
    “Checking the calendar overlap of GTFS feeds”
    ([\#85](https://github.com/ipea/gtfstools/issues/85)). Thanks
    [@higgicd](https://github.com/higgicd) for the suggestion and the
    original `check_gtfs_overlap()` code.
- New functions to edit feeds:
  - [`set_route_frequency()`](https://ipea.github.io/gtfstools/reference/set_route_frequency.md)
    sets the headway of routes within a time of day, replacing their
    trips in it with a frequency-based template trip. Departures outside
    the time of day don’t change.
  - [`set_route_speed()`](https://ipea.github.io/gtfstools/reference/set_route_speed.md)
    sets the average speed of all trips of the given routes, as
    [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
    does for trips.
  - [`set_dwell_time()`](https://ipea.github.io/gtfstools/reference/set_dwell_time.md),
    [`set_min_dwell_time()`](https://ipea.github.io/gtfstools/reference/set_min_dwell_time.md)
    and
    [`set_max_speed()`](https://ipea.github.io/gtfstools/reference/set_max_speed.md)
    set dwell times, raise dwell times at intermediate stops to a
    minimum and cap trip speeds, shifting the later times of each trip
    accordingly. The dwell times can be set within a time of day, and
    speeds capped only between two stops or for trips departing within a
    time of day, as in
    [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md).
    Like
    [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
    and
    [`set_route_speed()`](https://ipea.github.io/gtfstools/reference/set_route_speed.md),
    they and
    [`set_route_frequency()`](https://ipea.github.io/gtfstools/reference/set_route_frequency.md)
    can be restricted to some transport modes with `route_type`.
  - [`interpolate_stop_times()`](https://ipea.github.io/gtfstools/reference/interpolate_stop_times.md)
    fills blank arrival and departure times, assuming a constant speed
    between stops with known times.
  - [`interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/reference/interpolate_shape_dist_traveled.md)
    (re)calculates `shape_dist_traveled` in `stop_times` and `shapes`,
    in meters.
  - [`stop_times_to_frequencies()`](https://ipea.github.io/gtfstools/reference/stop_times_to_frequencies.md),
    the counterpart of
    [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/reference/frequencies_to_stop_times.md),
    approximates scheduled trips by frequency-based ones
    ([\#69](https://github.com/ipea/gtfstools/issues/69)).
  - [`convert_stops_to_shapes()`](https://ipea.github.io/gtfstools/reference/convert_stops_to_shapes.md)
    creates straight-line shapes between consecutive stops for trips
    without a usable shape.
  - [`combine_nearby_stops()`](https://ipea.github.io/gtfstools/reference/combine_nearby_stops.md)
    combines the stops within a given distance of each other (after
    merging platforms into their stations), updating every file that
    refers to them. Entrances, generic nodes, boarding areas and
    `pathways` are removed.
  - [`crop_gtfs()`](https://ipea.github.io/gtfstools/reference/crop_gtfs.md)
    crops a feed to a spatial extent. Unlike
    [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/reference/filter_by_spatial_extent.md),
    which keeps entire trips, it cuts the trips that leave the extent
    (interpolating blank times at their new ends and shifting their
    `frequencies`) and, by default, trims their shapes
    ([\#44](https://github.com/ipea/gtfstools/issues/44)). Thanks
    [@luukvdmeer](https://github.com/luukvdmeer) for the proposal and
    discussion.
  - [`remove_unused_ids()`](https://ipea.github.io/gtfstools/reference/remove_unused_ids.md)
    removes unused ids from all files
    ([\#55](https://github.com/ipea/gtfstools/issues/55)).
  - [`fix_gtfs()`](https://ipea.github.io/gtfstools/reference/fix_gtfs.md)
    cleans a feed in one call: it removes duplicated rows and unused
    ids, interpolates blank stop times, recalculates
    `shape_dist_traveled` in feeds with shapes, and optionally caps trip
    speeds and sets a minimum dwell time.
- New function
  [`build_graph()`](https://ipea.github.io/gtfstools/reference/build_graph.md),
  which builds a frequency-based transit network from the trips
  departing within a time of day, as General Modeling Network
  Specification (GMNS) tables or as an [igraph](https://r.igraph.org/)
  or [tidygraph](https://tidygraph.data-imaginist.com) graph, with
  in-vehicle, boarding, alighting and walking transfer links. See the
  new vignette “Building transit network graphs”.
- New functions
  [`filter_by_date()`](https://ipea.github.io/gtfstools/reference/filter_by_date.md)
  and
  [`filter_by_period()`](https://ipea.github.io/gtfstools/reference/filter_by_period.md),
  which keep the services that run on given dates or in a period. By
  default (`trim = TRUE`),
  [`filter_by_period()`](https://ipea.github.io/gtfstools/reference/filter_by_period.md)
  trims the calendars to the period.
- New function
  [`convert_seconds_to_time()`](https://ipea.github.io/gtfstools/reference/convert_seconds_to_time.md),
  the counterpart of
  [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md).
- New function
  [`list_validator_versions()`](https://ipea.github.io/gtfstools/reference/list_validator_versions.md).
  PR contribution by [@baarthur](https://github.com/baarthur).
- [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md)
  and
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md)
  gain the `by` argument, to calculate lengths and speeds between
  consecutive stops. They and
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md)
  gain the `method` argument, to measure along shapes or along straight
  lines between stops, and, without shapes, now fall back to straight
  lines with a warning instead of an error.
- [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
  gains `first_stop`, `last_stop`, `from` and `to`, to change speeds
  only between two stops and for trips departing within a time of day
  ([\#89](https://github.com/ipea/gtfstools/issues/89)), and
  `route_type`, so `trip_id` is now optional.
- [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md)
  and
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
  accept `unit = "mph"`.
- [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md),
  [`get_route_speed()`](https://ipea.github.io/gtfstools/reference/get_route_speed.md),
  [`get_trip_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_duration.md),
  [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md)
  and
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_segment_duration.md)
  gain `from` and `to`, as in
  [`get_dwell_time()`](https://ipea.github.io/gtfstools/reference/get_dwell_time.md),
  to include only the trips (or segments) that depart within a time of
  day.
- [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/reference/frequencies_to_stop_times.md)
  gains `strategy`, to shift departures by half the headway or by a
  random offset ([\#56](https://github.com/ipea/gtfstools/issues/56)).
- [`write_gtfs()`](https://ipea.github.io/gtfstools/reference/write_gtfs.md)
  gains `compression_level`. Its default, 6 (previously always 9), makes
  writing about 2 to 3 times faster, with files of very similar size.
- The `path` argument of
  [`download_validator()`](https://ipea.github.io/gtfstools/reference/download_validator.md)
  now defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html).
- New vignettes “Editing GTFS feeds”, “Querying GTFS feeds” and “Mapping
  GTFS feeds”.

### Bug fixes

- [`merge_gtfs()`](https://ipea.github.io/gtfstools/reference/merge_gtfs.md):
  - no longer prefixes ids with `"NA_"` when the GTFS objects are passed
    with names (e.g. `merge_gtfs(a = gtfs1, b = gtfs2, prefix = TRUE)`);
  - no longer prefixes the `field_value` and `record_sub_id` columns of
    `translations`, no longer errors with character columns of unknown
    type, and keeps parent station ids. PR contributions by
    [@gmatosferreira](https://github.com/gmatosferreira) and
    [@haneroglu](https://github.com/haneroglu).
- [`merge_gtfs()`](https://ipea.github.io/gtfstools/reference/merge_gtfs.md)
  and
  [`remove_duplicates()`](https://ipea.github.io/gtfstools/reference/remove_duplicates.md)
  no longer corrupt elements that are not tables, such as the
  `locations` of GTFS-Flex feeds
  ([`merge_gtfs()`](https://ipea.github.io/gtfstools/reference/merge_gtfs.md)
  leaves them out, with a warning).
- [`download_validator()`](https://ipea.github.io/gtfstools/reference/download_validator.md)
  and
  [`list_validator_versions()`](https://ipea.github.io/gtfstools/reference/list_validator_versions.md)
  now fail gracefully on network problems, as CRAN requires: they retry
  transient failures and then inform with a message (class
  `gtfstools_validator_download_failure`) and invisibly return `NULL`,
  instead of raising an error
  ([`download_validator()`](https://ipea.github.io/gtfstools/reference/download_validator.md)
  used to raise a misleading “invalid URL” one). A version that doesn’t
  exist raises an error of class `gtfstools_invalid_validator_version`.
- [`download_validator()`](https://ipea.github.io/gtfstools/reference/download_validator.md)
  downloads the validator once instead of twice, doesn’t go online when
  an explicit `version` is already in `path`, and shows a progress bar
  with `quiet = FALSE`.
  [`list_validator_versions()`](https://ipea.github.io/gtfstools/reference/list_validator_versions.md)
  returns its result visibly.
- [`get_trip_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_duration.md),
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_segment_duration.md),
  [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/reference/filter_by_time_of_day.md),
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/reference/filter_by_stop_id.md)
  and
  [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/reference/frequencies_to_stop_times.md)
  no longer add temporary columns to the tables of the given feed.
- The `filter_by_*()` functions no longer drop:
  - rows whose blank keys mean “applies to all”: zone `fare_rules`
    without `route_id`, `transfers` without `from_stop_id`/`to_stop_id`
    and `attributions` without `agency_id`;
  - the `agency` of single-agency feeds whose `routes.agency_id` is
    blank or absent;
  - the station entrances, generic nodes and boarding areas of kept
    stations and platforms, with their pathways and levels;
  - every `fare_attributes` entry of feeds without `fare_rules`. In
    multi-agency feeds, they keep the fares of the agencies whose routes
    were kept, and those without an agency.
- [`filter_by_agency_id()`](https://ipea.github.io/gtfstools/reference/filter_by_agency_id.md)
  now keeps the `fare_attributes` without an `agency_id`.
- [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/reference/filter_by_trip_id.md),
  [`filter_by_service_id()`](https://ipea.github.io/gtfstools/reference/filter_by_service_id.md),
  [`filter_by_shape_id()`](https://ipea.github.io/gtfstools/reference/filter_by_shape_id.md)
  and the functions built on them no longer keep `fare_attributes` (and
  their agencies) whose `fare_rules` were all dropped by zone.
- [`filter_by_route_id()`](https://ipea.github.io/gtfstools/reference/filter_by_route_id.md)
  and
  [`filter_by_route_type()`](https://ipea.github.io/gtfstools/reference/filter_by_route_type.md)
  filtered `fare_rules` by `level_id` instead of `route_id`.
- [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/reference/filter_by_time_of_day.md):
  - with `keep = TRUE`, sets the `end_time` of `frequencies` entries
    that cross `to` to one second after it, so
    [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/reference/frequencies_to_stop_times.md)
    no longer loses a departure at `to`;
  - keeps `frequencies` entries that start exactly at `to` (this also
    affects
    [`get_summary()`](https://ipea.github.io/gtfstools/reference/get_summary.md));
  - with `keep = FALSE`, drops a departure at `to`, and removes entries
    left without departures;
  - updates the `start_time` of `frequencies` entries with a blank
    `exact_times`, and no longer returns frequency-based trips whose
    entries were all filtered out;
  - with `keep = FALSE` and `full_trips = TRUE`, no longer drops every
    trip with an untimed stop;
  - rejects `from`/`to` with minutes or seconds of 60 or more;
  - no longer modifies the `frequencies` table of the given feed when
    all of its entries are selected.
- [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/reference/filter_by_spatial_extent.md)
  no longer errors when stops have missing coordinates, drops every
  selected trip with `keep = FALSE`, no longer keeps unused shapes nor
  removes duplicated rows, and treats a `bbox` as a rectangle in
  longitude and latitude, instead of a slightly larger polygon with
  curved edges. It no longer accepts
  [`sf::st_equals_exact()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html)
  and
  [`sf::st_is_within_distance()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html)
  as `spatial_operation`, since they always failed.
- [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/reference/frequencies_to_stop_times.md)
  treats `end_time` as exclusive, as the GTFS specification requires
  (from 08:00 to 09:00 every 30 minutes now yields 08:00 and 08:30
  only), and sets arrivals that a dwell time at the first stop would put
  before 00:00:00 to 00:00:00, instead of raising an error.
- Malformed times (e.g. `"5:30"`, `"12:60:00"`) and non-ASCII strings
  marked as `"bytes"` are converted to `NA` with a warning, instead of
  wrong values or an error.
  [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md)
  no longer skips `arrival_time` and `end_time` when only one column of
  a pair is present.
- [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/reference/get_stop_times_patterns.md)
  no longer ignores stop timing in the spatiotemporal patterns of trips
  with blank stop times, and no longer merges different stop sequences
  whose `stop_id`s contain `;` or `|`.
- [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
  identifies the first stop of each trip by `stop_sequence` instead of
  row position, keeps existing `*_secs` columns in sync, and raises an
  error when `speed` is zero, negative or infinite, or when a trip is
  given different speeds.
- [`get_trip_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_duration.md)
  returns `NA` with a warning (also raised by
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md))
  for trips without any arrival or departure time, instead of `-Inf` or
  an error.
- Functions that measure trips along shapes raise an informative error
  when a used shape has a blank `shape_id`.
  [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md),
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md)
  and
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md)
  ignore `stop_times` entries with a missing or blank `trip_id`, which
  used to shift the segments of other trips with `by = "segment"`.
- [`get_children_stops()`](https://ipea.github.io/gtfstools/reference/get_children_stops.md)
  no longer returns `NA` rows for stops without a `parent_station`.
- [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md)
  no longer keeps doubled quotes inside quoted text fields, and
  [`write_gtfs()`](https://ipea.github.io/gtfstools/reference/write_gtfs.md)
  always writes UTF-8, also for feeds read with `encoding = "Latin-1"`.
- [`as_dt_gtfs()`](https://ipea.github.io/gtfstools/reference/as_dt_gtfs.md)
  no longer turns `Date` fields into `NA`, and converts the date fields
  of lists to `Date`.
- The documentation of
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/reference/filter_by_stop_id.md)
  now says that it keeps (or drops) the `stop_times` entries at the
  given stops, not entire trips.

### Notes

- Many functions are faster. The table below shows how many times faster
  than in version 1.4.0 each function of that version is, on the example
  feeds `poa` and `spo` stacked twice with
  [`merge_gtfs()`](https://ipea.github.io/gtfstools/reference/merge_gtfs.md)
  (up to 46,000 `stop_times` rows), with the default number of threads.
  Values below 1 mean slower, and ~1 a difference under 1.2 times
  (measurement noise); functions not listed are ~1 on both feeds, except
  [`get_children_stops()`](https://ipea.github.io/gtfstools/reference/get_children_stops.md)
  and
  [`get_parent_station()`](https://ipea.github.io/gtfstools/reference/get_parent_station.md)
  (the feeds have no `parent_station`),
  [`validate_gtfs()`](https://ipea.github.io/gtfstools/reference/validate_gtfs.md)
  and
  [`download_validator()`](https://ipea.github.io/gtfstools/reference/download_validator.md),
  which were not measured. `poa` has no `frequencies`. Functions marked
  with † now do different work (see “Breaking changes”):
  [`merge_gtfs()`](https://ipea.github.io/gtfstools/reference/merge_gtfs.md)
  checks the ids shared by the GTFS objects (with `prefix = TRUE`, it is
  1.2 to 1.8 times faster), and
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md)
  cuts shapes at the trips’ first and last stops. On these small feeds,
  fixed costs dominate:
  [`as_dt_gtfs()`](https://ipea.github.io/gtfstools/reference/as_dt_gtfs.md)
  now converts integer dates (about 1 to 2 milliseconds),
  [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/reference/filter_by_trip_id.md)
  and
  [`filter_by_weekday()`](https://ipea.github.io/gtfstools/reference/filter_by_weekday.md)
  take about 7 milliseconds more, and the deprecated
  [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_shapes_to_sf.md)
  and
  [`convert_stops_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_stops_to_sf.md)
  raise a warning, while their replacements,
  [`get_shapes_geometry()`](https://ipea.github.io/gtfstools/reference/get_shapes_geometry.md)
  and
  [`get_stops_geometry()`](https://ipea.github.io/gtfstools/reference/get_stops_geometry.md),
  are about as fast as they were.

  | function | n times faster on poa | n times faster on spo |
  |----|----|----|
  | [`as_dt_gtfs()`](https://ipea.github.io/gtfstools/reference/as_dt_gtfs.md) | 0.3 | 0.7 |
  | [`convert_sf_to_shapes()`](https://ipea.github.io/gtfstools/reference/convert_sf_to_shapes.md) | 11 | 65 |
  | [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_shapes_to_sf.md) | 0.1 | 0.4 |
  | [`convert_stops_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_stops_to_sf.md) | 0.2 | 0.4 |
  | [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md) | 3.1 | 1.7 |
  | [`filter_by_agency_id()`](https://ipea.github.io/gtfstools/reference/filter_by_agency_id.md) | ~1 | 1.3 |
  | [`filter_by_route_id()`](https://ipea.github.io/gtfstools/reference/filter_by_route_id.md) | ~1 | 3.3 |
  | [`filter_by_route_type()`](https://ipea.github.io/gtfstools/reference/filter_by_route_type.md) | ~1 | 2.5 |
  | [`filter_by_shape_id()`](https://ipea.github.io/gtfstools/reference/filter_by_shape_id.md) | 0.7 | 1.3 |
  | [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/reference/filter_by_spatial_extent.md) | 2.5 | 3.1 |
  | [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/reference/filter_by_stop_id.md) | 3.6 | 3.0 |
  | [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/reference/filter_by_time_of_day.md) | 1.4 | 1.7 |
  | [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/reference/filter_by_trip_id.md) | 0.6 | 0.6 |
  | [`filter_by_weekday()`](https://ipea.github.io/gtfstools/reference/filter_by_weekday.md) | 0.7 | 0.7 |
  | [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/reference/frequencies_to_stop_times.md) | – | 12 |
  | [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/reference/get_stop_times_patterns.md) | 1.4 | ~1 |
  | [`get_trip_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_duration.md) | 3.1 | ~1 |
  | [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md)† | 0.8 | ~1 |
  | [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md)† | 1.9 | ~1 |
  | [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_segment_duration.md) | 64 | 7.9 |
  | [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md)† | 1.4 | ~1 |
  | [`merge_gtfs()`](https://ipea.github.io/gtfstools/reference/merge_gtfs.md)† | 0.1 | 0.1 |
  | [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md) | 1.4 | 1.8 |
  | [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)† | 1.4 | ~1 |
  | [`write_gtfs()`](https://ipea.github.io/gtfstools/reference/write_gtfs.md) | 1.2 | 2.4 |

  Most gains grow with feed size: on a feed with 900,000 `stop_times`
  rows,
  [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md)
  is about 20 times faster,
  [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/reference/filter_by_spatial_extent.md)
  25 times,
  [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/reference/filter_by_time_of_day.md)
  7 times, and
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_segment_duration.md)
  and
  [`get_trip_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_duration.md)
  (when `unit` isn’t `"s"`) 60 and 10 times.
  [`merge_gtfs()`](https://ipea.github.io/gtfstools/reference/merge_gtfs.md)
  with `prefix` is about 2.3 times faster with 1.15 million `stop_times`
  rows,
  [`get_children_stops()`](https://ipea.github.io/gtfstools/reference/get_children_stops.md)
  about 250 times faster with 20,000 stops, and
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md)
  is much faster on feeds with large `calendar_dates` tables.

- [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md),
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md),
  [`get_shape_length()`](https://ipea.github.io/gtfstools/reference/get_shape_length.md),
  [`get_stop_distances()`](https://ipea.github.io/gtfstools/reference/get_stop_distances.md)
  and the functions that use them run their C++ code in parallel, with
  [`data.table::getDTthreads()`](https://rdrr.io/pkg/data.table/man/openmp-utils.html)
  threads (set with
  [`data.table::setDTthreads()`](https://rdrr.io/pkg/data.table/man/openmp-utils.html)),
  or on a single thread where the compiler doesn’t support OpenMP.
  Results don’t depend on the number of threads.

- Trip lengths are always calculated on the
  [s2](https://r-spatial.github.io/s2/) sphere, regardless of
  [`sf::sf_use_s2()`](https://r-spatial.github.io/sf/reference/s2.html).
  [`convert_sf_to_shapes()`](https://ipea.github.io/gtfstools/reference/convert_sf_to_shapes.md)
  also calculates distances on that sphere: they match the previous ones
  within a micrometre with `sf::sf_use_s2(TRUE)` (the default), and
  differ by up to about 0.4% from the ellipsoidal ones previously
  calculated with `sf::sf_use_s2(FALSE)`.

- gtfstools no longer depends on
  [units](https://r-quantities.github.io/units/)
  ([\#84](https://github.com/ipea/gtfstools/issues/84)).
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
  now converts speeds in m/s or mph with exact factors, so in rare
  borderline cases a new time may be one second earlier than in version
  1.4.0.

- [`download_validator()`](https://ipea.github.io/gtfstools/reference/download_validator.md)
  detects the latest validator version automatically. PR contribution by
  [@baarthur](https://github.com/baarthur).

- Invalid dates (e.g. `20240230`) are still converted to `NA`, but now
  with a warning.

- [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/reference/frequencies_to_stop_times.md)
  raises informative errors for invalid `frequencies` entries and trips
  without a `departure_time`.

- The warnings about `route_id`s, `trip_id`s and `stop_id`s not found in
  a feed (classes `gtfstools_invalid_route_id`,
  `gtfstools_invalid_trip_id` and `gtfstools_invalid_stop_id`) list each
  missing id once.

- The documentation website moved to <https://ipea.github.io/gtfstools/>
  and the GitHub repository to <https://github.com/ipea/gtfstools>.

## gtfstools 1.4.0

CRAN release: 2025-01-08

### New features

- [`download_validator()`](https://ipea.github.io/gtfstools/reference/download_validator.md)
  and
  [`validate_gtfs()`](https://ipea.github.io/gtfstools/reference/validate_gtfs.md)
  now support using validator v5.0.0, v5.0.1 and v6.0.0.

### Notes

- Removed the local copies of [cpp11](https://cpp11.r-lib.org)
  functions, as the most recent releases fix the issues we were having.

## gtfstools 1.3.0

CRAN release: 2024-10-07

### New features

- New function
  [`convert_sf_to_shapes()`](https://ipea.github.io/gtfstools/reference/convert_sf_to_shapes.md).
- New generic function
  [`as_dt_gtfs()`](https://ipea.github.io/gtfstools/reference/as_dt_gtfs.md)
  with methods for a few different classes (`tidygtfs`, `gtfs` and
  `list`).
- [gtfstools](https://ipea.github.io/gtfstools/) functions now accepts
  GTFS objects created by other packages, such as
  [gtfsio](https://r-transit.github.io/gtfsio/) and
  [tidytransit](https://github.com/r-transit/tidytransit).
- [`filter_by_route_type()`](https://ipea.github.io/gtfstools/reference/filter_by_route_type.md)
  now accepts Google Transit’s [extended route
  types](https://developers.google.com/transit/gtfs/reference/extended-route-types).
  Thanks [@Ge-Rag](https://github.com/Ge-Rag).
- [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_shapes_to_sf.md),
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md),
  [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md),
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md),
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_segment_duration.md)
  and
  [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/reference/get_stop_times_patterns.md)
  now take an additional argument `sort_sequence`, used to indicate
  whether shapes/timetables should be ordered by
  `shape_pt_sequence`/`stop_sequence` when applying the functions’
  procedures.
- [`download_validator()`](https://ipea.github.io/gtfstools/reference/download_validator.md)
  and
  [`validate_gtfs()`](https://ipea.github.io/gtfstools/reference/validate_gtfs.md)
  now support using validator v4.1.0 and v4.2.0.
- New parameters to
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/reference/filter_by_stop_id.md):
  `include_children` and `include_parents`.

### Bug fixes

- Fixed a bug in
  [`convert_to_standard()`](https://ipea.github.io/gtfstools/reference/convert_to_standard.md)
  in which the date fields from `feed_info` would not be converted back
  to an integer in their standard format (YYYYMMDD).
- Filtering functions now also filter the `transfers` table based on
  `trip_id` and `route_id`. Previously they would filter it based only
  on `stop_id`. Thanks Daniel Langbein
  ([@langbein-daniel](https://github.com/langbein-daniel)).
- Fixed a bug in
  [`filter_by_route_id()`](https://ipea.github.io/gtfstools/reference/filter_by_route_id.md)
  in which feeds with only one agency that omitted `agency_id` in
  `routes` and `fare_attributes` would end up with an empty `agency`
  table.
- [`filter_by_sf()`](https://ipea.github.io/gtfstools/reference/filter_by_sf.md)
  now correctly throws an error when an unsupported function is passed
  to `spatial_operation`.

### Feature deprecation

- The
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/reference/filter_by_stop_id.md)
  behavior of filtering by trips that contain the specified stops has
  been deprecated. For backwards compatibility reasons, this behavior is
  still the default as of the current version and is controlled by the
  parameter `full_trips`. To actually filter by stop ids (the behavior
  that we now believe is the most appropriate), please use
  `full_trips = FALSE`. This behavior will be the default from version
  2.0.0 onward. To achieve the old behavior, manually subset the
  stop_times table by `stop_id` and specify the `trip_id`s included in
  the output in
  [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/reference/filter_by_trip_id.md).
- [`filter_by_sf()`](https://ipea.github.io/gtfstools/reference/filter_by_sf.md)
  has been deprecated in favor of
  [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/reference/filter_by_spatial_extent.md).
  For backwards compatibility reasons, usage of
  [`filter_by_sf()`](https://ipea.github.io/gtfstools/reference/filter_by_sf.md)
  is still allowed as of the current version, but the function will be
  removed from the package in version 2.0.0.

### Notes

- [`validate_gtfs()`](https://ipea.github.io/gtfstools/reference/validate_gtfs.md)
  now defaults to run sequentially. Previously it would default to run
  parallelly using all available cores. Heavily inspired by Henrik
  Bengtsson post “Please Avoid detectCores() in your R packages”
  (<https://www.jottr.org/2022/12/05/avoid-detectcores/>).
- Improved performance of
  [`seconds_to_string()`](https://ipea.github.io/gtfstools/reference/seconds_to_string.md)
  and, consequently, any other functions that use it.
- Improved performance and improved readability of most filtering
  functions.

## gtfstools 1.2.0

CRAN release: 2022-11-24

### New features

- New
  [`validate_gtfs()`](https://ipea.github.io/gtfstools/reference/validate_gtfs.md)
  behavior. Now used to run MobilityData Canonical GTFS validator with a
  feed. The old behavior was marked as deprecated since v1.0.0.
- New function
  [`download_validator()`](https://ipea.github.io/gtfstools/reference/download_validator.md).
- New vignette demonstrating how to validate feeds.

### Bug fixes

- Fixed a bug in
  [`write_gtfs()`](https://ipea.github.io/gtfstools/reference/write_gtfs.md)
  that prevented `as_dir = TRUE` to be used.
- Fixed a bug in
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
  that resulted in invalid stop_times tables when `max(stop_sequence)`
  was higher than the number of stops of a given trip. Thanks Alena
  Stern ([@alenastern](https://github.com/alenastern)).
- Fixed a bug in
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
  that resulted in the speed of wrong trip_ids being updated because of
  the order that these ids would appear in the trips and stop_times
  tables. Thanks Alena Stern
  ([@alenastern](https://github.com/alenastern)).

## gtfstools 1.1.0

CRAN release: 2022-05-24

### New features

- New function
  [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md).
- New function
  [`filter_by_agency_id()`](https://ipea.github.io/gtfstools/reference/filter_by_agency_id.md).
- New function
  [`filter_by_service_id()`](https://ipea.github.io/gtfstools/reference/filter_by_service_id.md).
- New function
  [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/reference/filter_by_time_of_day.md).
- New function
  [`filter_by_weekday()`](https://ipea.github.io/gtfstools/reference/filter_by_weekday.md).
- New function
  [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/reference/frequencies_to_stop_times.md).
- New function
  [`get_children_stops()`](https://ipea.github.io/gtfstools/reference/get_children_stops.md).
- New function
  [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/reference/get_stop_times_patterns.md).
- New function
  [`get_trip_length()`](https://ipea.github.io/gtfstools/reference/get_trip_length.md).
- New parameter to
  [`merge_gtfs()`](https://ipea.github.io/gtfstools/reference/merge_gtfs.md):
  `prefix`. The `warnings` parameter was flagged as deprecated.
- Functions
  [`get_parent_station()`](https://ipea.github.io/gtfstools/reference/get_parent_station.md)
  and `get_children_stops` now accept `stop_id = NULL` to analyze all
  `stop_id`s in the `stops` table.

### Bug fixes

- Fixed a bug in which
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_segment_duration.md)
  would list wrong segment numbers, not necessarily starting from 1. Now
  segment numbers always range from 1 to N, where N is the total number
  of segments that compose each trip.
- Fixed a bug in `filter_by_{route,service,shape,trip}_id()` that
  resulted in the `agency` table not getting filtered when the specified
  id was `character(0)`.

### Notes

- Performance improvements to
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md),
  [`get_trip_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_duration.md),
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/reference/get_trip_segment_duration.md)
  and
  [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_shapes_to_sf.md).
- Stopped ordering points by `shape_pt_sequence`/`stop_sequence` in
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md)
  and
  [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_shapes_to_sf.md),
  since the GTFS reference says that the `stop_times` and `shapes`
  tables must be ordered by point/stop sequence anyway.
- Removed [lwgeom](https://r-spatial.github.io/lwgeom/) from
  dependencies (Suggests), now that it’s not required to run
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md)
  and
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
  anymore.
- Removed the `warnings` parameter from
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md)
  and
  [`write_gtfs()`](https://ipea.github.io/gtfstools/reference/write_gtfs.md)
  and the `optional` and `extra` parameters from
  [`write_gtfs()`](https://ipea.github.io/gtfstools/reference/write_gtfs.md),
  flagged as deprecated on gtfstools v1.0.0.
- Updated filtering vignette to demonstrate new functions.

## gtfstools 1.0.0

CRAN release: 2021-11-16

### New features

- New function
  [`convert_stops_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_stops_to_sf.md).
- New function
  [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/reference/convert_shapes_to_sf.md).
- New function
  [`filter_by_route_type()`](https://ipea.github.io/gtfstools/reference/filter_by_route_type.md).
- New function
  [`filter_by_route_id()`](https://ipea.github.io/gtfstools/reference/filter_by_route_id.md).
- New function
  [`filter_by_sf()`](https://ipea.github.io/gtfstools/reference/filter_by_sf.md).
- New function
  [`filter_by_shape_id()`](https://ipea.github.io/gtfstools/reference/filter_by_shape_id.md).
- New function
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/reference/filter_by_stop_id.md).
- New function
  [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/reference/filter_by_trip_id.md).
- New function
  [`get_parent_station()`](https://ipea.github.io/gtfstools/reference/get_parent_station.md).
- New function
  [`remove_duplicates()`](https://ipea.github.io/gtfstools/reference/remove_duplicates.md).
- New parameters to
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md):
  `fields`, `skip` and `encoding`. The `warnings` parameter was flagged
  as deprecated.
- New parameters to
  [`write_gtfs()`](https://ipea.github.io/gtfstools/reference/write_gtfs.md):
  `files`, `standard_only` and `as_dir`. They substitute the previously
  existent `optional` and `extra`, which were flagged as deprecated. The
  `warnings` parameter was flagged as deprecated too.
- New vignette exploring the filtering functions.

### Bug fixes

- [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md)
  and
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
  examples and tests now only run if
  [lwgeom](https://r-spatial.github.io/lwgeom/) is installed.
  [lwgeom](https://r-spatial.github.io/lwgeom/) is an
  [sf](https://r-spatial.github.io/sf/) “soft” dependency required by
  these functions, and is listed in `Suggests`. However, package checks
  would fail not so gracefully if it wasn’t installed, which is now
  fixed.
- Fixed a bug in which the `crs` passed to
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md)
  would be assigned to the result without actually reprojecting it.
- Changed the behaviour of
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md)
  to not raise an error when the ‘file’ parameter is left untouched and
  the GTFS object doesn’t contain either the shapes or the stop_times
  table. Closes [\#29](https://github.com/ipea/gtfstools/issues/29).
- Fixed a bug that would cause
  [`merge_gtfs()`](https://ipea.github.io/gtfstools/reference/merge_gtfs.md)
  to create objects that inherited only from `dt_gtfs` (ignoring `gtfs`
  and `list`).
- Fixed a bug in which
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/reference/get_trip_speed.md)
  returned `NA` speeds if the specified `trip_id` was listed in trips,
  but not in stop_times.
- Adjusted
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/reference/set_trip_speed.md)
  to stop raising a
  [`max()`](https://rdrr.io/r/base/Extremes.html)-related warning when
  none of the specified `trip_id`s exists.

### Notes

- Some utility functions previously provided by
  [`{gtfs2gps}`](https://github.com/ipea/gtfs2gps) will now be exported
  by [gtfstools](https://ipea.github.io/gtfstools/). Huge thanks to the
  whole [gtfs2gps](https://github.com/ipeaGIT/gtfs2gps) crew (Rafael
  Pereira [@rafapereirabr](https://github.com/rafapereirabr), Pedro
  Andrade [@pedro-andrade-inpe](https://github.com/pedro-andrade-inpe)
  and João Bazzo [@Joaobazzo](https://github.com/Joaobazzo))!
- The package now imports [gtfsio](https://r-transit.github.io/gtfsio/),
  and many functions now heavily rely on it, such as
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md)
  and
  [`write_gtfs()`](https://ipea.github.io/gtfstools/reference/write_gtfs.md).
- Internal function
  [`string_to_seconds()`](https://ipea.github.io/gtfstools/reference/string_to_seconds.md)
  now runs much faster thanks to Mark Padgham
  ([@mpadge](https://github.com/mpadge)).
- [`get_trip_geometry()`](https://ipea.github.io/gtfstools/reference/get_trip_geometry.md)
  now runs much faster due to `data.table`-related optimizations.

### Potentially breaking changes

- Functions no longer validate GTFS objects on usage.
  [`validate_gtfs()`](https://ipea.github.io/gtfstools/reference/validate_gtfs.md)
  will be flagged as deprecated as well, since I plan to heavily change
  its usability and outputs in future versions.
- [`write_gtfs()`](https://ipea.github.io/gtfstools/reference/write_gtfs.md)
  parameters went through major changes - the `optional` and `extra`
  params were flagged as deprecated and substituted by the more general
  `files` and `standard_only`.

## gtfstools 0.1.0

CRAN release: 2021-02-23

- Initial CRAN release.
