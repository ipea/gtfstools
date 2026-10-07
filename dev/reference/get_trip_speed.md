# Get trip speed

Returns the average speed of each specified `trip_id`, either from the
first to the last stop of the trip or between each pair of consecutive
stops.

## Usage

``` r
get_trip_speed(
  gtfs,
  trip_id = NULL,
  method = "shapes",
  by = "trip",
  unit = "km/h",
  sort_sequence = TRUE,
  file = NULL
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to have their speeds
  calculated. If `NULL` (the default), the function calculates the speed
  of every `trip_id` in the GTFS.

- method:

  A string, either `"shapes"` (the default) or `"euclidean"`. `"shapes"`
  measures lengths along the trip's shape, described in the `shapes`
  table, while `"euclidean"` measures the straight-line (great-circle)
  distances between consecutive stops. If the GTFS object doesn't have a
  `shapes` table, or if its `trips` table doesn't have a `shape_id`
  column, `"euclidean"` is used instead, with a warning.

- by:

  A string, either `"trip"` (the default) or `"segment"`. `"trip"`
  returns the average speed from the first to the last stop of each
  trip, while `"segment"` returns the average speed between each pair of
  consecutive stops.

- unit:

  A string representing the unit in which the speeds are desired. Either
  `"km/h"` (the default) or `"m/s"`.

- sort_sequence:

  A logical specifying whether to sort timetables and shapes by
  `stop_sequence` and `shape_pt_sequence`, respectively. Defaults to
  `TRUE`. Set to `FALSE` only if these tables are known to be ordered.

- file:

  Deprecated. Use `method` instead (`file = "stop_times"` corresponds to
  `method = "euclidean"`).

## Value

With `by = "trip"`, a `data.table` with the `trip_id` and the average
`speed` of each trip. With `by = "segment"`, a `data.table` with the
`trip_id`, the `segment` number, the `from_stop_id` and `to_stop_id`
that delimit the segment and its average `speed`.

## Details

The speed is the length calculated by
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
divided by the duration calculated by
[`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md)
(with `by = "trip"`) or by
[`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)
(with `by = "segment"`). Speeds are `NA` when the length is `NA` (e.g.
trips not linked to a shape) or when the duration is missing (e.g. blank
times at intermediate stops) or not positive.

Existing `_secs` columns in `stop_times` (e.g. created with
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md))
are used as-is, not recalculated from the time strings.

## See also

[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
[`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md),
[`get_trip_segment_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_segment_duration.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

trip_speed <- get_trip_speed(gtfs)
head(trip_speed)
#> Key: <trip_id>
#>      trip_id     speed
#>       <char>     <num>
#> 1: 2002-10-0  8.360838
#> 2: 2105-10-0 10.251044
#> 3: 2105-10-1  9.651135
#> 4: 2161-10-0 11.172445
#> 5: 2161-10-1 11.625440
#> 6: 4491-10-0 12.011979

trip_ids <- c("CPTM L07-0", "2002-10-0")
trip_speed <- get_trip_speed(gtfs, trip_ids)
trip_speed
#> Key: <trip_id>
#>       trip_id     speed
#>        <char>     <num>
#> 1:  2002-10-0  8.360838
#> 2: CPTM L07-0 26.730015

trip_speed <- get_trip_speed(gtfs, trip_ids, method = "euclidean")
trip_speed
#> Key: <trip_id>
#>       trip_id     speed
#>        <char>     <num>
#> 1:  2002-10-0  6.559614
#> 2: CPTM L07-0 24.342591

trip_speed <- get_trip_speed(gtfs, trip_ids, unit = "m/s")
trip_speed
#> Key: <trip_id>
#>       trip_id    speed
#>        <char>    <num>
#> 1:  2002-10-0 2.322455
#> 2: CPTM L07-0 7.425004

segment_speed <- get_trip_speed(gtfs, "CPTM L07-0", by = "segment")
head(segment_speed)
#>       trip_id segment from_stop_id to_stop_id    speed
#>        <char>   <int>       <char>     <char>    <num>
#> 1: CPTM L07-0       1        18940      18920 26.60738
#> 2: CPTM L07-0       2        18920      18919 18.18377
#> 3: CPTM L07-0       3        18919      18917 11.93590
#> 4: CPTM L07-0       4        18917      18916 15.07881
#> 5: CPTM L07-0       5        18916      18965 16.28882
#> 6: CPTM L07-0       6        18965      18923 21.31043
```
