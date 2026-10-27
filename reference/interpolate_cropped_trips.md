# Interpolate the times of cropped trips

Interpolate the times of cropped trips

## Usage

``` r
interpolate_cropped_trips(gtfs, trip_id, first_sequence, last_sequence)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md).

- trip_id:

  The `trip_id`s of the cropped trips with blank times at their new
  first or last stop.

- first_sequence, last_sequence:

  The `stop_sequence` of the new first and last stops of each trip.

## Value

The GTFS object with the times of these trips interpolated, along their
shapes when possible, and along straight lines otherwise.
