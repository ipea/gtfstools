# Assert the shapes (and trips) fields needed to work with shapes

Asserts that `shapes` has `shape_id`, `shape_pt_lat`, `shape_pt_lon` and
`shape_pt_sequence`, with the expected classes, and, if `trips = TRUE`,
first that `trips` has `trip_id` and `shape_id`.

## Usage

``` r
assert_shapes_fields(gtfs, trips = TRUE)
```

## Arguments

- gtfs:

  A GTFS object.

- trips:

  Whether to also check the `trips` fields.

## Value

Invisibly, `TRUE`.
