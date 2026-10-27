# Calculate the route headways of a feed on its busiest day

Calculate the route headways of a feed on its busiest day

## Usage

``` r
summarise_route_frequency(feed, service_days, date, from, to)
```

## Arguments

- feed:

  A `dt_gtfs` object, already filtered.

- service_days:

  The service days of `feed`, as returned by
  [`get_service_days()`](https://ipea.github.io/gtfstools/reference/get_service_days.md).

- date:

  A `Date` vector, or `NULL`. The day is chosen among these dates.

- from, to:

  Strings in the `"HH:MM:SS"` format, or `NULL`, in which case the time
  of day spans the departures of the day, rounded out to whole hours.

## Value

A list with the elements `headways` (the headway of each route and
direction, in minutes, named by `route_id`), `stats` (their summary, as
created by
[`summarise_distribution()`](https://ipea.github.io/gtfstools/reference/summarise_distribution.md)),
`date`, `from` and `to` (the day and time of day in which the headways
were measured, `NA` if there is none).
