# Get the earliest departure of each trip

Get the earliest departure of each trip

## Usage

``` r
first_departure_per_trip(trip_id, departure_secs)
```

## Arguments

- trip_id, departure_secs:

  The `trip_id` and the departure time (in seconds) of each `stop_times`
  row.

## Value

A `data.table` with the columns `trip_id` and `departure_secs` (the
earliest non-missing departure of the trip), with one row per trip with
at least one departure, in order of first appearance of the timed rows.
