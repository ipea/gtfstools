# Replace the shapes of cropped trips by their cuts

Replace the shapes of cropped trips by their cuts

## Usage

``` r
replace_cropped_shapes(gtfs, shape_cuts)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md).

- shape_cuts:

  The output of
  [`locate_cropped_trip_cuts()`](https://ipea.github.io/gtfstools/reference/locate_cropped_trip_cuts.md).

## Value

The GTFS object with the cut shapes added to `shapes`, the cropped trips
linked to them and the `shape_dist_traveled` of their `stop_times` set
to `NA`. Shapes no longer used by any trip are removed.
