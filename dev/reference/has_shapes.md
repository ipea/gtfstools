# Check whether a GTFS object has shapes linked to its trips

Check whether a GTFS object has shapes linked to its trips

## Usage

``` r
has_shapes(gtfs)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

## Value

`TRUE` if the GTFS object has a `shapes` table and a `shape_id` column
in its `trips` table, `FALSE` otherwise.
