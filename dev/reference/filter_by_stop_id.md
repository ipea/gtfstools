# Filter GTFS object by `stop_id`

Filters a GTFS object by `stop_id`s, keeping (or dropping) relevant
entries in each file.

## Usage

``` r
filter_by_stop_id(
  gtfs,
  stop_id,
  keep = TRUE,
  include_children = TRUE,
  include_parents = keep,
  full_trips
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- stop_id:

  A character vector. The `stop_id`s used to filter the data.

- keep:

  A logical. Whether the entries related to the `trip_id`s that passes
  through the specified `stop_id`s should be kept or dropped (defaults
  to `TRUE`, which keeps the entries).

- include_children:

  A logical. Whether the filtered output should keep/drop children stops
  of those specified in `stop_id`. Defaults to `TRUE` - i.e. by default
  children stops are kept if their parents are kept and dropped if their
  parents are dropped.

- include_parents:

  A logical. Whether the filtered output should keep/drop parent
  stations of those specified in `stop_id`. Defaults to the same value
  of `keep` - i.e. by default parent stations are kept both when their
  children are kept and dropped, because they can be parents of multiple
  stops that are not necessarily dropped, even if their sibling are.

- full_trips:

  Defunct. Deprecated in version 1.3.0 and removed in the following
  major version: using it, with any value, raises an error. The function
  now always filters by the specified stops. To keep all stops of the
  trips that pass through them, subset `stop_times` by `stop_id` and
  pass the resulting `trip_id`s to
  [`filter_by_trip_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_trip_id.md).

## Value

The GTFS object passed to the `gtfs` parameter, after the filtering
process.

## See also

Other filtering functions:
[`filter_by_agency_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_agency_id.md),
[`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md),
[`filter_by_route_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_id.md),
[`filter_by_route_type()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_type.md),
[`filter_by_service_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_service_id.md),
[`filter_by_shape_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_shape_id.md),
[`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md),
[`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md),
[`filter_by_trip_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_trip_id.md),
[`filter_by_weekday()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_weekday.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
stop_ids <- c("18848", "940004157")

object.size(gtfs)
#> 811304 bytes

# keeps entries related to trips that pass through specified stop_ids
smaller_gtfs <- filter_by_stop_id(gtfs, stop_ids)
object.size(smaller_gtfs)
#> 64272 bytes

# drops entries related to trips that pass through specified stop_ids
smaller_gtfs <- filter_by_stop_id(gtfs, stop_ids, keep = FALSE)
object.size(smaller_gtfs)
#> 809872 bytes
```
