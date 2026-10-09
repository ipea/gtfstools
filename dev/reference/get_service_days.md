# Get the service days of a GTFS object and their number of trips

Returns the days on which at least one service used by a trip runs (any
service, if `trips` has no `service_id` field), according to the
`calendar` and `calendar_dates` tables (either may be missing), and the
number of trips that run on each of them.

## Usage

``` r
get_service_days(gtfs, count_trips = TRUE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- count_trips:

  A logical. Whether to count the trips of each day. If `FALSE`,
  `n_trips` is `NA`, which is faster when only the days are needed.

## Value

A `data.table` with the columns `date` and `n_trips` (`NA` if `trips`
has no `service_id` field or if `count_trips = FALSE`), sorted by date,
with one row per service day.
