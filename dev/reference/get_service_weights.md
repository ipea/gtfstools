# Get the number of trips each service runs on a day

Each trip counts once, except those listed in `frequencies`, which count
once per departure. A trip with an invalid `frequencies` entry counts
once, with a warning.

## Usage

``` r
get_service_weights(gtfs)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

## Value

A `data.table` with the columns `service_id` and `weight` (the number of
trips, as a double).
