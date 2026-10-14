# Set route average speed

Sets the average speed of the trips of each specified `route_id`, or of
a segment of them, by changing the `arrival_time` and `departure_time`
columns in `stop_times`.

## Usage

``` r
set_route_speed(
  gtfs,
  route_id,
  speed,
  unit = "km/h",
  first_stop = NULL,
  last_stop = NULL,
  from = NULL,
  to = NULL,
  by_reference = FALSE
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- route_id:

  A character vector including the `route_id`s to have the average speed
  of their trips set.

- speed:

  A numeric representing the speed to be set. Its length must either
  equal 1, in which case the value is recycled for all `route_id`s, or
  equal `route_id`'s length. Must be positive and finite.

- unit:

  A string representing the unit in which the speed is given. One of
  `"km/h"` (the default), `"m/s"` or `"mph"` (miles per hour).

- first_stop:

  A string. The `stop_id` where the segment whose speed is set starts.
  If `NULL` (the default), the segment starts at each trip's first stop.

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

- by_reference:

  Whether to update `stop_times`' `data.table` by reference. Defaults to
  `FALSE`.

## Value

If `by_reference` is set to `FALSE`, returns a GTFS object with the time
columns of its `stop_times` adjusted. Else, returns a GTFS object
invisibly (note that in this case the original GTFS object is altered).

## Details

Every trip of each route, as listed in `trips`, gets the route's speed,
as in
[`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md),
whose details also apply here: the duration of each trip's segment (by
default, the whole trip) is set to its length divided by `speed`, the
times at stops inside the segment are set to `""`, and `from` and `to`
restrict the changes to the trips that depart from the segment's first
stop within the time of day. Warnings about trips that can't be changed
refer to their `trip_id`s. Trips without `stop_times` entries are
ignored.

## See also

[`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md),
[`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)

## Examples

``` r
library(dplyr)

data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

route_trips <- gtfs$trips |>
  filter(route_id == "CPTM L07") |>
  pull(trip_id)
get_trip_speed(gtfs, route_trips)
#> Key: <trip_id>
#>    route_id    trip_id    speed
#>      <char>     <char>    <num>
#> 1: CPTM L07 CPTM L07-0 26.73002
#> 2: CPTM L07 CPTM L07-1 26.73002

new_speed_gtfs <- set_route_speed(gtfs, route_id = "CPTM L07", speed = 50)
get_trip_speed(new_speed_gtfs, route_trips)
#> Key: <trip_id>
#>    route_id    trip_id    speed
#>      <char>     <char>    <num>
#> 1: CPTM L07 CPTM L07-0 50.00388
#> 2: CPTM L07 CPTM L07-1 50.00388

# set the speed only of the trips that depart within a time of day
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
poa_gtfs <- read_gtfs(poa_path)

poa_new_speed <- set_route_speed(
  poa_gtfs,
  route_id = "T2",
  speed = 25,
  from = "07:00:00",
  to = "09:00:00"
)

# the arrival at the last stop of a trip that departs at 07:02 changes
poa_gtfs$stop_times |>
  filter(trip_id == "T2-1@1#702") |>
  slice_tail(n = 1)
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: T2-1@1#702     08:03:00       08:03:00    1456            62

poa_new_speed$stop_times |>
  filter(trip_id == "T2-1@1#702") |>
  slice_tail(n = 1)
#> Index: <trip_id>
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: T2-1@1#702     07:41:39       07:41:39    1456            62
```
