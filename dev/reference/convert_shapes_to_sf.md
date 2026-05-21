# Convert `shapes` table to simple feature object

Converts the `shapes` table to a `LINESTRING sf` object.

## Usage

``` r
convert_shapes_to_sf(gtfs, shape_id = NULL, crs = 4326, sort_sequence = FALSE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- shape_id:

  A character vector including the `shape_id`s to be converted. If
  `NULL` (the default), all shapes are converted.

- crs:

  The CRS of the resulting object, either as an EPSG code or as an `crs`
  object. Defaults to 4326 (WGS 84).

- sort_sequence:

  A logical. Whether to sort shapes by `shape_pt_sequence`. Defaults to
  `FALSE`, otherwise spec-compliant feeds, in which shape points are
  already ordered by `shape_pt_sequence`, would be penalized through
  longer processing times. Shapes generated from unordered sequences do
  not correctly depict the real life trip shapes.

## Value

A `LINESTRING sf` object.

## Examples

``` r
# read gtfs
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

shapes_sf <- convert_shapes_to_sf(gtfs)
head(shapes_sf)
#> Simple feature collection with 6 features and 1 field
#> Geometry type: LINESTRING
#> Dimension:     XY
#> Bounding box:  xmin: -46.98404 ymin: -23.73644 xmax: -46.63535 ymax: -23.19474
#> Geodetic CRS:  WGS 84
#>   shape_id                       geometry
#> 1    17846 LINESTRING (-46.63535 -23.5...
#> 2    17847 LINESTRING (-46.87255 -23.1...
#> 3    17848 LINESTRING (-46.64073 -23.5...
#> 4    17849 LINESTRING (-46.98404 -23.5...
#> 5    17850 LINESTRING (-46.77604 -23.5...
#> 6    17851 LINESTRING (-46.69711 -23.7...

shapes_sf <- convert_shapes_to_sf(gtfs, shape_id = "17846")
shapes_sf
#> Simple feature collection with 1 feature and 1 field
#> Geometry type: LINESTRING
#> Dimension:     XY
#> Bounding box:  xmin: -46.87255 ymin: -23.53517 xmax: -46.63535 ymax: -23.19474
#> Geodetic CRS:  WGS 84
#>   shape_id                       geometry
#> 1    17846 LINESTRING (-46.63535 -23.5...
```
