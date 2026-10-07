# Build the geometries of parts of shapes

Build the geometries of parts of shapes

## Usage

``` r
build_shape_cuts(cuts, shape_points)
```

## Arguments

- cuts:

  A `data.table` with the `shape_id` of each part and the positions, in
  meters from the start of the shape, where it starts (`from`) and ends
  (`to`).

- shape_points:

  The `"shape_points"` attribute of the output of
  [`locate_stops_along_shapes()`](https://ipea.github.io/gtfstools/dev/reference/locate_stops_along_shapes.md),
  on which the positions were measured.

## Value

A `sfc_LINESTRING` in WGS 84 with the geometry of each part.
