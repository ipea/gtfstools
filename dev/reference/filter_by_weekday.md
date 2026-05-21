# Filter GTFS object by weekday

Filters a GTFS object by weekday, keeping (or dropping) the relevant
entries in each file.

## Usage

``` r
filter_by_weekday(gtfs, weekday, combine = "or", keep = TRUE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- weekday:

  A character vector. The weekdays used to filter the data. Possible
  values are
  `c("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")`.

- combine:

  A string. Specifies which logic operation (OR or AND) should be used
  to filter the calendar table when multiple weekdays are specified.
  Defaults to `"or"`. Please check the details and examples sections for
  more information on this argument usage.

- keep:

  A logical. Whether the entries related to the specified weekdays
  should be kept or dropped (defaults to `TRUE`, which keeps the
  entries).

## Value

The GTFS object passed to the `gtfs` parameter, after the filtering
process.

## `combine` usage

When filtering the calendar table using weekdays, one could reason about
the process in different ways. For example, you may want to keep only
services who run on mondays AND tuesdays. Or you may want to keep
services that run EITHER on mondays OR on tuesdays. The first case is
the equivalent of filtering using the expression
`monday == 1 & tuesday == 1`, while the second uses
`monday == 1 | tuesday == 1`. You can use the `combine` argument to
control this behaviour.

Please note that `combine` also works together with `keep`. Using the
same examples listed above, you could either keep the entries related to
services that run on mondays and tuesdays or drop them, depending on the
value you pass to `keep`.

## See also

Other filtering functions:
[`filter_by_agency_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_agency_id.md),
[`filter_by_route_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_id.md),
[`filter_by_route_type()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_type.md),
[`filter_by_service_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_service_id.md),
[`filter_by_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_sf.md),
[`filter_by_shape_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_shape_id.md),
[`filter_by_spatial_extent()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md),
[`filter_by_stop_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_stop_id.md),
[`filter_by_time_of_day()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_time_of_day.md),
[`filter_by_trip_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_trip_id.md)

## Examples

``` r
# read gtfs
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

object.size(gtfs)
#> 811304 bytes

# keeps entries related to services than run EITHER on monday OR on sunday
smaller_gtfs <- filter_by_weekday(gtfs, weekday = c("monday", "sunday"))
smaller_gtfs$calendar[, c("service_id", "monday", "sunday")]
#>     service_id monday sunday
#>         <char>  <int>  <int>
#>  1:        USD      1      1
#>  2:        U__      1      0
#>  3:        US_      1      0
#>  4:        _SD      0      1
#>  5:        __D      0      1
#>  6:        USD      1      1
#>  7:        U__      1      0
#>  8:        US_      1      0
#>  9:        _SD      0      1
#> 10:        __D      0      1
object.size(smaller_gtfs)
#> 811248 bytes

# keeps entries related to services than run on monday AND on sunday
smaller_gtfs <- filter_by_weekday(
  gtfs,
  weekday = c("monday", "sunday"),
  combine = "and"
)
smaller_gtfs$calendar[, c("service_id", "monday", "sunday")]
#>    service_id monday sunday
#>        <char>  <int>  <int>
#> 1:        USD      1      1
#> 2:        USD      1      1
object.size(smaller_gtfs)
#> 762152 bytes

# drops entries related to services than run EITHER on monday OR on sunday
# the resulting gtfs shouldn't include any trips running on these days
smaller_gtfs <- filter_by_weekday(
  gtfs,
  weekday = c("monday", "sunday"),
  keep = FALSE
)
smaller_gtfs$calendar[, c("service_id", "monday", "sunday")]
#>    service_id monday sunday
#>        <char>  <int>  <int>
#> 1:        _S_      0      0
#> 2:        _S_      0      0
object.size(smaller_gtfs)
#> 19168 bytes

# drops entries related to services than run on monday AND on sunday
# the resulting gtfs may include trips that run on these days, but no trips
# that run on both these days
smaller_gtfs <- filter_by_weekday(
  gtfs,
  weekday = c("monday", "sunday"),
  combine = "and",
  keep = FALSE
)
smaller_gtfs$calendar[, c("service_id", "monday", "sunday")]
#>     service_id monday sunday
#>         <char>  <int>  <int>
#>  1:        U__      1      0
#>  2:        US_      1      0
#>  3:        _SD      0      1
#>  4:        __D      0      1
#>  5:        _S_      0      0
#>  6:        U__      1      0
#>  7:        US_      1      0
#>  8:        _SD      0      1
#>  9:        __D      0      1
#> 10:        _S_      0      0
object.size(smaller_gtfs)
#> 69880 bytes
```
