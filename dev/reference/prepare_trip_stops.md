# Select and prepare the stop_times of the relevant trips

Select and prepare the stop_times of the relevant trips

## Usage

``` r
prepare_trip_stops(gtfs, trip_id)
```

## Arguments

- gtfs:

  A GTFS object.

- trip_id:

  The `trip_id`s whose stop_times should be selected, or `NULL` to
  select every trip.

## Value

A new `data.table` with the `trip_id`, `stop_id` and `stop_sequence` of
the selected stop_times, sorted by `trip_id` and `stop_sequence`, plus
the `stop_lat` and `stop_lon` of each stop.
