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
  from each one of its points to its first point. Defaults to `TRUE`.

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
#> Bounding box:  xmin: -46.98404 ymin: -23.73644 xmax: -46.63535 ymax: -23.19474
#> Geodetic CRS:  WGS 84
#>   shape_id                       geometry
#> 1    17846 LINESTRING (-46.63535 -23.5...
#> 2    17847 LINESTRING (-46.87255 -23.1...
#> 3    17848 LINESTRING (-46.64073 -23.5...
#> 4    17849 LINESTRING (-46.98404 -23.5...
#> 5    17850 LINESTRING (-46.77604 -23.5...
#> 6    17851 LINESTRING (-46.69711 -23.7...

# by default converts all shapes
result <- convert_sf_to_shapes(shapes_sf)
result
#>        shape_id shape_dist_traveled shape_pt_lon shape_pt_lat shape_pt_sequence
#>          <char>               <num>        <num>        <num>             <int>
#>     1:    17846             0.00000    -46.63535    -23.53517                 1
#>     2:    17846            13.55178    -46.63548    -23.53513                 2
#>     3:    17846            95.86978    -46.63626    -23.53494                 3
#>     4:    17846           184.81732    -46.63710    -23.53473                 4
#>     5:    17846           211.17349    -46.63735    -23.53466                 5
#>    ---                                                                         
#> 12291:    68962         26058.05526    -46.64066    -23.54921               628
#> 12292:    68962         26067.76199    -46.64057    -23.54922               629
#> 12293:    68962         26094.30002    -46.64033    -23.54913               630
#> 12294:    68962         26132.70120    -46.63995    -23.54910               631
#> 12295:    68962         26162.11007    -46.63967    -23.54907               632

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
#>     1:    17846             0.00000    -46.63535    -23.53517                 1
#>     2:    17846            13.55178    -46.63548    -23.53513                 2
#>     3:    17846            95.86978    -46.63626    -23.53494                 3
#>     4:    17846           184.81732    -46.63710    -23.53473                 4
#>     5:    17846           211.17349    -46.63735    -23.53466                 5
#>    ---                                                                         
#> 12291:    68962         26058.05526    -46.64066    -23.54921               628
#> 12292:    68962         26067.76199    -46.64057    -23.54922               629
#> 12293:    68962         26094.30002    -46.64033    -23.54913               630
#> 12294:    68962         26132.70120    -46.63995    -23.54910               631
#> 12295:    68962         26162.11007    -46.63967    -23.54907               632
```
