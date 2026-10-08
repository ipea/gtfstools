# Get dwell time

Returns the dwell time of each specified `trip_id` at each specified
`stop_id`, i.e. the time the vehicle stays at the stop, as specified in
the `stop_times` table.

## Usage

``` r
get_dwell_time(
  gtfs,
  trip_id = NULL,
  stop_id = NULL,
  unit = "s",
  from = NULL,
  to = NULL
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to have their dwell times
  calculated. If `NULL` (the default), the function calculates the dwell
  times of every `trip_id` in the GTFS.

- stop_id:

  A character vector including the `stop_id`s to have their dwell times
  calculated. If `NULL` (the default), the function calculates the dwell
  times at every `stop_id` in the GTFS.

- unit:

  A string representing the time unit in which the dwell times are
  desired. One of `"s"` (seconds, the default), `"min"` (minutes), `"h"`
  (hours) or `"d"` (days).

- from:

  A string, in the "HH:MM:SS" format. Only visits whose arrival time is
  at or after `from` are included. If `NULL` (the default), there is no
  lower limit.

- to:

  A string, in the "HH:MM:SS" format. Only visits whose arrival time is
  at or before `to` are included. If `NULL` (the default), there is no
  upper limit.

## Value

A `data.table` with the columns `trip_id`, `stop_id`, `stop_sequence`
and `dwell_time`, with one row per visit of a specified trip to a
specified stop (within the time of day, if `from` or `to` is given),
ordered by `trip_id` and `stop_sequence`. `dwell_time` is numeric, in
the given `unit`, and `NA` where a time is blank.

## Details

The dwell time of a trip at a stop is the time difference between the
`departure_time` and the `arrival_time` of that visit in `stop_times`.
When both `trip_id` and `stop_id` are given, the function returns the
visits of every specified trip to every specified stop (not of pairs
formed by their elements).

The dwell time is `NA` when either time is blank, as is common at stops
that are not timepoints. Use
[`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md)
to fill these times beforehand. The first and last stops of each trip
are included, usually with a dwell time of 0. Negative dwell times mean
that the departure is earlier than the arrival, which usually indicates
inconsistent times.

A stop visited more than once by the same trip (e.g. in a loop) has one
row per visit, told apart by `stop_sequence`. For trips listed in
`frequencies`, the times in `stop_times` are a template that applies to
each of their departures, so one dwell time is returned per visit, not
per departure.

`from` and `to` are compared with the `arrival_time` of each visit, as
written in `stop_times`, so use times past `"24:00:00"` for arrivals
after midnight. For trips listed in `frequencies`, these are template
times, not the times of each departure. Visits with a blank arrival time
are never included when `from` or `to` is given.

`stop_id`s are matched exactly against the `stop_id`s in `stop_times`,
which are never stations. To get the dwell times at a station, use
[`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md)
to list its children and pass those that appear in `stop_times`.

Times are read from the time strings: existing `_secs` columns in
`stop_times` (e.g. created with
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md))
are not used.

## See also

[`set_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_dwell_time.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

dwell_times <- get_dwell_time(gtfs)
head(dwell_times)
#>      trip_id   stop_id stop_sequence dwell_time
#>       <char>    <char>         <int>      <num>
#> 1: 2002-10-0 800016549             1          0
#> 2: 2002-10-0 800016589             2          0
#> 3: 2002-10-0 800016590             3          0
#> 4: 2002-10-0 800016591             4          0
#> 5: 2002-10-0 800012730             5          0
#> 6: 2002-10-0 670012731             6          0

# use the trip_id and stop_id arguments to control which trips and stops
# are analyzed
get_dwell_time(gtfs, trip_id = "CPTM L07-0")
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
#>  9: CPTM L07-0 4114459             9          0
#> 10: CPTM L07-0   18921            10          0
#> 11: CPTM L07-0   18924            11          0
#> 12: CPTM L07-0   18925            12          0
#> 13: CPTM L07-0   18926            13          0
#> 14: CPTM L07-0   18971            14          0
#> 15: CPTM L07-0   18972            15          0
#> 16: CPTM L07-0   18973            16          0
#> 17: CPTM L07-0   18974            17          0
#> 18: CPTM L07-0   18975            18          0
get_dwell_time(gtfs, stop_id = "18960")
#>       trip_id stop_id stop_sequence dwell_time
#>        <char>  <char>         <int>      <num>
#> 1: CPTM L08-0   18960             7          0
#> 2: CPTM L08-1   18960            16          0
#> 3: CPTM L09-0   18960             1          0
#> 4: CPTM L09-1   18960            18          0
get_dwell_time(
  gtfs,
  trip_id = c("CPTM L08-0", "CPTM L09-0"),
  stop_id = "18960"
)
#>       trip_id stop_id stop_sequence dwell_time
#>        <char>  <char>         <int>      <num>
#> 1: CPTM L08-0   18960             7          0
#> 2: CPTM L09-0   18960             1          0

# blank times result in NA dwell times. use the unit argument to control in
# which unit the dwell times are calculated
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
ggl_gtfs <- read_gtfs(ggl_path)
get_dwell_time(ggl_gtfs, trip_id = "AWE1", unit = "min")
#>    trip_id stop_id stop_sequence dwell_time
#>     <char>  <char>         <int>      <num>
#> 1:    AWE1      S1             1  0.0000000
#> 2:    AWE1      S2             2         NA
#> 3:    AWE1      S3             3  0.1666667
#> 4:    AWE1      S5             4         NA
#> 5:    AWE1      S6             5  0.0000000
```
