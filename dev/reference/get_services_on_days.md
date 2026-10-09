# Get the services that run on the given days

Returns the services that run on at least one of the given days,
according to the `calendar` and `calendar_dates` tables (either may be
missing).

## Usage

``` r
get_services_on_days(gtfs, days)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- days:

  An integer vector of unique days, as the number of days since
  1970-01-01.

## Value

A character vector of unique `service_id`s, empty if no service runs on
the given days.
