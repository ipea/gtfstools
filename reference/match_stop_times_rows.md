# Match stop_times entries by trip and stop sequence

Match stop_times entries by trip and stop sequence

## Usage

``` r
match_stop_times_rows(stop_times, trip_id, stop_sequence)
```

## Arguments

- stop_times:

  The `stop_times` table.

- trip_id, stop_sequence:

  The `trip_id` and `stop_sequence` of each entry.

## Value

An integer vector with the row of each entry in `stop_times`. Repeated
`trip_id`/`stop_sequence` pairs in `stop_times` (invalid GTFS) are
resolved by their first match.
