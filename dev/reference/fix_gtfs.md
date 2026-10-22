# Fix common problems in GTFS feeds

Cleans a GTFS feed in one call, by removing duplicated entries and
unused ids, optionally capping the speed of trips, filling blank stop
times and filling the distances travelled along shapes.

## Usage

``` r
fix_gtfs(gtfs, max_speed = NULL, unit = "km/h")
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- max_speed:

  A number. The maximum speed of trips, in the unit given by `unit`. If
  `NULL` (the default), speeds are not capped.

- unit:

  A string representing the unit in which `max_speed` is given. One of
  `"km/h"` (the default), `"m/s"` or `"mph"` (miles per hour).

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

5.  [`interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_shape_dist_traveled.md),
    only if the feed has a `shapes` table and `trips` has a `shape_id`
    column, replaces the `shape_dist_traveled` columns of `stop_times`
    and `shapes` with the distances, in meters, from the start of each
    shape. Existing values, whatever their unit, are replaced, and stops
    that can't be located along their trip's shape get `NA`.

The `trips` and `stop_times` tables are always required, and `stops` is
required to cap speeds, to fill blank times and to fill the distances
travelled along shapes. The warnings raised are those of the functions
above, so some warnings (e.g. about a missing `shapes` table) may be
raised twice.

## See also

[`remove_duplicates()`](https://ipea.github.io/gtfstools/dev/reference/remove_duplicates.md),
[`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md),
[`set_max_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_max_speed.md),
[`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md),
[`interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_shape_dist_traveled.md)

## Examples

``` r
library(dplyr)

data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

fixed_gtfs <- fix_gtfs(gtfs, max_speed = 40)

# duplicated agencies were removed, and the trip is now slower
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
#> 1: CPTM L07-0     06:19:33       06:19:33   18975            18
#>    shape_dist_traveled
#>                  <num>
#> 1:            60598.61
```
