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
  full_trips = TRUE
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

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

  A logical. Whether to keep all stops that compose trips that pass
  through the stops specified in `stop_id`. Defaults to `TRUE`, in order
  to preserve the behavior of the function in versions 1.2.0 and below.
  Please note that when `TRUE`, the resultant filtered feed may contain
  more stops than the ones specified in `stop_id` to preserve the
  integrity of the trips. IMPORTANT: using `full_trips = TRUE` is
  flagged as deprecated as of version 1.3.0 and this parameter will
  default to `FALSE` from version 2.0.0 onward.

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
[`filter_by_spatial_extent()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md),
[`filter_by_time_of_day()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_time_of_day.md),
[`filter_by_trip_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_trip_id.md),
[`filter_by_weekday()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_weekday.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
stop_ids <- c("18848", "940004157")

object.size(gtfs)
#> 811304 bytes

# keeps entries related to trips that pass through specified stop_ids
smaller_gtfs <- filter_by_stop_id(gtfs, stop_ids, full_trips = FALSE)
object.size(smaller_gtfs)
#> 64272 bytes

# drops entries related to trips that pass through specified stop_ids
smaller_gtfs <- filter_by_stop_id(
  gtfs,
  stop_ids,
  keep = FALSE,
  full_trips = FALSE
)
object.size(smaller_gtfs)
#> 809872 bytes

# the old behavior of filtering trips that contained the specified stops has
# been deprecated
invisible(filter_by_stop_id(gtfs, stop_ids, full_trips = TRUE))
#> Warning: The `filter_by_stop_id()` behavior of filtering by trips that contain the
#> specified stops was deprecated in gtfstools 1.3.0.
#> ℹ For backwards compatibility reasons, this behavior is still the default as of
#>   version 1.3.0, and is controlled by the parameter `full_trips`.
#> ℹ Please set `full_trips` to "FALSE" to actually filter by `stop_ids`. This
#>   behavior will be the default from version 2.0.0 onward.
#> ℹ To achieve the old behavior, manually subset the `stop_times` table by
#>   `stop_id` and specify the `trip_ids` included in the output in
#>   `filter_by_trip_id()`.
```
