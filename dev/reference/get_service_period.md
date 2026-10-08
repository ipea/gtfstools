# Get the service days of a GTFS object

Returns the days on which at least one service used by a trip runs (any
service, if `trips` has no `service_id` field), according to the
`calendar` and `calendar_dates` tables (either may be missing).

## Usage

``` r
get_service_period(gtfs)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

## Value

A sorted `Date` vector of unique days, empty if the feed has none.
