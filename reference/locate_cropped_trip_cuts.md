# Locate the cuts of the shapes of cropped trips

Locate the cuts of the shapes of cropped trips

## Usage

``` r
locate_cropped_trip_cuts(gtfs, st, cropped_trip, trip_start, n_stops, is_kept)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md).

- st:

  The sorted stop_times of every trip, in which the rows of each trip
  are contiguous.

- cropped_trip:

  The indices of the cropped trips.

- trip_start, n_stops:

  The first row of each trip in `st` and its number of rows.

- is_kept:

  Whether each row of `st` is kept.

## Value

A list with `trip_cuts`, a `data.table` with the `trip_id` of each
cropped trip with a cut, its `shape_id` and the index of its cut in
`cuts`, which holds the unique `shape_id`, `from` and `to` of the cuts,
and `shape_points`, the shape points on which the positions were
measured.
