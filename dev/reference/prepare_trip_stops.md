# Select and prepare the stop_times of the relevant trips

Select and prepare the stop_times of the relevant trips

## Usage

``` r
prepare_trip_stops(gtfs, trip_id, with_departure = FALSE, with_row = FALSE)
```

## Arguments

- gtfs:

  A GTFS object.

- trip_id:

  The `trip_id`s whose stop_times should be selected, or `NULL` to
  select every trip.

- with_departure:

  Whether to also select the `departure_time`.

- with_row:

  Whether to also return the `row` of each selected stop_time in
  `gtfs$stop_times`.

## Value

A new `data.table` with the `trip_id`, `stop_id` and `stop_sequence`
(and, if `with_departure` is `TRUE`, the `departure_time`, and if
`with_row` is `TRUE`, the `row`) of the selected stop_times, sorted by
`trip_id` and `stop_sequence`, plus the `stop_lat` and `stop_lon` of
each stop.
