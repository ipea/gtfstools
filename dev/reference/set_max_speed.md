# Set trip maximum speed

Caps the speed of the specified trips: each part of a trip that is
faster than `max_speed` is slowed down to `max_speed`, by changing the
`arrival_time` and `departure_time` columns in `stop_times`. Parts of
the trips that are already slower are left unchanged.

## Usage

``` r
set_max_speed(gtfs, max_speed, route_id = NULL, trip_id = NULL, unit = "km/h")
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- max_speed:

  A number. The maximum speed allowed, in the unit given by `unit`.

- route_id:

  A character vector including the `route_id`s whose trips have their
  speeds capped. If both `route_id` and `trip_id` are `NULL` (the
  default), the speeds of every trip in the GTFS are capped.

- trip_id:

  A character vector including the `trip_id`s to have their speeds
  capped. When given together with `route_id`, the trips of both are
  capped.

- unit:

  A string representing the unit in which the speed is given. One of
  `"km/h"` (the default), `"m/s"` or `"mph"` (miles per hour).

## Value

A GTFS object with the time columns of its `stop_times` adjusted.

## Details

The speed of each span between two consecutive stops with times is its
length, as calculated by
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
along the trip's shape (or as straight lines between stops, with a
warning, if there are no shapes), divided by the time between the
departure from the first stop and the arrival at the second. Stops with
blank times inside a span are kept blank. The `stops` table is required.
Spans whose length is `NA` (e.g. in trips not linked to a shape) are
left unchanged.

Each span faster than `max_speed` has its duration increased to its
length divided by `max_speed`, rounded up to the next second, so new
times may include seconds even if the original times were given in whole
minutes. Spans with zero duration are treated the same way. All the
later times of the trip are shifted by the accumulated extra time, so
dwell times are kept. Spans whose arrival is earlier than the previous
departure are left unchanged, with a warning. This usually happens when
times after midnight are written as `"00:30:00"` instead of
`"24:30:00"`. Only `stop_times` is modified.

## See also

[`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md),
[`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

# the trip is faster than 30 km/h between some of its stops
get_trip_speed(gtfs, "CPTM L07-0", by = "segment")
#>     route_id    trip_id segment from_stop_id to_stop_id    speed
#>       <char>     <char>   <int>       <char>     <char>    <num>
#>  1: CPTM L07 CPTM L07-0       1        18940      18920 26.60738
#>  2: CPTM L07 CPTM L07-0       2        18920      18919 18.18377
#>  3: CPTM L07 CPTM L07-0       3        18919      18917 11.93590
#>  4: CPTM L07 CPTM L07-0       4        18917      18916 15.07881
#>  5: CPTM L07 CPTM L07-0       5        18916      18965 16.28882
#>  6: CPTM L07 CPTM L07-0       6        18965      18923 21.31043
#>  7: CPTM L07 CPTM L07-0       7        18923      18922 15.08821
#>  8: CPTM L07 CPTM L07-0       8        18922    4114459 17.68714
#>  9: CPTM L07 CPTM L07-0       9      4114459      18921 31.53864
#> 10: CPTM L07 CPTM L07-0      10        18921      18924 32.98105
#> 11: CPTM L07 CPTM L07-0      11        18924      18925 36.47943
#> 12: CPTM L07 CPTM L07-0      12        18925      18926 20.48514
#> 13: CPTM L07 CPTM L07-0      13        18926      18971 26.54381
#> 14: CPTM L07 CPTM L07-0      14        18971      18972 52.84955
#> 15: CPTM L07 CPTM L07-0      15        18972      18973 28.27469
#> 16: CPTM L07 CPTM L07-0      16        18973      18974 44.78676
#> 17: CPTM L07 CPTM L07-0      17        18974      18975 38.29072

gtfs_capped <- set_max_speed(gtfs, max_speed = 30, trip_id = "CPTM L07-0")
get_trip_speed(gtfs_capped, "CPTM L07-0", by = "segment")
#>     route_id    trip_id segment from_stop_id to_stop_id    speed
#>       <char>     <char>   <int>       <char>     <char>    <num>
#>  1: CPTM L07 CPTM L07-0       1        18940      18920 26.60738
#>  2: CPTM L07 CPTM L07-0       2        18920      18919 18.18377
#>  3: CPTM L07 CPTM L07-0       3        18919      18917 11.93590
#>  4: CPTM L07 CPTM L07-0       4        18917      18916 15.07881
#>  5: CPTM L07 CPTM L07-0       5        18916      18965 16.28882
#>  6: CPTM L07 CPTM L07-0       6        18965      18923 21.31043
#>  7: CPTM L07 CPTM L07-0       7        18923      18922 15.08821
#>  8: CPTM L07 CPTM L07-0       8        18922    4114459 17.68714
#>  9: CPTM L07 CPTM L07-0       9      4114459      18921 29.97732
#> 10: CPTM L07 CPTM L07-0      10        18921      18924 29.98277
#> 11: CPTM L07 CPTM L07-0      11        18924      18925 29.98309
#> 12: CPTM L07 CPTM L07-0      12        18925      18926 20.48514
#> 13: CPTM L07 CPTM L07-0      13        18926      18971 26.54381
#> 14: CPTM L07 CPTM L07-0      14        18971      18972 29.98556
#> 15: CPTM L07 CPTM L07-0      15        18972      18973 28.27469
#> 16: CPTM L07 CPTM L07-0      16        18973      18974 29.98277
#> 17: CPTM L07 CPTM L07-0      17        18974      18975 29.98295

# the later stops are shifted, so the trip ends later
 get_start_and_end_times(gtfs, trip_id = "CPTM L07-0")
#> start_time   end_time 
#> "04:00:00" "06:16:00" 
 get_start_and_end_times(gtfs_capped, trip_id = "CPTM L07-0")
#> start_time   end_time 
#> "04:00:00" "06:31:13" 

# cap the speed of all the trips of all routes of the GTFS feed
gtfs_capped <- set_max_speed(gtfs, max_speed = 8)
```
