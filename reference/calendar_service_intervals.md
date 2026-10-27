# Get the weekday intervals of the calendar entries

Returns one row per `calendar` entry and weekday on which it runs, with
the first and last days of the entry as integers (days since
1970-01-01). Entries with missing or inverted dates are dropped.

## Usage

``` r
calendar_service_intervals(gtfs, service_id = NULL)
```

## Arguments

- gtfs:

  A GTFS object.

- service_id:

  The `service_id`s whose entries should be kept, or `NULL` to keep
  every entry.

## Value

A `data.table` with the columns `service_id`, `weekday` (an integer, 1
is monday), `first_day` and `last_day`, empty if the GTFS object has no
`calendar` table.
