# Filter a GTFS object using a spatial extent

Filters a GTFS object using a spatial extent (passed as an `sf` object),
keeping (or dropping) entries related to shapes and trips whose
geometries are selected through a specified spatial operation.

## Usage

``` r
filter_by_spatial_extent(
  gtfs,
  geom,
  spatial_operation = sf::st_intersects,
  keep = TRUE
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- geom:

  An `sf` object. Describes the spatial extent used to filter the data.

- spatial_operation:

  A spatial operation function from the set of options listed in
  [geos_binary_pred](https://r-spatial.github.io/sf/reference/geos_binary_pred.html)
  (check the [DE-I9M](https://en.wikipedia.org/wiki/DE-9IM) Wikipedia
  entry for the definition of each function). Defaults to
  [`sf::st_intersects`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html),
  which tests if the shapes and trips have ANY intersection with the
  object specified in `geom`. Please note that `geom` is passed as the
  `x` argument of these functions.

- keep:

  A logical. Whether the entries related to the shapes and trips
  selected by the given spatial operation should be kept or dropped
  (defaults to `TRUE`, which keeps the entries).

## Value

The GTFS object passed to the `gtfs` parameter, after the filtering
process.

## See also

Other filtering functions:
[`filter_by_agency_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_agency_id.md),
[`filter_by_route_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_id.md),
[`filter_by_route_type()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_type.md),
[`filter_by_service_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_service_id.md),
[`filter_by_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_sf.md),
[`filter_by_shape_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_shape_id.md),
[`filter_by_stop_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_stop_id.md),
[`filter_by_time_of_day()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_time_of_day.md),
[`filter_by_trip_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_trip_id.md),
[`filter_by_weekday()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_weekday.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

shape_id <- "68962"
shape_sf <- convert_shapes_to_sf(gtfs, shape_id)
bbox <- sf::st_bbox(shape_sf)
object.size(gtfs)
#> 860808 bytes

# keeps entries that intersect with the specified polygon
smaller_gtfs <- filter_by_spatial_extent(gtfs, bbox)
object.size(smaller_gtfs)
#> 324952 bytes

# drops entries that intersect with the specified polygon
smaller_gtfs <- filter_by_spatial_extent(gtfs, bbox, keep = FALSE)
object.size(smaller_gtfs)
#> 512288 bytes

# uses a different function to filter the gtfs
smaller_gtfs <- filter_by_spatial_extent(
  gtfs,
  bbox,
  spatial_operation = sf::st_contains
)
object.size(smaller_gtfs)
#> 68976 bytes
```
