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

Stops with a `parent_station` are always merged into one stop with the
`stop_id` of the parent station, regardless of the distance between
them. This stop is named after the parent station if it's listed in
`stops`, or else after its platforms. Then stops are merged by distance,
so that every pair of stops merged together is at most `max_dist` apart.
The closest pairs are merged first. Stops that were already merged by
their parent station are compared by the mean of their coordinates, so
their own platforms may be farther apart. Distances are great-circle
distances, as in
[`get_stop_distances()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_distances.md).
Stops without coordinates are only merged by their parent station.

A stop merged from several stops has a `stop_id` and a `stop_name` made
of the ids and names of the merged stops, separated by `"-"` (repeated
names are listed only once), and the mean of their coordinates. Its
other fields, such as `zone_id` and `level_id`, are those of the merged
stop whose `stop_id` comes first. If a `stop_id` is listed more than
once in `stops`, only its first entry is used.

The result has only plain stops (`location_type` 0) without
`parent_station`: stations are replaced by the stop merged from their
platforms, and stations without platforms, entrances, generic nodes,
boarding areas and `pathways` are removed. The `stop_id`s of merged
stops and stations are updated in `stop_times`, `transfers`,
`stop_areas`, `location_group_stops` and `fare_leg_join_rules`, but
references to removed stops are left as they are. Transfers between
stops that were merged together become transfers within the merged stop,
and when several transfers end up with the same stops, routes and trips,
only the first one is kept, even if their `transfer_type` or
`min_transfer_time` differ. The other fields of transfers are not
changed, so a `min_transfer_time` between platforms that were merged now
applies within the merged stop, and may no longer be accurate. Since
`transfers` is optional, it can be removed (`gtfs$transfers <- NULL`)
when these rules are not needed. Duplicated rows of `stop_areas` and
`location_group_stops` are removed. Translations of merged stops are not
updated. References to removed stops and their translations can be
removed with
[`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md).

An error is raised if `max_dist` is so large that all stops would be
merged into a single one. Large values of `max_dist` in dense feeds
compare many pairs of stops, which is slow and raises a warning when it
may use a lot of memory, or an error when there are too many pairs to
compare.

Merged `stop_id`s can be long at large terminals, and are ambiguous when
the original `stop_id`s include `"-"`. Feeds that cross the antimeridian
are not supported.

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
