# Set trip maximum speed

Caps the speed of the specified trips: each part of a trip that is
faster than `max_speed` is slowed down to `max_speed`, by changing the
`arrival_time` and `departure_time` columns in `stop_times`. Parts of
the trips that are already slower are left unchanged.

## Usage

``` r
set_max_speed(
  gtfs,
  max_speed,
  unit = "km/h",
  route_id = NULL,
  trip_id = NULL,
  first_stop = NULL,
  last_stop = NULL,
  from = NULL,
  to = NULL,
  route_type = NULL
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- max_speed:

  A number. The maximum speed allowed, in the unit given by `unit`.

- unit:

  A string representing the unit in which the speed is given. One of
  `"km/h"` (the default), `"m/s"` or `"mph"` (miles per hour).

- route_id:

  A character vector including the `route_id`s whose trips have their
  speeds capped. If `route_id`, `trip_id` and `route_type` are all
  `NULL` (the default), the speeds of every trip in the GTFS are capped.
  `route_id`s not listed in `trips` are ignored, with a warning.

- trip_id:

  A character vector including the `trip_id`s to have their speeds
  capped. When given together with `route_id`, the trips of both are
  capped.

- first_stop:

  A string. The `stop_id` where the segment whose speeds are capped
  starts. If `NULL` (the default), the segment starts at each trip's
  first stop.

- last_stop:

  A string. The `stop_id` where the segment ends. If `NULL` (the
  default), the segment ends at each trip's last stop.

- from:

  A string, in the "HH:MM:SS" format. Only trips that depart from the
  segment's first stop at or after `from` are changed. If `NULL` (the
  default), there is no lower limit.

- to:

  A string, in the "HH:MM:SS" format. Only trips that depart from the
  segment's first stop at or before `to` are changed. If `NULL` (the
  default), there is no upper limit.

- route_type:

  An integer vector of `route_type`s (see
  [`filter_by_route_type()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_type.md)).
  If given, only trips of routes of these types are changed; together
  with the other selection arguments, it restricts their selection.
  `route_type`s not listed in `routes` are ignored. If `NULL` (the
  default), trips of any type are changed.

## Value

A GTFS object with the time columns of its `stop_times` adjusted.

## Details

A span is the part of a trip between two consecutive stops with times;
stops with blank times inside it are kept blank. Its speed is its
length, calculated by
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
along the trip's shape (or, with a warning, as straight lines between
stops if there are no shapes; the `stops` table is required), divided by
the time from the departure at its first stop to the arrival at its
second. Spans whose length is `NA` (e.g. in trips not linked to a shape)
are left unchanged.

Each span faster than `max_speed`, or with a zero duration, has its
duration raised to its length divided by `max_speed`, rounded up to the
next second. All the later times of the trip are shifted by the
accumulated extra time, so dwell times are kept. Spans whose arrival is
earlier than the previous departure (usually times after midnight
written as `"00:30:00"` instead of `"24:30:00"`) are left unchanged,
with a warning. An error is raised if a shift would result in a time
later than `"9999:59:59"`. Only `stop_times` is modified; its existing
`_secs` columns are updated to match.

With `first_stop` and `last_stop`, matched as in
[`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md),
only the spans between them are capped: times before `first_stop` don't
change, and the times at and after `last_stop` are shifted. The given
stops must have a time, so that no span crosses them (if only
`last_stop` is given, the trip's first stop needs none). Trips that
don't visit `first_stop` and then `last_stop`, or have blank times
there, are left unchanged, with a warning if they were given in
`trip_id` or `route_id`.

`from` and `to` are compared with the departure at the segment's first
stop (or its arrival, if the departure is blank) as written in
`stop_times` (template times, for trips listed in `frequencies`), so use
times past `"24:00:00"` for departures after midnight. Trips without a
time there are left unchanged.

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

# cap the speed only between two stops. the spans before and after them
# are not capped
gtfs_capped <- set_max_speed(
  gtfs,
  max_speed = 30,
  trip_id = "CPTM L07-0",
  first_stop = "18921",
  last_stop = "18974"
)
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
#>  9: CPTM L07 CPTM L07-0       9      4114459      18921 31.53864
#> 10: CPTM L07 CPTM L07-0      10        18921      18924 29.98277
#> 11: CPTM L07 CPTM L07-0      11        18924      18925 29.98309
#> 12: CPTM L07 CPTM L07-0      12        18925      18926 20.48514
#> 13: CPTM L07 CPTM L07-0      13        18926      18971 26.54381
#> 14: CPTM L07 CPTM L07-0      14        18971      18972 29.98556
#> 15: CPTM L07 CPTM L07-0      15        18972      18973 28.27469
#> 16: CPTM L07 CPTM L07-0      16        18973      18974 29.98277
#> 17: CPTM L07 CPTM L07-0      17        18974      18975 38.29072

# cap the speed of all the trips of all routes of the GTFS feed
gtfs_capped <- set_max_speed(gtfs, max_speed = 8)
```
