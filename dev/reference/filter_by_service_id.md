# Filter GTFS object by `service_id`

Filters a GTFS object by `service_id`s, keeping (or dropping) the
relevant entries in each file.

## Usage

``` r
filter_by_service_id(gtfs, service_id, keep = TRUE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- service_id:

  A character vector. The `service_id`s used to filter the data.

- keep:

  A logical. Whether the entries related to the specified `service_id`s
  should be kept or dropped (defaults to `TRUE`, which keeps the
  entries).

## Value

The GTFS object passed to the `gtfs` parameter, after the filtering
process.

## See also

Other filtering functions:
[`filter_by_agency_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_agency_id.md),
[`filter_by_route_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_id.md),
[`filter_by_route_type()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_type.md),
[`filter_by_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_sf.md),
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
service_ids <- c("USD", "U__")

object.size(gtfs)
#> 811304 bytes

# keeps entries related to the specified service_ids
smaller_gtfs <- filter_by_service_id(gtfs, service_ids)
object.size(smaller_gtfs)
#> 810568 bytes

# drops entries related to the specified service_ids
smaller_gtfs <- filter_by_service_id(gtfs, service_ids, keep = FALSE)
object.size(smaller_gtfs)
#> 19648 bytes
```
