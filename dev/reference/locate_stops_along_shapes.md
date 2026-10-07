# Locate stops along their trips' shapes

Locate stops along their trips' shapes

## Usage

``` r
locate_stops_along_shapes(gtfs, st, stop_lat, stop_lon, sort_sequence)
```

## Arguments

- gtfs:

  A GTFS object.

- st:

  A `data.table` with the stop_times of the relevant trips, in which the
  rows of each trip are contiguous.

- stop_lat, stop_lon:

  The coordinates of the stops listed in `st`.

- sort_sequence:

  Whether to sort the shapes by `shape_pt_sequence`.

## Value

A numeric vector with the position of each stop along its trip's shape,
in meters from the start of the shape. Stops whose trip is not linked to
a usable shape, or that don't have coordinates, get `NA`.
