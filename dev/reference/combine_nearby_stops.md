# Combine nearby stops

Merges the stops that are within a given distance of each other into a
single stop, and updates the tables that refer to them. Useful to build
routing networks or to analyse the feed by station rather than by
platform.

## Usage

``` r
combine_nearby_stops(gtfs, max_dist)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- max_dist:

  A number. The maximum distance, in meters, between two stops merged
  together.

## Value

The GTFS object with the merged stops.

## Details

Stops with a `parent_station` are first merged into one stop with the
`stop_id` of the station, regardless of the distance between them, named
after the station if it's listed in `stops` or else after its platforms.
Stops are then merged by distance, closest pairs first, so that every
pair of stops merged together is at most `max_dist` apart (great-circle
distance, as in
[`get_stop_distances()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_distances.md)).
Stops already merged by their parent station are compared by the mean of
their coordinates, so their own platforms may be farther apart. Stops
without coordinates are only merged by their parent station.

A merged stop has a `stop_id` and a `stop_name` made of the ids and
names of the merged stops joined by `"-"` (repeated names listed once)
and the mean of their coordinates; its other fields (e.g. `zone_id`,
`level_id`) are those of the merged stop whose `stop_id` comes first.
Only the first entry of a `stop_id` listed more than once in `stops` is
used. Merged `stop_id`s are ambiguous when the original `stop_id`s
include `"-"`, and an error is raised if two resulting `stop_id`s are
identical.

The result has only plain stops (`location_type` 0) without
`parent_station`: stations are replaced by the stop merged from their
platforms, and stations without platforms, entrances, generic nodes,
boarding areas and `pathways` are removed. The `stop_id`s of merged
stops and stations are updated in `stop_times`, `transfers`,
`stop_areas`, `location_group_stops` and `fare_leg_join_rules`;
references to removed stops are left as they are (they and their
translations can be removed with
[`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md)).
Transfers between stops merged together become transfers within the
merged stop, and when several transfers end up with the same stops,
routes and trips, only the first is kept, even if their `transfer_type`
or `min_transfer_time` differ; the other fields of transfers are not
changed. Duplicated rows of `stop_areas` and `location_group_stops` are
removed. Translations of merged stops are not updated.

An error is raised if `max_dist` would merge all stops into a single
one. Large values of `max_dist` in dense feeds raise a warning when
comparing the pairs of stops may use a lot of memory, or an error when
there are too many pairs. Feeds that cross the antimeridian are not
supported.

## See also

[`get_stop_distances()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_distances.md),
[`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
nrow(gtfs$stops)
#> [1] 654

combined_gtfs <- combine_nearby_stops(gtfs, max_dist = 100)
nrow(combined_gtfs$stops)
#> [1] 487
```
