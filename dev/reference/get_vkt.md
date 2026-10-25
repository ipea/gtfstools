# Get vehicle-kilometres travelled

Returns the vehicle-kilometres travelled (VKT) by each specified
`route_id`: the length of each of its trips, counted once for every
departure of the trip on every day on which its service runs. VKT can be
restricted to some dates and to a time of day.

## Usage

``` r
get_vkt(gtfs, route_id = NULL, date = NULL, from = NULL, to = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- route_id:

  A character vector including the `route_id`s to have their VKT
  calculated. If `NULL` (the default), the function calculates the VKT
  of every `route_id` in the GTFS. `route_id`s not listed in `trips` are
  ignored, with a warning.

- date:

  A `Date` vector (including `IDate`) or a character vector of dates in
  the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. If given, only these dates
  are counted. If `NULL` (the default), every day on which the services
  of the routes run is counted.

- from, to:

  Strings in the `"HH:MM:SS"` format. If given (both must be), only the
  departures at or after `from` and at or before `to` are counted. If
  `NULL` (the default), every departure is counted.

## Value

A `data.table` with the columns `route_id`, `n_days` (the number of
counted days on which at least one counted departure of the route runs),
`vkt` (the vehicle-kilometres travelled on these days, in km) and
`vkt_daily_mean` (`vkt` divided by `n_days`, in km per day), sorted by
`route_id`. Routes without any departure on the counted days (and within
the time of day) are not included.

## Details

The VKT of a route is the sum, over its trips, of the length of each
trip times its number of departures times the number of counted days on
which its service runs, according to the `calendar` and `calendar_dates`
tables. Departures are counted as in
[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md):
trips listed in the `frequencies` table depart once per headway, the
other trips depart once, and departures after midnight belong to the
previous service day. Unlike in
[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md),
the time of day includes `to`, as in
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md).
An error is raised if the `frequencies` table has invalid entries for
trips that run on the counted days.

Trip lengths are calculated with
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
along the shape of each trip from its first to its last stop, so trips
to and from the depot are not included. If the GTFS has no `shapes`
table, the straight-line distances between stops are used instead, with
a warning. Trips whose length is unknown (e.g. trips without a usable
shape, which also raise a warning, or trips listed in `frequencies` but
not in `stop_times`) add nothing to the VKT, but the days on which they
run still count in `n_days`. If no counted trip of a route has a known
length, its `vkt` is `NA`.

## See also

[`get_vmt()`](https://ipea.github.io/gtfstools/dev/reference/get_vmt.md)
for vehicle-miles,
[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md),
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
[`get_summary()`](https://ipea.github.io/gtfstools/dev/reference/get_summary.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# VKT of every route over every day of the feed's calendar
vkt <- get_vkt(gtfs)
head(vkt)
#>    route_id n_days        vkt vkt_daily_mean
#>      <char>  <int>      <num>          <num>
#> 1:  2002-10   4505  4941723.3     1096.94191
#> 2:  2105-10   4505 11041692.2     2450.98605
#> 3:  2161-10   4505 11842279.1     2628.69681
#> 4:  4491-10   4505  7244927.9     1608.19709
#> 5:  5290-10   4505 16438977.8     3649.05168
#> 6:  6450-51   3219   252483.4       78.43535

# VKT of two routes in the morning peak of a single day
get_vkt(
  gtfs,
  route_id = c("CPTM L07", "2002-10"),
  date = "2019-03-04",
  from = "07:00:00",
  to = "09:00:00"
)
#>    route_id n_days       vkt vkt_daily_mean
#>      <char>  <int>     <num>          <num>
#> 1:  2002-10      1  140.4621       140.4621
#> 2: CPTM L07      1 2544.6974      2544.6974
```
