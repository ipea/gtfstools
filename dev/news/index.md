# Changelog

## gtfstools (development version)

### Breaking changes

- With `prefix = FALSE`, the default,
  [`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md)
  now keeps rows that are identical in every column only once (as
  [`remove_duplicates()`](https://ipea.github.io/gtfstools/dev/reference/remove_duplicates.md)
  does), and raises an error when the GTFS objects share ids whose data
  differ (such as a `stop_id` with different coordinates, or a `trip_id`
  with different `stop_times`). Merging a feed with itself, or feeds
  that share identical stops, now works, but merging versions of the
  same feed, or unrelated feeds that use simple ids (e.g. both have an
  `agency_id` `"1"`), usually raises the error. Such shared ids made the
  merged feed inconsistent and broke functions such as
  [`get_summary()`](https://ipea.github.io/gtfstools/dev/reference/get_summary.md).
  Use `prefix = TRUE` to make the ids of each GTFS object unique. For
  the same reason, a character `prefix` must now have unique elements.
- [`filter_by_sf()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_sf.md),
  deprecated in version 1.3.0, is now defunct. Use
  [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md),
  which takes the same arguments.
- The `full_trips` argument of
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_stop_id.md),
  deprecated in version 1.3.0, is now defunct, and the function always
  filters by the given stops. To keep entire trips, pass the `trip_id`s
  that serve these stops to
  [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_trip_id.md)
  ([\#75](https://github.com/ipea/gtfstools/issues/75)).
- [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
  now measures each trip from its first to its last stop, instead of
  along its entire shape, so lengths are usually shorter.
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  and
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  use these lengths, so speeds are usually slightly lower, and they now
  also require the `stops` table. Use the new
  [`get_shape_length()`](https://ipea.github.io/gtfstools/dev/reference/get_shape_length.md)
  for the length of entire shapes.
- [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  now returns, by default, the part of each trip’s shape between its
  first and last stops, matching
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
  and requires the `stop_times` and `stops` tables. Use
  [`get_shapes_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_shapes_geometry.md)
  for entire shapes.
- [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md),
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
  and
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  now return one result per trip, without the `origin_file` column.
  Their new `method` argument (and `by`, in the last two) comes right
  after `trip_id`, so `unit` and `file` must now be passed by name.
- The `by_reference` argument of
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  must now be passed by name
  ([\#89](https://github.com/ipea/gtfstools/issues/89)).
- [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  now returns the `route_id` of each trip (or segment) as its first
  column, so it now also requires the `trips` table.
- [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md),
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md),
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md),
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  and
  [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_times_patterns.md)
  now always order `shapes` and `stop_times` by
  `shape_pt_sequence`/`stop_sequence`, so these columns are required.
  Results only change for feeds not ordered by these columns, whose
  previous results were incorrect. Their `sort_sequence` argument is
  deprecated: `sort_sequence = TRUE` raises a warning and
  `sort_sequence = FALSE` raises an error
  ([\#94](https://github.com/ipea/gtfstools/issues/94)).

### Feature deprecation

- [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md)
  and
  [`convert_stops_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_stops_to_sf.md)
  are deprecated in favour of
  [`get_shapes_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_shapes_geometry.md)
  and
  [`get_stops_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_stops_geometry.md),
  which take the same arguments (except the deprecated `sort_sequence`)
  and return the same results. Calling them raises a warning.
- The `file` argument of
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md),
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
  and
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  is deprecated in favour of `method` (`file = "stop_times"` corresponds
  to `method = "euclidean"`).

### New features

- New function
  [`build_graph()`](https://ipea.github.io/gtfstools/dev/reference/build_graph.md),
  which builds a frequency-based transit network from the trips that
  depart within a time of day and returns it as the node, link and
  config tables of the General Modeling Network Specification (GMNS), or
  as an [igraph](https://r.igraph.org/) or
  [tidygraph](https://tidygraph.data-imaginist.com) graph (these
  packages are suggested, and the function offers to install them in
  interactive sessions). The network has a node for each stop and for
  each route and direction at each stop, linked by in-vehicle links
  (with the mean travel time between stops), boarding links (with the
  number of departures and the mean waiting time), alighting links and
  walking transfer links between nearby stops. The direction of trips
  without `direction_id` is inferred from the stops they share. See the
  new “Building transit network graphs” vignette, which also shows how
  to calculate the centrality of stops and how to map the network with
  [sfnetworks](https://luukvdmeer.github.io/sfnetworks/) and
  [ggraph](https://ggraph.data-imaginist.com).
- New function
  [`combine_nearby_stops()`](https://ipea.github.io/gtfstools/dev/reference/combine_nearby_stops.md),
  which combines the stops within a given distance of each other into a
  single stop. Stops are first merged into their parent stations, and
  then by distance, closest pairs first, comparing each station at the
  mean of its platforms’ coordinates. A merged stop gets the ids and
  names of its stops joined by `"-"` and the mean of their coordinates,
  and the ids of merged stops are replaced in `stop_times`, `transfers`
  and the other files that refer to stops. Stations are replaced by the
  stop merged from their platforms, and entrances, generic nodes,
  boarding areas and `pathways` are removed.
- The `path` argument of
  [`download_validator()`](https://ipea.github.io/gtfstools/dev/reference/download_validator.md)
  now defaults to [`tempdir()`](https://rdrr.io/r/base/tempfile.html),
  so the validator is downloaded to a temporary directory unless another
  one is given.
- New function
  [`crop_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/crop_gtfs.md),
  which crops a feed to a spatial extent: it keeps the stops inside it
  (and their parent stations) and the parts of the trips that serve
  them, and, by default, trims the trips’ shapes to their first and last
  remaining stops. Unlike
  [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md),
  which keeps entire trips, trips that leave the spatial extent are cut.
  Blank times at the new ends of cropped trips are interpolated, and the
  `frequencies` of trips whose first stop is dropped are shifted
  accordingly ([\#44](https://github.com/ipea/gtfstools/issues/44)).
  Thanks to [@luukvdmeer](https://github.com/luukvdmeer) for the
  proposal and discussion.
- New function
  [`get_summary()`](https://ipea.github.io/gtfstools/dev/reference/get_summary.md),
  which summarises a feed (its files, agencies, service calendar,
  totals, including the vehicle-kilometres (or vehicle-miles) travelled,
  and the distributions of trip speeds, trip lengths and route
  headways), optionally restricted to some dates, routes, modes,
  agencies and a time of day. It returns a list of `data.table`s and
  writes an HTML report with tables and figures (requires
  [ggplot2](https://ggplot2.tidyverse.org),
  [knitr](https://yihui.org/knitr/),
  [rmarkdown](https://github.com/rstudio/rmarkdown) and Pandoc). With
  `by_route_type = TRUE`, the totals, speeds, lengths and headways are
  also broken down by transport mode
  ([\#127](https://github.com/ipea/gtfstools/issues/127)). Distances and
  speeds are reported in km and km/h, or in miles and mph with
  `unit = "mph"`.
- New function
  [`get_vkt()`](https://ipea.github.io/gtfstools/dev/reference/get_vkt.md),
  which returns the vehicle-kilometres travelled (VKT) by each route:
  the length of each of its trips, counted once for every departure
  (including each departure listed in `frequencies`) on every day on
  which its service runs. VKT can be restricted to some dates and to a
  time of day.
  [`get_vmt()`](https://ipea.github.io/gtfstools/dev/reference/get_vmt.md)
  returns the same measure in vehicle-miles travelled (VMT).
- New function
  [`get_route_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_route_speed.md),
  which returns the minimum, mean, median, maximum and standard
  deviation of the speeds of the trips of each route, as calculated by
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md).
- New function
  [`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md),
  which filters a feed by the services that run on the given dates.
- New function
  [`filter_by_period()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_period.md),
  which filters a feed by the services that run on at least one day of a
  period, given by its first and last dates. By default (`trim = TRUE`),
  the calendars of the kept services are cut to the period, so the feed
  has no service outside it.
- New function
  [`get_shapes_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_shapes_geometry.md),
  which converts the `shapes` table to a `LINESTRING sf` object. It
  replaces
  [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md).
- New function
  [`get_stops_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_stops_geometry.md),
  which converts the `stops` table to a `POINT sf` object. It replaces
  [`convert_stops_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_stops_to_sf.md).
- New function
  [`get_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_stops.md),
  which returns the stops visited by the given trips and/or routes.
- New function
  [`get_stop_distances()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_distances.md),
  which returns the great-circle distances between each pair of stops
  visited by the given trips and/or routes.
- New function
  [`convert_stops_to_shapes()`](https://ipea.github.io/gtfstools/dev/reference/convert_stops_to_shapes.md),
  which creates shapes that link the consecutive stops of trips along
  straight lines, for trips not linked to a usable shape (or for the
  given trips), and assigns them to the trips.
- New function
  [`get_dates()`](https://ipea.github.io/gtfstools/dev/reference/get_dates.md),
  which returns the dates on which a feed has service, as `Date`s or as
  `"YYYYMMDD"` strings.
- New function
  [`get_active_services()`](https://ipea.github.io/gtfstools/dev/reference/get_active_services.md),
  which returns the services active on the given dates.
- New function
  [`get_start_and_end_times()`](https://ipea.github.io/gtfstools/dev/reference/get_start_and_end_times.md),
  which returns the earliest departure time and the latest arrival time
  in `stop_times`, optionally restricted to the given trips and dates.
- New functions
  [`get_stop_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_timetable.md)
  and
  [`get_route_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_route_timetable.md),
  which return the timetables of the given stops and routes on the given
  dates: the stop times of the trips that run on each date, with the
  trip information.
- New function
  [`get_calendar_overlap()`](https://ipea.github.io/gtfstools/dev/reference/get_calendar_overlap.md),
  which returns the number of trips each GTFS feed runs on each of its
  service days (counting the departures listed in `frequencies`) and
  whether all feeds have service on that day, helping to pick a date on
  which several feeds can be analysed together (e.g. in routing and
  accessibility analyses). With `resolution = "periods"`, it returns the
  periods in which all feeds have service. `plot = TRUE` plots either
  result (requires [ggplot2](https://ggplot2.tidyverse.org)): a box plot
  of when each feed’s trips run, or a timeline of its service periods. A
  message is printed when the feeds have no day with service in all of
  them. Feeds may be given as paths or as a list of GTFS objects. See
  the new “Checking the calendar overlap of GTFS feeds” vignette
  ([\#85](https://github.com/ipea/gtfstools/issues/85)). Thanks
  [@higgicd](https://github.com/higgicd) for the suggestion and the
  original `check_gtfs_overlap()` code.
- New functions
  [`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md)
  and
  [`get_stop_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_frequency.md),
  which return the number of departures and the mean headway of each
  route and at each stop within a time of day
  ([\#53](https://github.com/ipea/gtfstools/issues/53)).
- New function
  [`stop_times_to_frequencies()`](https://ipea.github.io/gtfstools/dev/reference/stop_times_to_frequencies.md),
  the counterpart of
  [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md),
  which approximates scheduled trips by frequency-based ones
  ([\#69](https://github.com/ipea/gtfstools/issues/69)).
- New function
  [`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md),
  which fills blank `arrival_time`s and `departure_time`s in
  `stop_times`, assuming a constant speed between stops with known
  times.
- New function
  [`interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_shape_dist_traveled.md),
  which calculates the distance, in meters, from the start of each shape
  to each stop and shape point, and writes it to the
  `shape_dist_traveled` columns of `stop_times` and `shapes`, replacing
  any existing values. Stops are located along the shapes as in
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md).
- New function
  [`convert_seconds_to_time()`](https://ipea.github.io/gtfstools/dev/reference/convert_seconds_to_time.md),
  the counterpart of
  [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md),
  which converts seconds after midnight to strings in the “HH:MM:SS”
  format.
- New function
  [`set_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/set_route_frequency.md),
  the editing counterpart of
  [`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md),
  which sets the headway of routes within a time of day by replacing
  their trips in it with a frequency-based template trip. Departures
  outside the time of day don’t change. With `route_type`, it changes
  only the routes of the given transport modes (all of them if
  `route_id` is not given).
- New function
  [`set_route_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_route_speed.md),
  the route counterpart of
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md),
  which sets the average speed of all trips of the given routes
  (optionally only of a segment between two stops, only of trips
  departing within a time of day, and only of the given transport modes,
  with `route_type`).
- New functions
  [`get_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/get_dwell_time.md)
  and
  [`set_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_dwell_time.md),
  which return and set how long vehicles stay at stops, optionally
  within a time of day.
  [`set_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_dwell_time.md)
  shifts the later times of each trip accordingly, and can be restricted
  to the trips of the given transport modes (`route_type`).
- New function
  [`set_max_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_max_speed.md),
  which caps the speed of the given trips and/or routes. Each part of a
  trip faster than the maximum speed is slowed down to it, and the later
  times of the trip are shifted accordingly. Like
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md),
  it can cap speeds only between two stops (`first_stop`, `last_stop`),
  for trips departing within a time of day (`from`, `to`), and for trips
  of the given transport modes (`route_type`).
- New function
  [`set_min_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_min_dwell_time.md),
  which makes vehicles stay at least a minimum time at the intermediate
  stops of the given trips, raising only shorter dwell times and
  shifting the later times of each trip accordingly.
- New function
  [`fix_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/fix_gtfs.md),
  a wrapper that cleans a feed in one call: it removes duplicated
  entries and unused ids, optionally caps the speed of trips with
  [`set_max_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_max_speed.md),
  fills blank stop times with
  [`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md),
  optionally sets a minimum dwell time at the intermediate stops of each
  trip with
  [`set_min_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_min_dwell_time.md)
  and, in feeds with shapes, recalculates the distances travelled along
  shapes with
  [`interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_shape_dist_traveled.md),
  replacing any existing `shape_dist_traveled` values.
- New function
  [`get_shape_length()`](https://ipea.github.io/gtfstools/dev/reference/get_shape_length.md),
  which returns the length of each shape.
- New function
  [`get_route_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_route_geometry.md),
  which returns the distinct trip geometries of each route (e.g. each
  direction and short-turn service), as generated by
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md),
  with the `trip_id` that identifies each of them (`trip_pattern`, the
  first `trip_id` of the trips that follow it) and the number of trips
  that follow each of them.
- New function
  [`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md),
  which removes unused ids from all files
  ([\#55](https://github.com/ipea/gtfstools/issues/55)).
- New function
  [`list_validator_versions()`](https://ipea.github.io/gtfstools/dev/reference/list_validator_versions.md),
  which lists the available validator versions. PR contribution by
  [@baarthur](https://github.com/baarthur).
- [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
  and
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  gain the `by` argument, to calculate lengths and speeds between
  consecutive stops. They and
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  gain the `method` argument, to measure along the trip’s shape or as
  straight lines between stops. Without shapes, they now fall back to
  straight lines with a warning, instead of raising an error.
- [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  gains the `first_stop`, `last_stop`, `from` and `to` arguments, to
  change speeds only between two stops and only for trips departing
  within a time of day
  ([\#89](https://github.com/ipea/gtfstools/issues/89)).
- [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  gains the `route_type` argument, to change only the trips of the given
  transport modes. It restricts the trips given in `trip_id`, or, on its
  own, sets the speed of all the trips of these modes, so `trip_id` is
  now optional.
- [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  and
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  now accept `unit = "mph"`, for speeds in miles per hour.
- [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md),
  [`get_route_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_route_speed.md),
  [`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md),
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
  and
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  gain the `from` and `to` arguments, as in
  [`get_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/get_dwell_time.md),
  to include only the trips that depart from their first stop within a
  time of day (or, for segment results, only the segments that depart
  within it).
- [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
  gains the `strategy` argument, to shift the departures of
  frequency-based trips by half the headway or by a random offset
  ([\#56](https://github.com/ipea/gtfstools/issues/56)).
- [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md)
  gains the `compression_level` argument. Its default, 6 (previously
  always 9), makes writing about 2 to 3 times faster for files of very
  similar size.
- New vignette “Editing GTFS feeds”, which lists the functions that edit
  feeds and demonstrates
  [`set_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/set_route_frequency.md),
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md),
  [`stop_times_to_frequencies()`](https://ipea.github.io/gtfstools/dev/reference/stop_times_to_frequencies.md),
  [`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md)
  and
  [`fix_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/fix_gtfs.md).
- New vignette “Querying GTFS feeds”, which demonstrates
  [`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md),
  [`get_stop_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_frequency.md),
  [`get_stop_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_timetable.md),
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
  [`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md),
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md),
  [`get_route_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_route_speed.md)
  and
  [`get_summary()`](https://ipea.github.io/gtfstools/dev/reference/get_summary.md).
- New vignette “Mapping GTFS feeds”, which maps the transit network,
  routes by speed and stops by frequency with
  [`get_shapes_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_shapes_geometry.md),
  [`get_route_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_route_geometry.md),
  [`get_route_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_route_speed.md)
  and
  [`get_stops_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_stops_geometry.md).

### Bug fixes

- Fixed a bug in
  [`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md)
  that, when the GTFS objects were passed with names
  (e.g. `merge_gtfs(a = gtfs1, b = gtfs2, prefix = TRUE)`), prefixed the
  ids with `"NA_"` instead of the given prefixes.
- [`download_validator()`](https://ipea.github.io/gtfstools/dev/reference/download_validator.md)
  and
  [`list_validator_versions()`](https://ipea.github.io/gtfstools/dev/reference/list_validator_versions.md)
  now fail gracefully on network problems, as CRAN requires: they retry
  transient failures and, if GitHub still can’t be reached, inform that
  with a message (class `gtfstools_validator_download_failure`) and
  invisibly return `NULL`, instead of raising an error. Previously,
  [`download_validator()`](https://ipea.github.io/gtfstools/dev/reference/download_validator.md)
  reported any network problem as a misleading “invalid URL” error. A
  version that doesn’t exist still raises an error, now with its own
  class (`gtfstools_invalid_validator_version`).
- [`download_validator()`](https://ipea.github.io/gtfstools/dev/reference/download_validator.md)
  now downloads the validator only once, instead of twice. When an
  explicit `version` was already downloaded to `path`, it no longer goes
  online at all. With `quiet = FALSE`, it now shows a progress bar.
- [`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md),
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  and
  [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md)
  no longer add temporary columns to the `stop_times` table (and, in
  [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md),
  the `frequencies` table) of the given GTFS object, which could be left
  behind if an error happened during the calculation.
- The `filter_by_*()` functions no longer drop:
  - rows whose blank keys mean “applies to all”: zone `fare_rules`
    without `route_id`, `transfers` without `from_stop_id`/`to_stop_id`
    and `attributions` without `agency_id`;
  - the `agency` of single-agency feeds whose `routes.agency_id` is
    blank or absent;
  - the station entrances, generic nodes and boarding areas of kept
    stations and platforms, with their pathways and levels.
- [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_trip_id.md),
  [`filter_by_service_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_service_id.md)
  and
  [`filter_by_shape_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_shape_id.md),
  and the functions built on them (such as
  [`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md),
  [`filter_by_period()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_period.md),
  [`filter_by_weekday()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_weekday.md)
  and
  [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md)),
  no longer keep `fare_attributes` (and their agencies) whose
  `fare_rules` were all dropped by zone.
- [`filter_by_route_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_id.md)
  and
  [`filter_by_route_type()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_type.md)
  filtered `fare_rules` by `level_id` instead of `route_id`.
- [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md):
  - with `keep = TRUE`, now sets the `end_time` of `frequencies` entries
    that cross `to` to one second after `to`, so that a departure at
    `to` is no longer lost by
    [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md);
  - updates the `start_time` of `frequencies` entries with a blank
    `exact_times`;
  - no longer returns frequency-based trips whose `frequencies` entries
    were all filtered out;
  - with `keep = FALSE` and `full_trips = TRUE`, no longer drops every
    trip with an untimed stop;
  - rejects `from`/`to` values with minutes or seconds of 60 or more;
  - keeps `frequencies` entries that start exactly at `to`, whose first
    departure is within the time of day (this also affects
    [`get_summary()`](https://ipea.github.io/gtfstools/dev/reference/get_summary.md)
    with `from` and `to`);
  - with `keep = FALSE`, drops a departure at `to`: entries crossing
    `to` now start one second after it, or at the next departure with
    `exact_times = 1`. Entries left without any departure are removed;
  - no longer modifies the `frequencies` table of the given feed when
    all of its entries are selected.
- [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md)
  no longer errors when stops have missing coordinates, and with
  `keep = FALSE` drops every selected trip. It now filters the feed only
  once, so shapes not used by any trip are no longer kept and duplicated
  rows are no longer removed.
- Fixed a bug in
  [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md)
  in which a `bbox` passed to `geom` was converted to a slightly larger
  polygon with curved edges, so shapes and trips near its edges could be
  wrongly kept or dropped. A `bbox` is now treated as a rectangle in
  longitude and latitude.
- [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_stop_id.md)
  no longer adds a `.flagged` column to the `fare_rules` table of the
  given feed.
- [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
  treats `end_time` as exclusive, as required by the GTFS specification:
  an entry from 08:00 to 09:00 with a 30-minute headway now yields trips
  at 08:00 and 08:30 only.
- Functions that convert times to seconds now convert malformed times
  (e.g. `"5:30"`, `"12:60:00"`) to `NA` with a warning, instead of
  silently returning wrong values. Non-ASCII strings marked as `"bytes"`
  also become `NA` with a warning, instead of raising an error.
  [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md)
  also no longer skips `arrival_time` and `end_time` when only one
  column of a pair is present.
- [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_times_patterns.md)
  no longer ignores stop timing for spatiotemporal patterns of trips
  with blank stop times, and no longer merges different stop sequences
  whose `stop_id`s contain `;` or `|`.
- [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  now identifies the first stop of each trip by `stop_sequence` instead
  of row position, and keeps existing `*_secs` columns in sync with the
  updated times.
- [`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md)
  no longer returns `NA` rows for stops without a `parent_station`.
- [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md)
  no longer keeps doubled quotes inside quoted text fields, and
  [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md)
  always writes text as UTF-8, also when the feed was read with
  `encoding = "Latin-1"`.
- [`as_dt_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/as_dt_gtfs.md)
  no longer turns `Date` fields into `NA`, and converts the date fields
  of lists to `Date`.
- [`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md)
  no longer prefixes the `field_value` and `record_sub_id` columns of
  `translations`, no longer errors with character columns of unknown
  type, and keeps parent station ids. PR contributions by
  [@gmatosferreira](https://github.com/gmatosferreira) and
  [@haneroglu](https://github.com/haneroglu).
- The `filter_by_*()` functions no longer drop every `fare_attributes`
  entry of feeds without a `fare_rules` table, whose fares apply to all
  routes of their agency. In multi-agency feeds, they keep the fares of
  the agencies whose routes were kept, and the fares without an agency.
- [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  now raises an error when `speed` is zero or negative, instead of
  setting invalid times.
- [`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md)
  now returns `NA`, with a warning, for trips without any arrival time
  or without any departure time, instead of `-Inf` (or an error) with
  base R warnings.
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  raises the same warning.
- Functions that measure trips along their shapes (such as
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md),
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  and
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md))
  now raise an informative error when a used shape has a blank
  `shape_id`, instead of an obscure one.
- [`list_validator_versions()`](https://ipea.github.io/gtfstools/dev/reference/list_validator_versions.md)
  now returns its result visibly.
- [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md)
  no longer accepts
  [`sf::st_equals_exact()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html)
  and
  [`sf::st_is_within_distance()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html)
  as `spatial_operation`, since they always failed for lack of their
  additional arguments.
- [`remove_duplicates()`](https://ipea.github.io/gtfstools/dev/reference/remove_duplicates.md)
  no longer corrupts elements that are not tables, such as the
  `locations` of GTFS-Flex feeds.
- [`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md)
  no longer corrupts elements that are not tables, such as the
  `locations` of GTFS-Flex feeds: they are left out of the merged feed,
  with a warning.
- [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  and
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  now ignore `stop_times` entries with a missing or blank `trip_id`,
  which used to shift the segments of every other trip with
  `by = "segment"`.
- [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
  no longer errors when a dwell time at the first stop makes an arrival
  fall before 00:00:00; such arrivals are set to 00:00:00.
- [`filter_by_agency_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_agency_id.md)
  now keeps the `fare_attributes` without an `agency_id`.
- [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  now also raises an error when `speed` is infinite, or when the same
  trip is given different speeds.
- Documentation:
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_stop_id.md)
  now correctly describes that it keeps (or drops) the `stop_times`
  entries at the given stops, not entire trips.

### Notes

- [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  and the functions that use them
  ([`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md),
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  and
  [`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md)),
  as well as
  [`get_shape_length()`](https://ipea.github.io/gtfstools/dev/reference/get_shape_length.md)
  and
  [`get_stop_distances()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_distances.md),
  now run their C++ code in parallel, using as many threads as
  [`data.table::getDTthreads()`](https://rdrr.io/pkg/data.table/man/openmp-utils.html)
  (change it with
  [`data.table::setDTthreads()`](https://rdrr.io/pkg/data.table/man/openmp-utils.html)).
  On a feed with 900,000 shape points and 2,200 trip patterns, with 6
  threads,
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
  and
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  are about 2 to 2.5 times faster, and
  [`get_shape_length()`](https://ipea.github.io/gtfstools/dev/reference/get_shape_length.md)
  and
  [`get_stop_distances()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_distances.md)
  about 2 times faster. Stops are also located along all shapes in a
  single call, which makes
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
  about 15% faster even with a single thread. Results don’t depend on
  the number of threads. On platforms whose compilers don’t support
  OpenMP, the code runs on a single thread.

- [`get_stop_distances()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_distances.md)
  is about 1.5 times faster and allocates about 35% less memory than in
  earlier development versions (on a feed with 1.9 million pairs of
  stops), as the radians and the cosine of the latitude of each stop are
  calculated only once. Results are unchanged, up to floating-point
  rounding on some platforms.

- [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
  and the functions that use it
  ([`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md),
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md),
  [`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md),
  [`interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_shape_dist_traveled.md)
  and
  [`crop_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/crop_gtfs.md))
  are about 1.3 times faster than in earlier development versions, and
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  about 1.05 to 1.25 times faster (on a feed with 900,000 shape points
  and 2,200 trip patterns and on smaller feeds, with 2 threads), as each
  stop is now compared only with the parts of its trip’s shape near it,
  instead of with the whole shape. Results are unchanged.

- gtfstools no longer depends on
  [units](https://r-quantities.github.io/units/)
  ([\#84](https://github.com/ipea/gtfstools/issues/84)).
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  now converts speeds given in m/s or mph with exact factors (1 m/s =
  3.6 km/h, 1 mile = 1.609344 km), the same ones
  [`set_max_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_max_speed.md)
  uses, so in rare borderline cases the new times of a trip may be one
  second earlier than in version 1.4.0, which converted m/s through
  [units](https://r-quantities.github.io/units/).

- [`download_validator()`](https://ipea.github.io/gtfstools/dev/reference/download_validator.md)
  now automatically detects the latest validator version. PR
  contribution by [@baarthur](https://github.com/baarthur).

- Invalid dates (e.g. `20240230`) are still converted to `NA` when
  reading or converting feeds, but now with a warning.

- [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
  now raises informative errors for invalid `frequencies` entries and
  for trips without a `departure_time`.

- Trip lengths are now always calculated on the
  [s2](https://r-spatial.github.io/s2/) sphere, regardless of
  [`sf::sf_use_s2()`](https://r-spatial.github.io/sf/reference/s2.html).

- [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  is slower with the default `method = "shapes"`, as it locates stops
  along shapes: on a feed with 15,000 trips and 920,000 `stop_times`
  rows, about 0.8 seconds instead of 0.02 seconds for the entire shapes.

- [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_times_patterns.md)
  is about 2 times faster on a feed with 1,700 `stop_times` rows, as
  trips are compared without building text keys from their stops and
  times.
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
  and
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  also no longer build such keys when locating stops along shapes.

- [`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md)
  is now much faster on large feeds (about 250x faster with 20,000
  stops).

- Converting date fields when reading and writing feeds
  ([`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md),
  [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md),
  [`as_dt_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/as_dt_gtfs.md))
  is now much faster (about 200x faster for the date conversion itself),
  noticeably speeding up
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md)
  on feeds with large `calendar_dates` tables.

- Converting times between `"HH:MM:SS"` strings and seconds is now
  faster, as each distinct time is converted only once and parsed
  without being copied. This speeds up
  [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md)
  (about 20 times faster on a feed with 900,000 `stop_times` rows),
  [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md)
  (about 7 times faster on the same feed) and, to a lesser extent, the
  other functions that convert times.

- [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  and
  [`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md)
  are much faster when `unit` is not `"s"` (about 60 and 10 times
  faster, respectively, on a feed with 900,000 `stop_times` rows).

- [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
  is much faster (about 13 times faster when converting a feed into
  300,000 `stop_times` rows), as it creates all new trips at once
  instead of one at a time. It also no longer adds and then removes
  auxiliary columns from the tables of the given feed.

- [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md)
  is much faster and uses much less memory (about 25 times faster on a
  feed with 900,000 `stop_times` rows), as it filters the feed only once
  and doesn’t create geometries for trips already selected by their
  shapes.

- [`convert_sf_to_shapes()`](https://ipea.github.io/gtfstools/dev/reference/convert_sf_to_shapes.md)
  is much faster (about 30 times faster with
  `calculate_distance = FALSE` and 70 times faster with
  `calculate_distance = TRUE` on a feed with 50,000 shape points), as it
  no longer casts the linestrings to points and calculates
  `shape_dist_traveled` with a vectorised haversine formula. Distances
  are calculated on the same sphere used by
  [s2](https://r-spatial.github.io/s2/), so they match the previous
  results (with `sf::sf_use_s2(TRUE)`, the default) to within a
  micrometre. With `sf::sf_use_s2(FALSE)`, the previous version
  calculated ellipsoidal distances, which differ from the spherical ones
  by up to about 0.4%; distances are now always spherical.

- [`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md)
  with `prefix` is about 2.3 times faster on a feed with 1.15 million
  `stop_times` rows, as each distinct id is prefixed only once.
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md),
  `get_trip_geometry(method = "euclidean")` (which now builds the
  geometry of each distinct sequence of stops only once) and the
  functions that count the departures of scheduled trips, such as
  [`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md),
  are slightly faster. Results are unchanged.

- The table below compares the speed of each exported function with the
  CRAN release (1.4.0), on the example feeds shipped with the package
  (each stacked twice with
  [`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md)),
  with the default number of threads. Values are how many times faster
  each function is: values below 1 mean it is slower, and ~1 means a
  difference under about 1.2 times, within measurement noise. Functions
  marked with † now measure trips differently (see “Breaking changes”),
  so they do different work than before:
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md),
  for instance, is slower because it now cuts the shapes between the
  trips’ first and last stops.
  [`as_dt_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/as_dt_gtfs.md)
  is slower because it now converts integer dates (a fixed cost of about
  1 to 1.5 milliseconds), and
  [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md)
  because it now always sorts the shape points by `shape_pt_sequence`.
  [`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md)
  and
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  used `unit = "min"`,
  [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md)
  used the western half of each feed’s extent,
  [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md)
  kept the period from 07:00 to 09:00, and the other `filter_by_*()`
  functions kept half of the ids. The poa feed has no `frequencies`
  table, and neither feed has the `parent_station` column used by
  [`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md)
  and
  [`get_parent_station()`](https://ipea.github.io/gtfstools/dev/reference/get_parent_station.md).
  [`validate_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/validate_gtfs.md)
  and
  [`download_validator()`](https://ipea.github.io/gtfstools/dev/reference/download_validator.md)
  were not measured.

  | function | n times faster on poa | n times faster on spo |
  |----|----|----|
  | [`convert_sf_to_shapes()`](https://ipea.github.io/gtfstools/dev/reference/convert_sf_to_shapes.md) | 12 | 42 |
  | [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md) | 2.4 | ~1 |
  | [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md) | 3.3 | 2.4 |
  | [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_stop_id.md) | 5.3 | 4.6 |
  | [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md) | 1.4 | ~1 |
  | [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md) | – | 5.2 |
  | [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_times_patterns.md) | 1.6 | 1.5 |
  | [`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md) | 2.2 | ~1 |
  | [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)† | 1.7 | ~1 |
  | [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md) | 27 | 2.7 |
  | [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)† | 1.2 | ~1 |
  | [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)† | 1.2 | 0.7 |
  | [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md) | 1.7 | 1.9 |

- The package documentation website moved to
  <https://ipea.github.io/gtfstools/> and the GitHub repository to
  <https://github.com/ipea/gtfstools>. All links were updated.

- The warnings about `route_id`s, `trip_id`s and `stop_id`s not found in
  a feed (classes `gtfstools_invalid_route_id`,
  `gtfstools_invalid_trip_id` and `gtfstools_invalid_stop_id`) now list
  each missing id once.
  [`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md),
  [`get_stop_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_frequency.md),
  [`get_vkt()`](https://ipea.github.io/gtfstools/dev/reference/get_vkt.md)
  and
  [`set_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/set_route_frequency.md)
  used to list an id that was given twice, twice.

## gtfstools 1.4.0

CRAN release: 2025-01-08

### New features

- [`download_validator()`](https://ipea.github.io/gtfstools/dev/reference/download_validator.md)
  and
  [`validate_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/validate_gtfs.md)
  now support using validator v5.0.0, v5.0.1 and v6.0.0.

### Notes

- Removed the local copies of [cpp11](https://cpp11.r-lib.org)
  functions, as the most recent releases fix the issues we were having.

## gtfstools 1.3.0

CRAN release: 2024-10-07

### New features

- New function
  [`convert_sf_to_shapes()`](https://ipea.github.io/gtfstools/dev/reference/convert_sf_to_shapes.md).
- New generic function
  [`as_dt_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/as_dt_gtfs.md)
  with methods for a few different classes (`tidygtfs`, `gtfs` and
  `list`).
- [gtfstools](https://ipea.github.io/gtfstools/) functions now accepts
  GTFS objects created by other packages, such as
  [gtfsio](https://r-transit.github.io/gtfsio/) and
  [tidytransit](https://github.com/r-transit/tidytransit).
- [`filter_by_route_type()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_type.md)
  now accepts Google Transit’s [extended route
  types](https://developers.google.com/transit/gtfs/reference/extended-route-types).
  Thanks [@Ge-Rag](https://github.com/Ge-Rag).
- [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md),
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md),
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md),
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  and
  [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_times_patterns.md)
  now take an additional argument `sort_sequence`, used to indicate
  whether shapes/timetables should be ordered by
  `shape_pt_sequence`/`stop_sequence` when applying the functions’
  procedures.
- [`download_validator()`](https://ipea.github.io/gtfstools/dev/reference/download_validator.md)
  and
  [`validate_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/validate_gtfs.md)
  now support using validator v4.1.0 and v4.2.0.
- New parameters to
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_stop_id.md):
  `include_children` and `include_parents`.

### Bug fixes

- Fixed a bug in
  [`convert_to_standard()`](https://ipea.github.io/gtfstools/dev/reference/convert_to_standard.md)
  in which the date fields from `feed_info` would not be converted back
  to an integer in their standard format (YYYYMMDD).
- Filtering functions now also filter the `transfers` table based on
  `trip_id` and `route_id`. Previously they would filter it based only
  on `stop_id`. Thanks Daniel Langbein
  ([@langbein-daniel](https://github.com/langbein-daniel)).
- Fixed a bug in
  [`filter_by_route_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_id.md)
  in which feeds with only one agency that omitted `agency_id` in
  `routes` and `fare_attributes` would end up with an empty `agency`
  table.
- [`filter_by_sf()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_sf.md)
  now correctly throws an error when an unsupported function is passed
  to `spatial_operation`.

### Feature deprecation

- The
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_stop_id.md)
  behavior of filtering by trips that contain the specified stops has
  been deprecated. For backwards compatibility reasons, this behavior is
  still the default as of the current version and is controlled by the
  parameter `full_trips`. To actually filter by stop ids (the behavior
  that we now believe is the most appropriate), please use
  `full_trips = FALSE`. This behavior will be the default from version
  2.0.0 onward. To achieve the old behavior, manually subset the
  stop_times table by `stop_id` and specify the `trip_id`s included in
  the output in
  [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_trip_id.md).
- [`filter_by_sf()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_sf.md)
  has been deprecated in favor of
  [`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md).
  For backwards compatibility reasons, usage of
  [`filter_by_sf()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_sf.md)
  is still allowed as of the current version, but the function will be
  removed from the package in version 2.0.0.

### Notes

- [`validate_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/validate_gtfs.md)
  now defaults to run sequentially. Previously it would default to run
  parallelly using all available cores. Heavily inspired by Henrik
  Bengtsson post “Please Avoid detectCores() in your R packages”
  (<https://www.jottr.org/2022/12/05/avoid-detectcores/>).
- Improved performance of
  [`seconds_to_string()`](https://ipea.github.io/gtfstools/dev/reference/seconds_to_string.md)
  and, consequently, any other functions that use it.
- Improved performance and improved readability of most filtering
  functions.

## gtfstools 1.2.0

CRAN release: 2022-11-24

### New features

- New
  [`validate_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/validate_gtfs.md)
  behavior. Now used to run MobilityData Canonical GTFS validator with a
  feed. The old behavior was marked as deprecated since v1.0.0.
- New function
  [`download_validator()`](https://ipea.github.io/gtfstools/dev/reference/download_validator.md).
- New vignette demonstrating how to validate feeds.

### Bug fixes

- Fixed a bug in
  [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md)
  that prevented `as_dir = TRUE` to be used.
- Fixed a bug in
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  that resulted in invalid stop_times tables when `max(stop_sequence)`
  was higher than the number of stops of a given trip. Thanks Alena
  Stern ([@alenastern](https://github.com/alenastern)).
- Fixed a bug in
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  that resulted in the speed of wrong trip_ids being updated because of
  the order that these ids would appear in the trips and stop_times
  tables. Thanks Alena Stern
  ([@alenastern](https://github.com/alenastern)).

## gtfstools 1.1.0

CRAN release: 2022-05-24

### New features

- New function
  [`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md).
- New function
  [`filter_by_agency_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_agency_id.md).
- New function
  [`filter_by_service_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_service_id.md).
- New function
  [`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md).
- New function
  [`filter_by_weekday()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_weekday.md).
- New function
  [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md).
- New function
  [`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md).
- New function
  [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_times_patterns.md).
- New function
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md).
- New parameter to
  [`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md):
  `prefix`. The `warnings` parameter was flagged as deprecated.
- Functions
  [`get_parent_station()`](https://ipea.github.io/gtfstools/dev/reference/get_parent_station.md)
  and `get_children_stops` now accept `stop_id = NULL` to analyze all
  `stop_id`s in the `stops` table.

### Bug fixes

- Fixed a bug in which
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  would list wrong segment numbers, not necessarily starting from 1. Now
  segment numbers always range from 1 to N, where N is the total number
  of segments that compose each trip.
- Fixed a bug in `filter_by_{route,service,shape,trip}_id()` that
  resulted in the `agency` table not getting filtered when the specified
  id was `character(0)`.

### Notes

- Performance improvements to
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md),
  [`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md),
  [`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
  and
  [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md).
- Stopped ordering points by `shape_pt_sequence`/`stop_sequence` in
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  and
  [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md),
  since the GTFS reference says that the `stop_times` and `shapes`
  tables must be ordered by point/stop sequence anyway.
- Removed [lwgeom](https://r-spatial.github.io/lwgeom/) from
  dependencies (Suggests), now that it’s not required to run
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  and
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  anymore.
- Removed the `warnings` parameter from
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md)
  and
  [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md)
  and the `optional` and `extra` parameters from
  [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md),
  flagged as deprecated on gtfstools v1.0.0.
- Updated filtering vignette to demonstrate new functions.

## gtfstools 1.0.0

CRAN release: 2021-11-16

### New features

- New function
  [`convert_stops_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_stops_to_sf.md).
- New function
  [`convert_shapes_to_sf()`](https://ipea.github.io/gtfstools/dev/reference/convert_shapes_to_sf.md).
- New function
  [`filter_by_route_type()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_type.md).
- New function
  [`filter_by_route_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_id.md).
- New function
  [`filter_by_sf()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_sf.md).
- New function
  [`filter_by_shape_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_shape_id.md).
- New function
  [`filter_by_stop_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_stop_id.md).
- New function
  [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_trip_id.md).
- New function
  [`get_parent_station()`](https://ipea.github.io/gtfstools/dev/reference/get_parent_station.md).
- New function
  [`remove_duplicates()`](https://ipea.github.io/gtfstools/dev/reference/remove_duplicates.md).
- New parameters to
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md):
  `fields`, `skip` and `encoding`. The `warnings` parameter was flagged
  as deprecated.
- New parameters to
  [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md):
  `files`, `standard_only` and `as_dir`. They substitute the previously
  existent `optional` and `extra`, which were flagged as deprecated. The
  `warnings` parameter was flagged as deprecated too.
- New vignette exploring the filtering functions.

### Bug fixes

- [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  and
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
  examples and tests now only run if
  [lwgeom](https://r-spatial.github.io/lwgeom/) is installed.
  [lwgeom](https://r-spatial.github.io/lwgeom/) is an
  [sf](https://r-spatial.github.io/sf/) “soft” dependency required by
  these functions, and is listed in `Suggests`. However, package checks
  would fail not so gracefully if it wasn’t installed, which is now
  fixed.
- Fixed a bug in which the `crs` passed to
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  would be assigned to the result without actually reprojecting it.
- Changed the behaviour of
  [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  to not raise an error when the ‘file’ parameter is left untouched and
  the GTFS object doesn’t contain either the shapes or the stop_times
  table. Closes [\#29](https://github.com/ipea/gtfstools/issues/29).
- Fixed a bug that would cause
  [`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md)
  to create objects that inherited only from `dt_gtfs` (ignoring `gtfs`
  and `list`).
- Fixed a bug in which
  [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
  returned `NA` speeds if the specified `trip_id` was listed in trips,
  but not in stop_times.
- Adjusted
  [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
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
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md)
  and
  [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md).
- Internal function
  [`string_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/string_to_seconds.md)
  now runs much faster thanks to Mark Padgham
  ([@mpadge](https://github.com/mpadge)).
- [`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
  now runs much faster due to `data.table`-related optimizations.

### Potentially breaking changes

- Functions no longer validate GTFS objects on usage.
  [`validate_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/validate_gtfs.md)
  will be flagged as deprecated as well, since I plan to heavily change
  its usability and outputs in future versions.
- [`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md)
  parameters went through major changes - the `optional` and `extra`
  params were flagged as deprecated and substituted by the more general
  `files` and `standard_only`.

## gtfstools 0.1.0

CRAN release: 2021-02-23

- Initial CRAN release.
