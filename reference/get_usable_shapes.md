# Get the usable shapes of a shapes table

Returns the shapes with at least two distinct points with coordinates.
This is the single definition of a usable shape, used by both
[`convert_stops_to_shapes()`](https://ipea.github.io/gtfstools/reference/convert_stops_to_shapes.md)
and
[`locate_stops_along_shapes()`](https://ipea.github.io/gtfstools/reference/locate_stops_along_shapes.md).

## Usage

``` r
get_usable_shapes(shapes)
```

## Arguments

- shapes:

  A GTFS `shapes` table.

## Value

A character vector with the `shape_id`s of the usable shapes.
