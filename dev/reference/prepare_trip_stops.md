# Select and prepare the stop_times of the relevant trips

Select and prepare the stop_times of the relevant trips

## Usage

``` r
prepare_trip_stops(gtfs, trip_id, sort_sequence)
```

## Arguments

- gtfs:

  A GTFS object.

- trip_id:

  The `trip_id`s whose stop_times should be selected, or `NULL` to
  select every trip.

- sort_sequence:

  Whether to sort the stop_times by `stop_sequence`.

## Value

A new `data.table` with the `trip_id`, `stop_id` (and, if
`sort_sequence` is `TRUE`, `stop_sequence`) of the selected stop_times,
in which the rows of each trip are contiguous, plus the `stop_lat` and
`stop_lon` of each stop.
