# Filter a GTFS object using a `simple features` object (deprecated)

This function has been deprecated as of the current package version and
will be completely removed from version 2.0.0 onward. Please use
[`filter_by_spatial_extent()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md)
instead.

Filters a GTFS object using the geometry of an `sf` object, keeping (or
dropping) entries related to shapes and trips selected through a spatial
operation.

## Usage

``` r
filter_by_sf(gtfs, geom, spatial_operation = sf::st_intersects, keep = TRUE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- geom:

  An `sf` object. Describes the geometry used to filter the data.

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

  A logical. Whether the entries related to the shapes and trips that
  cross through the given geometry should be kept or dropped (defaults
  to `TRUE`, which keeps the entries).

## Value

The GTFS object passed to the `gtfs` parameter, after the filtering
process.

## See also

Other filtering functions:
[`filter_by_agency_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_agency_id.md),
[`filter_by_route_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_id.md),
[`filter_by_route_type()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_type.md),
[`filter_by_service_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_service_id.md),
[`filter_by_shape_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_shape_id.md),
[`filter_by_spatial_extent()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md),
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
smaller_gtfs <- filter_by_sf(gtfs, bbox)
#> Warning: `filter_by_sf()` was deprecated in gtfstools 1.3.0.
#> ℹ Please use `filter_by_spatial_extent()` instead.
#> ℹ For backwards compatibility reasons, usage of `filter_by_sf()` is still
#>   allowed as of the current version, but the function will be removed from the
#>   package in version 2.0.0.
object.size(smaller_gtfs)
#> 324952 bytes

# drops entries that intersect with the specified polygon
smaller_gtfs <- filter_by_sf(gtfs, bbox, keep = FALSE)
#> Warning: `filter_by_sf()` was deprecated in gtfstools 1.3.0.
#> ℹ Please use `filter_by_spatial_extent()` instead.
#> ℹ For backwards compatibility reasons, usage of `filter_by_sf()` is still
#>   allowed as of the current version, but the function will be removed from the
#>   package in version 2.0.0.
object.size(smaller_gtfs)
#> 512288 bytes

# uses a different function to filter the gtfs
smaller_gtfs <- filter_by_sf(gtfs, bbox, spatial_operation = sf::st_contains)
#> Warning: `filter_by_sf()` was deprecated in gtfstools 1.3.0.
#> ℹ Please use `filter_by_spatial_extent()` instead.
#> ℹ For backwards compatibility reasons, usage of `filter_by_sf()` is still
#>   allowed as of the current version, but the function will be removed from the
#>   package in version 2.0.0.
object.size(smaller_gtfs)
#> 68976 bytes
```
