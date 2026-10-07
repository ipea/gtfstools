# Get trip length

Returns the length of each specified `trip_id`, measured either from the
first to the last stop of the trip or between each pair of consecutive
stops. Lengths can be measured along the trip's shape or as straight
lines between stops.

## Usage

``` r
get_trip_length(
  gtfs,
  trip_id = NULL,
  method = "shapes",
  by = "trip",
  unit = "km",
  sort_sequence = TRUE,
  file = NULL
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to have their lengths
  calculated. If `NULL` (the default), the function calculates the
  lengths of every `trip_id` in the GTFS.

- method:

  A string, either `"shapes"` (the default) or `"euclidean"`. `"shapes"`
  measures lengths along the trip's shape, described in the `shapes`
  table, while `"euclidean"` measures the straight-line (great-circle)
  distances between consecutive stops. If the GTFS object doesn't have a
  `shapes` table, or if its `trips` table doesn't have a `shape_id`
  column, `"euclidean"` is used instead, with a warning.

- by:

  A string, either `"trip"` (the default) or `"segment"`. `"trip"`
  returns the length from the first to the last stop of each trip, while
  `"segment"` returns the length between each pair of consecutive stops.

- unit:

  A string representing the unit in which lengths are desired. Either
  `"km"` (the default) or `"m"`.

- sort_sequence:

  A logical specifying whether to sort timetables and shapes by
  `stop_sequence` and `shape_pt_sequence`, respectively. Defaults to
  `TRUE`. Set to `FALSE` only if these tables are known to be ordered.

- file:

  Deprecated. Use `method` instead (`file = "stop_times"` corresponds to
  `method = "euclidean"`).

## Value

With `by = "trip"`, a `data.table` with the `trip_id` and the `length`
of each trip. With `by = "segment"`, a `data.table` with the `trip_id`,
the `segment` number, the `from_stop_id` and `to_stop_id` that delimit
the segment and its `length`.

## Details

Segments are numbered as in
[`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md),
so both outputs can be joined by `trip_id` and `segment`. Trips with a
single stop have a length of 0.

With `method = "shapes"`, each stop is projected onto the closest point
of its trip's shape, with stops advancing along the shape in
`stop_sequence` order, so loops and shapes that pass by the same place
more than once are handled. Some limitations remain:

- a stop slightly behind the previous one along the shape (e.g. due to
  imprecise coordinates) is placed at the previous stop's position, so
  their segment has a length of 0. On shapes that pass the same place
  twice in the same direction, such a stop may be matched to the later
  pass instead;

- on shapes whose outbound and return legs overlap exactly, the stops
  just before and after the turnaround may be placed at the same
  position. The trip length is unaffected, but the segment between them
  gets a length of 0 and the next one is longer.

`shape_dist_traveled` is ignored. Trips not linked to a shape with at
least two distinct points have `NA` lengths, with a warning. Use
[`get_shape_length()`](https://ipea.github.io/gtfstools/dev/reference/get_shape_length.md)
for the length of entire shapes.

Lengths are great-circle (haversine) distances on the sphere used by
`{s2}`. Stops with missing coordinates, or not listed in `stops`, result
in `NA` lengths for their segments and trips.

## See also

[`get_shape_length()`](https://ipea.github.io/gtfstools/dev/reference/get_shape_length.md),
[`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md),
[`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# length along the shape from the first to the last stop of each trip
trip_length <- get_trip_length(gtfs)
head(trip_length)
#>      trip_id   length
#>       <char>    <num>
#> 1: 2002-10-0  6.68867
#> 2: 2105-10-0 18.45188
#> 3: 2105-10-1 17.85460
#> 4: 2161-10-0 17.50350
#> 5: 2161-10-1 18.01943
#> 6: 4491-10-0 13.81378

# length along the shape between consecutive stops
segment_length <- get_trip_length(gtfs, "CPTM L07-0", by = "segment")
head(segment_length)
#>       trip_id segment from_stop_id to_stop_id   length
#>        <char>   <int>       <char>     <char>    <num>
#> 1: CPTM L07-0       1        18940      18920 3.547651
#> 2: CPTM L07-0       2        18920      18919 2.424503
#> 3: CPTM L07-0       3        18919      18917 1.591453
#> 4: CPTM L07-0       4        18917      18916 2.010508
#> 5: CPTM L07-0       5        18916      18965 2.171843
#> 6: CPTM L07-0       6        18965      18923 2.841391

# straight-line distances between consecutive stops, in meters
straight_length <- get_trip_length(
  gtfs,
  "CPTM L07-0",
  method = "euclidean",
  by = "segment",
  unit = "m"
)
head(straight_length)
#>       trip_id segment from_stop_id to_stop_id   length
#>        <char>   <int>       <char>     <char>    <num>
#> 1: CPTM L07-0       1        18940      18920 3353.211
#> 2: CPTM L07-0       2        18920      18919 2357.544
#> 3: CPTM L07-0       3        18919      18917 1555.489
#> 4: CPTM L07-0       4        18917      18916 1861.838
#> 5: CPTM L07-0       5        18916      18965 2082.265
#> 6: CPTM L07-0       6        18965      18923 2761.174
```
