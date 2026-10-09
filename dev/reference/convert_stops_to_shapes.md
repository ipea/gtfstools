# Convert stops into shapes

Creates shapes for the given trips, linking their consecutive stops
along straight lines, and assigns them to the trips. Useful for feeds
without shapes, or in which some trips are not linked to a shape.

## Usage

``` r
convert_stops_to_shapes(gtfs, trip_id = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to get new shapes, which
  replace the shapes they are currently linked to. If `NULL` (the
  default), only the trips that are not linked to a usable shape get new
  shapes (see details).

## Value

The GTFS object passed to the `gtfs` parameter, with the new shapes
added to the `shapes` table (created if needed) and assigned to the
trips in the `trips` table.

## Details

The shape of a trip links its stops, in `stop_sequence` order, along
straight lines. Stops without coordinates, or not listed in `stops`, are
skipped. Trips that visit the same sequence of stops share the same
shape. The new shapes get new `shape_id`s (`"stops_shape_1"`,
`"stops_shape_2"`, etc.), different from any `shape_id` already listed
in `shapes` or `trips`. Their `shape_dist_traveled` is not calculated,
because the distance unit used by the feed is unknown, and the
`shape_dist_traveled` of the `stop_times` entries of the trips that get
new shapes, if present, is set to `NA`. Shapes no longer used by any
trip are kept (please use
[`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md)
to remove them).

A shape is usable if it has at least two distinct points with
coordinates. With `trip_id = NULL`, the trips that get new shapes are
those not linked to a `shape_id`, or linked to a `shape_id` that is not
listed in `shapes` or whose shape is not usable (all trips, if the feed
doesn't have a `shapes` table). These are the trips that
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
and
[`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md)
can't measure along a shape.

Trips with fewer than two distinct stops with coordinates, or without
`stop_times` entries, can't get a usable shape, so they keep their
current `shape_id`, with a warning.

## See also

[`get_trip_geometry()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_geometry.md),
[`convert_sf_to_shapes()`](https://ipea.github.io/gtfstools/dev/reference/convert_sf_to_shapes.md),
[`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# a feed without shapes gets one shape for each sequence of stops
gtfs$shapes <- NULL
new_gtfs <- convert_stops_to_shapes(gtfs)
head(new_gtfs$shapes)
#>         shape_id shape_pt_lat shape_pt_lon shape_pt_sequence
#>           <char>        <num>        <num>             <int>
#> 1: stops_shape_1    -23.54725    -46.62962                 1
#> 2: stops_shape_1    -23.55003    -46.63133                 2
#> 3: stops_shape_1    -23.54787    -46.63316                 3
#> 4: stops_shape_1    -23.54485    -46.63383                 4
#> 5: stops_shape_1    -23.54657    -46.63639                 5
#> 6: stops_shape_1    -23.54557    -46.63838                 6
head(new_gtfs$trips[, c("trip_id", "shape_id")])
#>       trip_id       shape_id
#>        <char>         <char>
#> 1: CPTM L07-0 stops_shape_11
#> 2: CPTM L07-1 stops_shape_12
#> 3: CPTM L08-0 stops_shape_13
#> 4: CPTM L08-1 stops_shape_14
#> 5: CPTM L09-0 stops_shape_15
#> 6: CPTM L09-1 stops_shape_16
```
