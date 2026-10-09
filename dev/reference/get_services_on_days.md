# Get the services that run on the given days

Returns the services that run on each of the given days, according to
the `calendar` and `calendar_dates` tables (either may be missing).

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

A `data.table` with the columns `service_id` and `day` (as an integer),
with one row for each service running on each day (rows may be
duplicated). Services with a missing `service_id` are not included.
