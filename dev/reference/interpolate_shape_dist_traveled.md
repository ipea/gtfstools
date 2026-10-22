# Interpolate the distances travelled along shapes

Calculates the distance, in meters, from the start of each shape to each
stop and to each shape point, and writes it to the `shape_dist_traveled`
columns of `stop_times` and `shapes`, replacing any existing values.

## Usage

``` r
interpolate_shape_dist_traveled(gtfs)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

## Value

A GTFS object whose `stop_times` and `shapes` have a
`shape_dist_traveled` column, in meters. The order of the rows and the
other columns are kept. The given GTFS object is not modified.

## Details

Each stop is projected onto the closest point of its trip's shape, with
stops advancing along the shape in `stop_sequence` order, as in
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
(see there for the limitations of this method). Distances are
great-circle distances on the sphere used by `{s2}`.

Existing `shape_dist_traveled` columns are entirely replaced, since
their values may be in any unit, so existing values are lost even where
new ones can't be calculated. Stops of trips not linked to a shape with
at least two distinct points (with a warning), stops without coordinates
and stops of trips with fewer than two stops with coordinates get `NA`,
as do shape points with missing coordinates. Unlike in
[`get_shape_length()`](https://ipea.github.io/gtfstools/dev/reference/get_shape_length.md),
these points are skipped, and the other points of the shape are still
measured.

## See also

[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
[`get_shape_length()`](https://ipea.github.io/gtfstools/dev/reference/get_shape_length.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

gtfs <- interpolate_shape_dist_traveled(gtfs)
head(gtfs$stop_times[, c("trip_id", "stop_id", "shape_dist_traveled")])
#>       trip_id stop_id shape_dist_traveled
#>        <char>  <char>               <num>
#> 1: CPTM L07-0   18940             10.5756
#> 2: CPTM L07-0   18920           3558.2262
#> 3: CPTM L07-0   18919           5982.7291
#> 4: CPTM L07-0   18917           7574.1820
#> 5: CPTM L07-0   18916           9584.6903
#> 6: CPTM L07-0   18965          11756.5330
head(gtfs$shapes)
#>    shape_id shape_pt_lat shape_pt_lon shape_pt_sequence shape_dist_traveled
#>      <char>        <num>        <num>             <int>               <num>
#> 1:    17846    -23.53517    -46.63535                 1             0.00000
#> 2:    17846    -23.53513    -46.63548                 2            13.55178
#> 3:    17846    -23.53494    -46.63626                 3            95.86978
#> 4:    17846    -23.53473    -46.63710                 4           184.81732
#> 5:    17846    -23.53466    -46.63735                 5           211.17349
#> 6:    17846    -23.53416    -46.63866                 6           355.92746
```
