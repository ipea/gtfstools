# Convert `shapes` table to simple feature object (deprecated)

This function is deprecated: calling it raises a warning. Please use
[`get_shapes_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_shapes_geometry.md)
instead, which takes the same arguments (except `sort_sequence`) and
returns the same result.

## Usage

``` r
convert_shapes_to_sf(gtfs, shape_id = NULL, crs = 4326, sort_sequence)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- shape_id:

  A character vector including the `shape_id`s to be converted. If
  `NULL` (the default), all shapes are converted.

- crs:

  The CRS of the resulting object, either as an EPSG code or as an `crs`
  object. Defaults to 4326 (WGS 84).

- sort_sequence:

  Deprecated; do not supply. Shapes are now always sorted by
  `shape_pt_sequence`. Passing `TRUE` raises a warning, and passing
  `FALSE` raises an error.

## Value

A `LINESTRING sf` object.

## See also

[`get_shapes_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_shapes_geometry.md),
which replaces this function.
