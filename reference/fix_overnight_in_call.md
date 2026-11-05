# Fix the times after midnight silently

Fixes the times after midnight of `stop_times` (and of `frequencies`)
silently, as the functions that use the times do before using them. A
feed whose times were already fixed is returned unchanged, without being
copied, so a function called by another one doesn't fix them again.

## Usage

``` r
fix_overnight_in_call(
  gtfs,
  trip_id = NULL,
  frequencies = FALSE,
  by_reference = FALSE
)
```

## Arguments

- gtfs:

  A GTFS object.

- trip_id:

  A character vector with the `trip_id`s to fix, or `NULL` for every
  trip.

- frequencies:

  Whether to fix the `end_time`s of `frequencies` too.

- by_reference:

  Whether to write the fixed times into `gtfs$stop_times` itself.

## Value

The GTFS object.
