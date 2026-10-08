# Set dwell time

Sets the dwell time of each specified `trip_id` at each specified
`stop_id`, i.e. the time the vehicle stays at the stop, by changing the
`departure_time` at these stops in `stop_times` and shifting the later
times of the trips accordingly.

## Usage

``` r
set_dwell_time(
  gtfs,
  trip_id = NULL,
  stop_id = NULL,
  dwell_time,
  unit = "s",
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

  A character vector including the `trip_id`s to have their dwell times
  set. If `NULL` (the default), the dwell times of every `trip_id` in
  the GTFS are set.

- stop_id:

  A character vector including the `stop_id`s at which the dwell times
  are set. If `NULL` (the default), the dwell times are set at every
  `stop_id` in the GTFS.

- dwell_time:

  A non-negative number, the dwell time to be set, in `unit`. It's
  rounded to the nearest whole second and applies to every specified
  visit (call the function once per value to set different dwell times).

- unit:

  A string representing the time unit in which `dwell_time` is given.
  One of `"s"` (seconds, the default), `"min"` (minutes), `"h"` (hours)
  or `"d"` (days).

- from:

  A string, in the "HH:MM:SS" format. Only visits whose arrival time is
  at or after `from` are changed. If `NULL` (the default), there is no
  lower limit.

- to:

  A string, in the "HH:MM:SS" format. Only visits whose arrival time is
  at or before `to` are changed. If `NULL` (the default), there is no
  upper limit.

- by_reference:

  Whether to update `stop_times`' `data.table` by reference. Defaults to
  `FALSE`.

## Value

If `by_reference` is set to `FALSE`, returns a GTFS object with the time
columns of its `stop_times` adjusted. Else, returns a GTFS object
invisibly (note that in this case the original GTFS object is altered).

## Details

The dwell time of a trip at a stop is the time difference between the
`departure_time` and the `arrival_time` of that visit in `stop_times`,
as returned by
[`get_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/get_dwell_time.md).
The function sets it at the visits of every specified trip to every
specified stop (not of pairs formed by their elements), within the time
of day if `from` or `to` is given. At each of these visits, the arrival
time is kept and the departure time is set to the arrival time plus
`dwell_time`. All the later times of the trip, in `stop_sequence` order,
are shifted by the change in the dwell time, so the travel times between
stops are kept and the trip ends earlier or later. Changes at several
visits of the same trip add up.

Setting the dwell time at a trip's first stop shifts the rest of the
trip. At its last stop, only the departure time changes. A stop visited
more than once by the same trip (e.g. in a loop) has its dwell time set
at each visit.

Blank times are never filled, and later blank times stay blank. Selected
visits with a blank arrival or departure time have no dwell time to
change, so their dwell time is not set and they don't shift the later
times. When `stop_id` is given, this raises a warning. Use
[`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md)
to fill blank times beforehand. The function raises an error if a shift
would result in a negative time, which only happens when the times of a
trip are not in chronological order, or in a time later than
`"9999:59:59"`, the latest time that can be written. The visits of each
trip are ordered by `stop_sequence`, which is assumed to be unique
within each trip and not `NA`, as required by the GTFS specification.
When both `trip_id` and `stop_id` are given, but none of the trips
visits any of the stops, the function raises a warning and returns the
GTFS unchanged.

For trips listed in `frequencies`, the times in `stop_times` are a
template: the trips depart at the times listed in `frequencies`,
starting from their first departure (see
[`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)).
Setting the dwell time at the first stop of such a trip therefore
changes only how long before each departure the vehicle arrives there,
while changes at later stops lengthen or shorten every departure of the
trip.

`from` and `to` are compared with the `arrival_time` of each visit, as
written in `stop_times` before any change, so use times past
`"24:00:00"` for arrivals after midnight. A shift caused by an earlier
visit may thus move a changed visit out of the time of day, or another
visit into it. For trips listed in `frequencies`, these are template
times, not the times of each departure. Visits with a blank arrival time
are never selected when `from` or `to` is given, so they don't raise the
warning above. When the time of day contains no visit of the specified
trips to the specified stops, the GTFS is returned unchanged.

`stop_id`s are matched exactly against the `stop_id`s in `stop_times`,
which are never stations. To set the dwell times at a station, use
[`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md)
to list its children and pass those that appear in `stop_times`.

Changed times are written in the "HH:MM:SS" format. Existing `_secs`
columns in `stop_times` (e.g. created with
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md))
are updated to match.

## See also

[`get_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/get_dwell_time.md),
[`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# set a 30 seconds dwell time at a stop of a trip. the later times of the
# trip are shifted by 30 seconds
new_gtfs <- set_dwell_time(
  gtfs,
  trip_id = "CPTM L07-0",
  stop_id = "18920",
  dwell_time = 30
)
head(new_gtfs$stop_times[trip_id == "CPTM L07-0"])
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     04:00:00       04:00:00   18940             1
#> 2: CPTM L07-0     04:08:00       04:08:30   18920             2
#> 3: CPTM L07-0     04:16:30       04:16:30   18919             3
#> 4: CPTM L07-0     04:24:30       04:24:30   18917             4
#> 5: CPTM L07-0     04:32:30       04:32:30   18916             5
#> 6: CPTM L07-0     04:40:30       04:40:30   18965             6

# set the dwell time at a stop in every trip that visits it. use the unit
# argument to give the dwell time in another unit
new_gtfs <- set_dwell_time(
  gtfs,
  stop_id = "18960",
  dwell_time = 1,
  unit = "min"
)
get_dwell_time(new_gtfs, stop_id = "18960")
#>       trip_id stop_id stop_sequence dwell_time
#>        <char>  <char>         <int>      <num>
#> 1: CPTM L08-0   18960             7         60
#> 2: CPTM L08-1   18960            16         60
#> 3: CPTM L09-0   18960             1         60
#> 4: CPTM L09-1   18960            18         60

# set the dwell time only at the visits that arrive within a time of day
new_gtfs <- set_dwell_time(
  gtfs,
  trip_id = "CPTM L07-0",
  dwell_time = 30,
  from = "05:00:00",
  to = "06:00:00"
)
get_dwell_time(new_gtfs, trip_id = "CPTM L07-0")
#>        trip_id stop_id stop_sequence dwell_time
#>         <char>  <char>         <int>      <num>
#>  1: CPTM L07-0   18940             1          0
#>  2: CPTM L07-0   18920             2          0
#>  3: CPTM L07-0   18919             3          0
#>  4: CPTM L07-0   18917             4          0
#>  5: CPTM L07-0   18916             5          0
#>  6: CPTM L07-0   18965             6          0
#>  7: CPTM L07-0   18923             7          0
#>  8: CPTM L07-0   18922             8          0
#>  9: CPTM L07-0 4114459             9         30
#> 10: CPTM L07-0   18921            10         30
#> 11: CPTM L07-0   18924            11         30
#> 12: CPTM L07-0   18925            12         30
#> 13: CPTM L07-0   18926            13         30
#> 14: CPTM L07-0   18971            14         30
#> 15: CPTM L07-0   18972            15         30
#> 16: CPTM L07-0   18973            16         30
#> 17: CPTM L07-0   18974            17          0
#> 18: CPTM L07-0   18975            18          0

# original gtfs remains unchanged
get_dwell_time(gtfs, stop_id = "18960")
#>       trip_id stop_id stop_sequence dwell_time
#>        <char>  <char>         <int>      <num>
#> 1: CPTM L08-0   18960             7          0
#> 2: CPTM L08-1   18960            16          0
#> 3: CPTM L09-0   18960             1          0
#> 4: CPTM L09-1   18960            18          0

# when doing by reference, original gtfs is changed
set_dwell_time(
  gtfs,
  trip_id = "CPTM L07-0",
  stop_id = "18920",
  dwell_time = 30,
  by_reference = TRUE
)
head(gtfs$stop_times[trip_id == "CPTM L07-0"])
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     04:00:00       04:00:00   18940             1
#> 2: CPTM L07-0     04:08:00       04:08:30   18920             2
#> 3: CPTM L07-0     04:16:30       04:16:30   18919             3
#> 4: CPTM L07-0     04:24:30       04:24:30   18917             4
#> 5: CPTM L07-0     04:32:30       04:32:30   18916             5
#> 6: CPTM L07-0     04:40:30       04:40:30   18965             6
```
