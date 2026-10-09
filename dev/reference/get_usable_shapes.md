# Get the usable shapes of a shapes table

Returns the shapes with at least two distinct points with coordinates,
the same rule used in
[`locate_stops_along_shapes()`](https://ipea.github.io/gtfstools/dev/reference/locate_stops_along_shapes.md)
(keep both in sync).

## Usage

``` r
get_usable_shapes(shapes)
```

## Arguments

- shapes:

  A GTFS `shapes` table.

## Value

A character vector with the `shape_id`s of the usable shapes.
