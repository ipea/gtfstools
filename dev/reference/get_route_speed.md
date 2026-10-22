# Get route speed

Returns summary statistics of the average speeds of the trips of each
specified `route_id`.

## Usage

``` r
get_route_speed(
  gtfs,
  route_id = NULL,
  method = "shapes",
  unit = "km/h",
  from = NULL,
  to = NULL
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- route_id:

  A character vector including the `route_id`s to have their speeds
  summarised. If `NULL` (the default), the function summarises the
  speeds of every `route_id` in the GTFS. `route_id`s not listed in
  `trips` are ignored, with a warning.

- method:

  A string, either `"shapes"` (the default) or `"euclidean"`. `"shapes"`
  measures lengths along the trip's shape, described in the `shapes`
  table, while `"euclidean"` measures the straight-line (great-circle)
  distances between consecutive stops. If the GTFS object doesn't have a
  `shapes` table, or if its `trips` table doesn't have a `shape_id`
  column, `"euclidean"` is used instead, with a warning.

- unit:

  A string representing the unit in which the speeds are desired. One of
  `"km/h"` (the default), `"m/s"` or `"mph"` (miles per hour).

- from:

  A string, in the "HH:MM:SS" format. Only trips that depart from their
  first stop at or after `from` are included. If `NULL` (the default),
  there is no lower limit.

- to:

  A string, in the "HH:MM:SS" format. Only trips that depart from their
  first stop at or before `to` are included. If `NULL` (the default),
  there is no upper limit.

## Value

A `data.table` with the `route_id` and the minimum (`min_speed`), mean
(`mean_speed`), median (`median_speed`), maximum (`max_speed`) and
standard deviation (`sd_speed`) of the speeds of its trips, ordered by
`route_id`.

## Details

The speed of each trip is calculated with
[`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
(with `by = "trip"`), whose details also apply here. Each trip is linked
to its route by the `trips` table. `mean_speed` is the unweighted mean
of the trip speeds, not the total length of the trips divided by their
total duration. Trips listed in `frequencies` count once, regardless of
their headways.

Trips with `NA` speeds are ignored. Routes whose trips all have `NA`
speeds get `NA` statistics, and `sd_speed` is `NA` for routes with a
single trip with a known speed. Routes without any trip in `stop_times`
(or, if `from` or `to` is given, without any trip departing within the
time of day) are not returned.

## See also

[`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md),
[`set_route_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_route_speed.md),
[`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

route_speed <- get_route_speed(gtfs)
head(route_speed)
#>    route_id min_speed mean_speed median_speed max_speed  sd_speed
#>      <char>     <num>      <num>        <num>     <num>     <num>
#> 1:  2002-10  8.360838   8.360838     8.360838  8.360838        NA
#> 2:  2105-10  9.651135   9.951090     9.951090 10.251044 0.4241997
#> 3:  2161-10 11.172445  11.398943    11.398943 11.625440 0.3203161
#> 4:  4491-10 12.011979  13.585046    13.585046 15.158114 2.2246538
#> 5:  5290-10  9.103782   9.870054     9.870054 10.636326 1.0836719
#> 6:  6450-51 11.450417  11.450417    11.450417 11.450417        NA

route_ids <- c("CPTM L07", "2002-10")
route_speed <- get_route_speed(gtfs, route_ids)
route_speed
#>    route_id min_speed mean_speed median_speed max_speed     sd_speed
#>      <char>     <num>      <num>        <num>     <num>        <num>
#> 1:  2002-10  8.360838   8.360838     8.360838  8.360838           NA
#> 2: CPTM L07 26.730015  26.730015    26.730015 26.730015 7.944109e-15

route_speed <- get_route_speed(gtfs, route_ids, method = "euclidean")
route_speed
#>    route_id min_speed mean_speed median_speed max_speed     sd_speed
#>      <char>     <num>      <num>        <num>     <num>        <num>
#> 1:  2002-10  6.559614   6.559614     6.559614  6.559614           NA
#> 2: CPTM L07 24.342591  24.342591    24.342591 24.342591 3.552714e-15

route_speed <- get_route_speed(gtfs, route_ids, unit = "m/s")
route_speed
#>    route_id min_speed mean_speed median_speed max_speed     sd_speed
#>      <char>     <num>      <num>        <num>     <num>        <num>
#> 1:  2002-10  2.322455   2.322455     2.322455  2.322455           NA
#> 2: CPTM L07  7.425004   7.425004     7.425004  7.425004 2.512148e-15
```
