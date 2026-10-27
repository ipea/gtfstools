# Select and sort the shape points

Select and sort the shape points

## Usage

``` r
prepare_shape_points(gtfs, shape_id = NULL)
```

## Arguments

- gtfs:

  A GTFS object.

- shape_id:

  The `shape_id`s whose points should be selected, or `NULL` to select
  every shape.

## Value

A new `data.table` with the `shape_id`, `shape_pt_lat`, `shape_pt_lon`
and `shape_pt_sequence` of the selected points, sorted by `shape_id` and
`shape_pt_sequence`. Points with missing coordinates are kept; points
with a missing `shape_id` are kept when every shape is selected (the
callers never request a missing `shape_id`).
