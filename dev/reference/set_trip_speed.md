# Set trip average speed

Sets the average speed of each specified `trip_id`, or of a segment of
it, by changing the `arrival_time` and `departure_time` columns in
`stop_times`.

## Usage

``` r
set_trip_speed(
  gtfs,
  trip_id,
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

The duration of each trip's segment (from the departure at `first_stop`
to the arrival at `last_stop`; by default the whole trip) is set to its
length, as calculated by
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
along the trip's shape (or as straight lines between stops, with a
warning, if there are no shapes), divided by `speed`. The `stops` table
is required. Trips whose length is `NA` (e.g. trips not linked to a
shape) are left unchanged.

The arrival and departure times at stops strictly inside the segment are
set to `""`, which is written as `NA` by
[`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md).
Some routing software, such as
[OpenTripPlanner](http://www.opentripplanner.org/), interpolates these
times from the average speed.

`first_stop` is matched at its first visit in `stop_sequence` order, and
`last_stop` at its next visit after that (which may be the same stop).
Times after `last_stop` are shifted by the change in the segment's
duration. Dwell times at `first_stop` and `last_stop` are kept, except
at the trip's first and last stops. Trips that don't visit `first_stop`
and then `last_stop`, or that have blank times there, are left unchanged
with a warning. `from` and `to` are compared with the `departure_time`
at `first_stop` as written in `stop_times`, so use times past
`"24:00:00"` for departures after midnight. For trips listed in
`frequencies`, these are template times, not actual departures. Trips
whose departure there is blank are left unchanged.

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
#> 18: CPTM L07-0     05:12:42       05:12:42   18975            18

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
#> 18: CPTM L07-0     05:07:19       05:07:19   18975            18

# set the speed only between two stops. later stops are shifted
gtfs_new_speed <- set_trip_speed(
  gtfs,
  trip_id = "CPTM L07-0",
  speed = 30,
  first_stop = "18917",
  last_stop = "18922"
)
gtfs_new_speed$stop_times[trip_id == "CPTM L07-0"]
#>        trip_id arrival_time departure_time stop_id stop_sequence
#>         <char>       <char>         <char>  <char>         <int>
#>  1: CPTM L07-0     04:00:00       04:00:00   18940             1
#>  2: CPTM L07-0     04:08:00       04:08:00   18920             2
#>  3: CPTM L07-0     04:16:00       04:16:00   18919             3
#>  4: CPTM L07-0     04:24:00       04:24:00   18917             4
#>  5: CPTM L07-0                               18916             5
#>  6: CPTM L07-0                               18965             6
#>  7: CPTM L07-0                               18923             7
#>  8: CPTM L07-0     04:42:04       04:42:04   18922             8
#>  9: CPTM L07-0     04:50:04       04:50:04 4114459             9
#> 10: CPTM L07-0     04:58:04       04:58:04   18921            10
#> 11: CPTM L07-0     05:06:04       05:06:04   18924            11
#> 12: CPTM L07-0     05:14:04       05:14:04   18925            12
#> 13: CPTM L07-0     05:22:04       05:22:04   18926            13
#> 14: CPTM L07-0     05:30:04       05:30:04   18971            14
#> 15: CPTM L07-0     05:38:04       05:38:04   18972            15
#> 16: CPTM L07-0     05:46:04       05:46:04   18973            16
#> 17: CPTM L07-0     05:54:04       05:54:04   18974            17
#> 18: CPTM L07-0     06:02:04       06:02:04   18975            18

# set the speed only of the trips that depart within a time of day
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
poa_gtfs <- read_gtfs(poa_path)

poa_new_speed <- set_trip_speed(
  poa_gtfs,
  trip_id = poa_gtfs$trips$trip_id,
  speed = 25,
  from = "07:00:00",
  to = "09:00:00"
)
# the arrival at the last stop of a trip that departs at 07:02 changes
poa_gtfs$stop_times[trip_id == "T2-1@1#702"][.N]
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: T2-1@1#702     08:03:00       08:03:00    1456            62
poa_new_speed$stop_times[trip_id == "T2-1@1#702"][.N]
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: T2-1@1#702     07:41:39       07:41:39    1456            62

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
#> 18: CPTM L07-0     05:12:42       05:12:42   18975            18
```
