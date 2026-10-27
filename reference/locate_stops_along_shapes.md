# Locate stops along their trips' shapes

Locate stops along their trips' shapes

## Usage

``` r
locate_stops_along_shapes(gtfs, st, stop_lat, stop_lon)
```

## Arguments

- gtfs:

  A GTFS object.

- st:

  A `data.table` with the stop_times of the relevant trips, in which the
  rows of each trip are contiguous.

- stop_lat, stop_lon:

  The coordinates of the stops listed in `st`.

## Value

A numeric vector with the position of each stop along its trip's shape,
in meters from the start of the shape. Stops whose trip is not linked to
a usable shape, or that don't have coordinates, get `NA`. Its
`"shape_points"` attribute is a list with the shape points on which the
positions were measured (`shapes`, without missing coordinates and
sorted by `shape_pt_sequence`), the rows of each shape in `shapes`
(`rows`) and the `shape_id` of each trip (`trip_shape_id`), in order of
appearance in `st`.
