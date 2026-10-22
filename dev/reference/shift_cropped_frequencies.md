# Shift the frequencies of cropped trips

Shift the frequencies of cropped trips

## Usage

``` r
shift_cropped_frequencies(gtfs, trip_id, shift)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  The `trip_id`s of the cropped trips whose first stop is dropped.

- shift:

  The shift of each trip, in seconds. Entries with an `NA` or negative
  shift are kept unchanged.

## Value

The GTFS object with the `start_time` and `end_time` (and their `_secs`
columns, if present) of the `frequencies` entries of these trips
shifted.
