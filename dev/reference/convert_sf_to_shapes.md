# Convert a simple feature object into a `shapes` table

Converts a `LINESTRING sf` object into a GTFS `shapes` table.

## Usage

``` r
convert_sf_to_shapes(sf_shapes, shape_id = NULL, calculate_distance = TRUE)
```

## Arguments

- sf_shapes:

  A `LINESTRING sf` associating each `shape_id`s to a geometry. This
  object must use CRS WGS 84 (EPSG code 4326).

- shape_id:

  A character vector specifying the `shape_id`s to be converted. If
  `NULL` (the default), all shapes are converted.

- calculate_distance:

  A logical. Whether to calculate and populate the `shape_dist_traveled`
  column. This column is used to describe the distance along the shape
  from each one of its points to its first point, in meters. Distances
  are great-circle distances on a sphere with the same radius used by
  `{s2}` (6,371,010 meters), regardless of whether
  [`sf::sf_use_s2()`](https://r-spatial.github.io/sf/reference/s2.html)
  is enabled. Defaults to `TRUE`.

## Value

A `data.table` representing a GTFS `shapes` table.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# first converting existing shapes table into a sf object
shapes_sf <- convert_shapes_to_sf(gtfs)
head(shapes_sf)
#> Simple feature collection with 6 features and 1 field
#> Geometry type: LINESTRING
#> Dimension:     XY
#> Bounding box:  xmin: -46.69114 ymin: -23.64631 xmax: -46.47121 ymax: -23.48005
#> Geodetic CRS:  WGS 84
#>   shape_id                       geometry
#> 1    17838 LINESTRING (-46.64105 -23.6...
#> 2    17839 LINESTRING (-46.60321 -23.4...
#> 3    17840 LINESTRING (-46.58193 -23.5...
#> 4    17841 LINESTRING (-46.69114 -23.5...
#> 5    17842 LINESTRING (-46.66696 -23.5...
#> 6    17843 LINESTRING (-46.47127 -23.5...

# by default converts all shapes
result <- convert_sf_to_shapes(shapes_sf)
result
#>        shape_id shape_dist_traveled shape_pt_lon shape_pt_lat shape_pt_sequence
#>          <char>               <num>        <num>        <num>             <int>
#>     1:    17838              0.0000    -46.64105    -23.64631                 1
#>     2:    17838            164.9708    -46.64116    -23.64483                 2
#>     3:    17838            379.5660    -46.64131    -23.64291                 3
#>     4:    17838            522.7076    -46.64140    -23.64162                 4
#>     5:    17838            623.3519    -46.64135    -23.64072                 5
#>    ---                                                                         
#> 12291:    70393          18489.1429    -46.63658    -23.68139               475
#> 12292:    70393          18498.9136    -46.63664    -23.68146               476
#> 12293:    70393          18515.8467    -46.63672    -23.68160               477
#> 12294:    70393          18520.4064    -46.63674    -23.68163               478
#> 12295:    70393          18523.6032    -46.63677    -23.68164               479

# shape_id argument controls which shapes are converted
result <- convert_sf_to_shapes(shapes_sf, shape_id = c("17846", "17847"))
result
#>       shape_id shape_dist_traveled shape_pt_lon shape_pt_lat shape_pt_sequence
#>         <char>               <num>        <num>        <num>             <int>
#>    1:    17846             0.00000    -46.63535    -23.53517                 1
#>    2:    17846            13.55178    -46.63548    -23.53513                 2
#>    3:    17846            95.86978    -46.63626    -23.53494                 3
#>    4:    17846           184.81732    -46.63710    -23.53473                 4
#>    5:    17846           211.17349    -46.63735    -23.53466                 5
#>   ---                                                                         
#> 1090:    17847         60507.76810    -46.63735    -23.53466               543
#> 1091:    17847         60534.12426    -46.63710    -23.53473               544
#> 1092:    17847         60623.07180    -46.63626    -23.53494               545
#> 1093:    17847         60705.38981    -46.63548    -23.53513               546
#> 1094:    17847         60718.94158    -46.63535    -23.53517               547

# calculate_distance argument controls whether to calculate
# shape_dist_traveled or not
result <- convert_sf_to_shapes(shapes_sf, calculate_distance = TRUE)
result
#>        shape_id shape_dist_traveled shape_pt_lon shape_pt_lat shape_pt_sequence
#>          <char>               <num>        <num>        <num>             <int>
#>     1:    17838              0.0000    -46.64105    -23.64631                 1
#>     2:    17838            164.9708    -46.64116    -23.64483                 2
#>     3:    17838            379.5660    -46.64131    -23.64291                 3
#>     4:    17838            522.7076    -46.64140    -23.64162                 4
#>     5:    17838            623.3519    -46.64135    -23.64072                 5
#>    ---                                                                         
#> 12291:    70393          18489.1429    -46.63658    -23.68139               475
#> 12292:    70393          18498.9136    -46.63664    -23.68146               476
#> 12293:    70393          18515.8467    -46.63672    -23.68160               477
#> 12294:    70393          18520.4064    -46.63674    -23.68163               478
#> 12295:    70393          18523.6032    -46.63677    -23.68164               479
```
