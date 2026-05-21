# Convert `stops` table to simple feature object

Converts the `stops` table to a `POINT sf` object.

## Usage

``` r
convert_stops_to_sf(gtfs, stop_id = NULL, crs = 4326)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- stop_id:

  A character vector including the `stop_id`s to be converted. If `NULL`
  (the default), all stops are converted.

- crs:

  The CRS of the resulting object, either as an EPSG code or as an `crs`
  object. Defaults to 4326 (WGS 84).

## Value

A `POINT sf` object.

## Examples

``` r
# read gtfs
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

stops_sf <- convert_stops_to_sf(gtfs)
head(stops_sf)
#> Simple feature collection with 6 features and 3 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -46.69114 ymin: -23.646 xmax: -46.64094 ymax: -23.5465
#> Geodetic CRS:  WGS 84
#>   stop_id     stop_name stop_desc                    geometry
#> 1   18848      Clínicas           POINT (-46.67111 -23.55402)
#> 2   18849 Vila Madalena            POINT (-46.69114 -23.5465)
#> 3   18850    Consolação            POINT (-46.6602 -23.55809)
#> 4   18851     Conceição           POINT (-46.64124 -23.63504)
#> 5   18852     Jabaquara             POINT (-46.64103 -23.646)
#> 6   18853     São Judas           POINT (-46.64094 -23.62588)

stops_sf <- convert_stops_to_sf(gtfs, stop_id = "18848")
stops_sf
#> Simple feature collection with 1 feature and 3 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -46.67111 ymin: -23.55402 xmax: -46.67111 ymax: -23.55402
#> Geodetic CRS:  WGS 84
#>   stop_id stop_name stop_desc                    geometry
#> 1   18848  Clínicas           POINT (-46.67111 -23.55402)
```
