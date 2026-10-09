# Build a timetable

Joins the given trips and stop times, and then each resulting row to the
dates on which its trip runs. Used by
[`get_stop_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_timetable.md)
and
[`get_route_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_route_timetable.md).

## Usage

``` r
build_timetable(gtfs, trips, stop_times, date, sort_by, call = parent.frame())
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trips, stop_times:

  The (possibly filtered) `trips` and `stop_times` tables. They are not
  modified.

- date:

  A `Date` vector, possibly empty.

- sort_by:

  A character vector with the columns to sort the timetable by. It may
  include the temporary columns `".departure_secs"` (the departure time
  in seconds) and `".first_departure_secs"` (the first departure time of
  the trip in seconds), which are removed after sorting.

- call:

  The environment of the calling function, in which errors are reported.

## Value

A `data.table` with the column `date`, followed by the columns of
`trips` and those of `stop_times`, sorted by `sort_by`.
