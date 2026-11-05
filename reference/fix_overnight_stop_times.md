# Fix the times after midnight of `stop_times`

Also used by the functions that calculate speeds and durations, which
fix the times silently before using them.

## Usage

``` r
fix_overnight_stop_times(
  gtfs,
  trip_id = NULL,
  warn = TRUE,
  by_reference = FALSE,
  detect_only = FALSE
)
```

## Arguments

- gtfs:

  A GTFS object whose `stop_times` has the `trip_id`, `stop_sequence`,
  `arrival_time` and `departure_time` fields, of the classes asserted by
  [`fix_overnight_times()`](https://ipea.github.io/gtfstools/reference/fix_overnight_times.md).

- trip_id:

  A character vector with the `trip_id`s to fix, or `NULL` (the default)
  for every trip. Each trip is fixed on its own, so the functions that
  only use some trips fix only these.

- warn:

  Whether to warn about the times that still go back after the fix, and
  about malformed times.

- by_reference:

  Whether to write the fixed times into `gtfs$stop_times` itself. If
  `FALSE`, the table is copied before being changed.

- detect_only:

  Whether to only detect the times to fix, without fixing them.

## Value

The GTFS object, or, with `detect_only = TRUE`, `TRUE` if any time would
be fixed and `FALSE` otherwise.
