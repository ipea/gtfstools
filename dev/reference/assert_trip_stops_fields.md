# Assert the stop_times and stops fields needed to work with trip stops

Asserts that `stop_times` has `trip_id`, `stop_id` and `stop_sequence`
and that `stops` has `stop_id`, `stop_lat` and `stop_lon`, with the
expected classes. `stop_times` is checked first, so the functions that
share these checks report errors in the same order.

## Usage

``` r
assert_trip_stops_fields(gtfs)
```

## Arguments

- gtfs:

  A GTFS object.

## Value

Invisibly, `TRUE`.
