# Fix common problems in GTFS feeds

Cleans a GTFS feed in one call, by removing duplicated entries and
unused ids, optionally capping the speed of trips, filling blank stop
times, optionally setting a minimum dwell time at intermediate stops and
recalculating the distances travelled along shapes (replacing any
existing ones).

## Usage

``` r
fix_gtfs(
  gtfs,
  max_speed = NULL,
  speed_unit = "km/h",
  min_dwell_time = NULL,
  dwell_time_unit = "s"
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- max_speed:

  A number. The maximum speed of trips, in the unit given by
  `speed_unit`. If `NULL` (the default), speeds are not capped.

- speed_unit:

  A string representing the unit in which `max_speed` is given. One of
  `"km/h"` (the default), `"m/s"` or `"mph"` (miles per hour).

- min_dwell_time:

  A non-negative number. The minimum time vehicles remain stopped at
  each intermediate stop of their trips, with their doors open to serve
  passengers, in the unit given by `dwell_time_unit`. If `NULL` (the
  default), dwell times are not changed.

- dwell_time_unit:

  A string representing the time unit in which `min_dwell_time` is
  given. One of `"s"` (seconds, the default), `"min"` (minutes), `"h"`
  (hours) or `"d"` (days).

## Value

The fixed GTFS object.

## Details

The feed goes through the following steps, in this order:

1.  [`remove_duplicates()`](https://ipea.github.io/gtfstools/dev/reference/remove_duplicates.md)
    removes duplicated entries from every table;

2.  [`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md)
    removes the trips without `stop_times`, and the entries of every
    table that no remaining trip uses (see its documentation for the
    exceptions). Note that this removes data from the feed;

3.  [`set_max_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_max_speed.md),
    only if `max_speed` is given, slows down the parts of trips that are
    faster than `max_speed`. Only spans between stops with known times
    are capped, and spans that end before they start (e.g. times after
    midnight written as `"00:30:00"`) are left unchanged, with a
    warning;

4.  [`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md)
    fills blank stop times from the times of the stops around them.
    Speeds are capped before interpolating, so the filled times follow
    the capped times. Interpolated times are rounded to the second.
    Stops whose times can't be interpolated are left blank, with a
    warning;

5.  [`set_min_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_min_dwell_time.md),
    only if `min_dwell_time` is given, delays the departure from each
    intermediate stop whose dwell time is shorter than `min_dwell_time`,
    so that vehicles stay there for at least that long. The minimum is
    rounded to the second. The later times of each changed trip are
    shifted accordingly, so the trip ends later (for trips listed in
    `frequencies`, every departure gets longer). This is done after
    filling blank times, so the filled stops also get the minimum. Only
    the stops between the first and the last stop with times of each
    trip get the minimum, so trips keep their start times. Stops with
    negative dwell times (departures earlier than arrivals, e.g. times
    after midnight written as `"00:30:00"`) don't get it either;

6.  [`interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_shape_dist_traveled.md),
    only if the feed has a `shapes` table and `trips` has a `shape_id`
    column, replaces the `shape_dist_traveled` columns of `stop_times`
    and `shapes` with the distances, in meters, from the start of each
    shape. Existing values, whatever their unit, are replaced, and stops
    that can't be located along their trip's shape get `NA`.

The `trips` and `stop_times` tables are always required, and `stops` is
required to cap speeds, to fill blank times and to calculate the
distances travelled along shapes. The warnings raised are those of the
functions above, so some warnings (e.g. about trips not linked to a
shape) may be raised more than once.

## See also

[`remove_duplicates()`](https://ipea.github.io/gtfstools/dev/reference/remove_duplicates.md),
[`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md),
[`set_max_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_max_speed.md),
[`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md),
[`set_min_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_min_dwell_time.md),
[`interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_shape_dist_traveled.md)

## Examples

``` r
library(dplyr)

data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

fixed_gtfs <- fix_gtfs(gtfs, max_speed = 40, min_dwell_time = 30)

# duplicated agencies were removed, and the trip is now slower and stays at
# least 30 seconds at each intermediate stop
gtfs$agency
#>    agency_id agency_name                               agency_url
#>       <char>      <char>                                   <char>
#> 1:         1     SPTRANS http://www.sptrans.com.br/?versao=011019
#> 2:         1     SPTRANS http://www.sptrans.com.br/?versao=011019
#>      agency_timezone agency_lang
#>               <char>      <char>
#> 1: America/Sao_Paulo          pt
#> 2: America/Sao_Paulo          pt
fixed_gtfs$agency
#>    agency_id agency_name                               agency_url
#>       <char>      <char>                                   <char>
#> 1:         1     SPTRANS http://www.sptrans.com.br/?versao=011019
#>      agency_timezone agency_lang
#>               <char>      <char>
#> 1: America/Sao_Paulo          pt

gtfs$stop_times |>
  filter(trip_id == "CPTM L07-0") |>
  slice_tail(n = 1)
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     06:16:00       06:16:00   18975            18

fixed_gtfs$stop_times |>
  filter(trip_id == "CPTM L07-0") |>
  slice_tail(n = 1)
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     06:27:33       06:27:33   18975            18
#>    shape_dist_traveled
#>                  <num>
#> 1:            60598.61
```
