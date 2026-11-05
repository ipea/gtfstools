# Check whether a feed has trips with times after midnight to fix

Detects the trips whose times after midnight are written as early
morning times (e.g. `"00:30:00"` instead of `"24:30:00"`), as
[`fix_overnight_times()`](https://ipea.github.io/gtfstools/reference/fix_overnight_times.md)
does, without fixing them: trips with a time more than 12 hours earlier
than the previous time of the trip, and `frequencies` entries whose
`end_time` is earlier than their `start_time`. Trips already written
with times past `"24:00:00"` don't count. Tables whose fields can't be
checked (e.g. a `stop_times` without an integer `stop_sequence`) are
skipped.

## Usage

``` r
has_overnight_trips(gtfs)
```

## Arguments

- gtfs:

  A GTFS object.

## Value

`TRUE` if
[`fix_overnight_times()`](https://ipea.github.io/gtfstools/reference/fix_overnight_times.md)
would change any time, `FALSE` otherwise.
