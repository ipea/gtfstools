# Fall back to the euclidean method when a GTFS object has no usable shapes

If `method` is `"shapes"` but the GTFS object has no `shapes` table or
its `trips` table has no `shape_id` column (see
[`has_shapes()`](https://ipea.github.io/gtfstools/dev/reference/has_shapes.md)),
raises a warning of class `gtfstools_shapes_unavailable` and returns
`"euclidean"`. Otherwise returns `method` unchanged.

## Usage

``` r
resolve_shapes_method(gtfs, method, fallback)
```

## Arguments

- gtfs:

  A GTFS object.

- method:

  A string, `"shapes"` or `"euclidean"`.

- fallback:

  A string. The "i" bullet of the warning, which says what is calculated
  instead. It is interpolated by cli in the helper, so it may use cli
  markup but not the caller's variables.

## Value

A string, the method to use.
