# Convert `stops` table to simple feature object (deprecated)

This function is deprecated: calling it raises a warning. Please use
[`get_stops_geometry()`](https://ipea.github.io/gtfstools/reference/get_stops_geometry.md)
instead, which takes the same arguments and returns the same result.

## Usage

``` r
convert_stops_to_sf(gtfs, stop_id = NULL, crs = 4326)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md).

- stop_id:

  A character vector including the `stop_id`s to be converted. If `NULL`
  (the default), all stops are converted.

- crs:

  The CRS of the resulting object, either as an EPSG code or as an `crs`
  object. Defaults to 4326 (WGS 84).

## Value

A `POINT sf` object.

## See also

[`get_stops_geometry()`](https://ipea.github.io/gtfstools/reference/get_stops_geometry.md),
which replaces this function.
