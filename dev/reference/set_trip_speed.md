# Set trip average speed

Sets the average speed of each specified `trip_id` by changing the
`arrival_time` and `departure_time` columns in `stop_times`.

## Usage

``` r
set_trip_speed(gtfs, trip_id, speed, unit = "km/h", by_reference = FALSE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A string vector including the `trip_id`s to have their average speed
  set.

- speed:

  A numeric representing the speed to be set. Its length must either
  equal 1, in which case the value is recycled for all `trip_id`s, or
  equal `trip_id`'s length.

- unit:

  A string representing the unit in which the speed is given. One of
  `"km/h"` (the default) or `"m/s"`.

- by_reference:

  Whether to update `stop_times`' `data.table` by reference. Defaults to
  `FALSE`.

## Value

If `by_reference` is set to `FALSE`, returns a GTFS object with the time
columns of its `stop_times` adjusted. Else, returns a GTFS object
invisibly (note that in this case the original GTFS object is altered).

## Details

The average speed is calculated as the difference between the arrival
time at the last stop minus the departure time at the first top, over
the trip's length (as calculated via
[`get_trip_geometry()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_geometry.md),
based on the `shapes` file). The arrival and departure times at all
other stops (i.e. not the first neither the last) are set as `""`, which
is written as `NA` with
[`write_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/write_gtfs.md).
Some transport routing software, such as
[OpenTripPlanner](http://www.opentripplanner.org/), support specifying
stop times like so. In such cases, they estimate arrival/departure times
at the others stops based on the average speed as well. We plan to add
that feature to this function in the future.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

gtfs_new_speed <- set_trip_speed(gtfs, trip_id = "CPTM L07-0", 50)
gtfs_new_speed$stop_times[trip_id == "CPTM L07-0"]
#>        trip_id arrival_time departure_time stop_id stop_sequence
#>         <char>       <char>         <char>  <char>         <int>
#>  1: CPTM L07-0     04:00:00       04:00:00   18940             1
#>  2: CPTM L07-0                               18920             2
#>  3: CPTM L07-0                               18919             3
#>  4: CPTM L07-0                               18917             4
#>  5: CPTM L07-0                               18916             5
#>  6: CPTM L07-0                               18965             6
#>  7: CPTM L07-0                               18923             7
#>  8: CPTM L07-0                               18922             8
#>  9: CPTM L07-0                             4114459             9
#> 10: CPTM L07-0                               18921            10
#> 11: CPTM L07-0                               18924            11
#> 12: CPTM L07-0                               18925            12
#> 13: CPTM L07-0                               18926            13
#> 14: CPTM L07-0                               18971            14
#> 15: CPTM L07-0                               18972            15
#> 16: CPTM L07-0                               18973            16
#> 17: CPTM L07-0                               18974            17
#> 18: CPTM L07-0     05:12:51       05:12:51   18975            18

# use the unit argument to change the speed unit
gtfs_new_speed <- set_trip_speed(
  gtfs,
  trip_id = "CPTM L07-0",
  speed = 15,
  unit = "m/s"
)
gtfs_new_speed$stop_times[trip_id == "CPTM L07-0"]
#>        trip_id arrival_time departure_time stop_id stop_sequence
#>         <char>       <char>         <char>  <char>         <int>
#>  1: CPTM L07-0     04:00:00       04:00:00   18940             1
#>  2: CPTM L07-0                               18920             2
#>  3: CPTM L07-0                               18919             3
#>  4: CPTM L07-0                               18917             4
#>  5: CPTM L07-0                               18916             5
#>  6: CPTM L07-0                               18965             6
#>  7: CPTM L07-0                               18923             7
#>  8: CPTM L07-0                               18922             8
#>  9: CPTM L07-0                             4114459             9
#> 10: CPTM L07-0                               18921            10
#> 11: CPTM L07-0                               18924            11
#> 12: CPTM L07-0                               18925            12
#> 13: CPTM L07-0                               18926            13
#> 14: CPTM L07-0                               18971            14
#> 15: CPTM L07-0                               18972            15
#> 16: CPTM L07-0                               18973            16
#> 17: CPTM L07-0                               18974            17
#> 18: CPTM L07-0     05:07:27       05:07:27   18975            18

# original gtfs remains unchanged
gtfs$stop_times[trip_id == "CPTM L07-0"]
#>        trip_id arrival_time departure_time stop_id stop_sequence
#>         <char>       <char>         <char>  <char>         <int>
#>  1: CPTM L07-0     04:00:00       04:00:00   18940             1
#>  2: CPTM L07-0     04:08:00       04:08:00   18920             2
#>  3: CPTM L07-0     04:16:00       04:16:00   18919             3
#>  4: CPTM L07-0     04:24:00       04:24:00   18917             4
#>  5: CPTM L07-0     04:32:00       04:32:00   18916             5
#>  6: CPTM L07-0     04:40:00       04:40:00   18965             6
#>  7: CPTM L07-0     04:48:00       04:48:00   18923             7
#>  8: CPTM L07-0     04:56:00       04:56:00   18922             8
#>  9: CPTM L07-0     05:04:00       05:04:00 4114459             9
#> 10: CPTM L07-0     05:12:00       05:12:00   18921            10
#> 11: CPTM L07-0     05:20:00       05:20:00   18924            11
#> 12: CPTM L07-0     05:28:00       05:28:00   18925            12
#> 13: CPTM L07-0     05:36:00       05:36:00   18926            13
#> 14: CPTM L07-0     05:44:00       05:44:00   18971            14
#> 15: CPTM L07-0     05:52:00       05:52:00   18972            15
#> 16: CPTM L07-0     06:00:00       06:00:00   18973            16
#> 17: CPTM L07-0     06:08:00       06:08:00   18974            17
#> 18: CPTM L07-0     06:16:00       06:16:00   18975            18

# when doing by reference, original gtfs is changed
set_trip_speed(gtfs, trip_id = "CPTM L07-0", 50, by_reference = TRUE)
gtfs$stop_times[trip_id == "CPTM L07-0"]
#>        trip_id arrival_time departure_time stop_id stop_sequence
#>         <char>       <char>         <char>  <char>         <int>
#>  1: CPTM L07-0     04:00:00       04:00:00   18940             1
#>  2: CPTM L07-0                               18920             2
#>  3: CPTM L07-0                               18919             3
#>  4: CPTM L07-0                               18917             4
#>  5: CPTM L07-0                               18916             5
#>  6: CPTM L07-0                               18965             6
#>  7: CPTM L07-0                               18923             7
#>  8: CPTM L07-0                               18922             8
#>  9: CPTM L07-0                             4114459             9
#> 10: CPTM L07-0                               18921            10
#> 11: CPTM L07-0                               18924            11
#> 12: CPTM L07-0                               18925            12
#> 13: CPTM L07-0                               18926            13
#> 14: CPTM L07-0                               18971            14
#> 15: CPTM L07-0                               18972            15
#> 16: CPTM L07-0                               18973            16
#> 17: CPTM L07-0                               18974            17
#> 18: CPTM L07-0     05:12:51       05:12:51   18975            18
```
