# Summarise the calendar of the services of a feed

Summarise the calendar of the services of a feed

## Usage

``` r
summarise_services(feed, service_days)
```

## Arguments

- feed:

  A `dt_gtfs` object, already filtered.

- service_days:

  The service days of `feed`, as returned by
  [`get_service_days()`](https://ipea.github.io/gtfstools/reference/get_service_days.md).

## Value

A one-row `data.table`, as described in the `services` element of the
[`get_summary()`](https://ipea.github.io/gtfstools/reference/get_summary.md)
output.
