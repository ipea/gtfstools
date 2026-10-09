# Filter GTFS object by date

Filters a GTFS object by the services that run on the given dates,
keeping (or dropping) the relevant entries in each file.

## Usage

``` r
filter_by_date(gtfs, date, keep = TRUE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- date:

  A `Date` vector (including `IDate`) or a character vector of dates in
  the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. The dates used to filter
  the data.

- keep:

  A logical. Whether the entries related to the services that run on the
  specified dates should be kept or dropped (defaults to `TRUE`, which
  keeps the entries).

## Value

The GTFS object passed to the `gtfs` parameter, after the filtering
process.

## Details

The services that run on at least one of the given dates are kept (or
dropped) as a whole: their `calendar` and `calendar_dates` entries are
not trimmed to the given dates, so they may still run on other dates.

A service runs on a date if its `calendar` entry spans the date and
flags its weekday, unless the date is removed from it in
`calendar_dates` (`exception_type` 2), or if the date is added to it in
`calendar_dates` (`exception_type` 1). An addition wins over a removal
on the same date. Either table may be missing. If both are missing, the
GTFS object is returned unchanged, with a warning.

## See also

[`filter_by_weekday()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_weekday.md),
[`get_calendar_overlap()`](https://ipea.github.io/gtfstools/dev/reference/get_calendar_overlap.md)

Other filtering functions:
[`filter_by_agency_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_agency_id.md),
[`filter_by_route_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_id.md),
[`filter_by_route_type()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_type.md),
[`filter_by_service_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_service_id.md),
[`filter_by_shape_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_shape_id.md),
[`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md),
[`filter_by_stop_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_stop_id.md),
[`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md),
[`filter_by_trip_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_trip_id.md),
[`filter_by_weekday()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_weekday.md)

## Examples

``` r
data_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# on 2006-07-03 (a monday) the weekday service "WD" is replaced by the
# weekend service "WE", according to the calendar_dates table
gtfs$calendar_dates
#>    service_id       date exception_type
#>        <char>     <Date>          <int>
#> 1:         WD 2006-07-03              2
#> 2:         WE 2006-07-03              1
#> 3:         WD 2006-07-04              2
#> 4:         WE 2006-07-04              1

smaller_gtfs <- filter_by_date(gtfs, "2006-07-03")
smaller_gtfs$calendar
#>    service_id monday tuesday wednesday thursday friday saturday sunday
#>        <char>  <int>   <int>     <int>    <int>  <int>    <int>  <int>
#> 1:         WE      0       0         0        0      0        1      1
#>    start_date   end_date
#>        <Date>     <Date>
#> 1: 2006-07-01 2006-07-31

# dates may also be given as Date objects. drops the services that run on
# 2006-07-05 (a wednesday)
smaller_gtfs <- filter_by_date(gtfs, as.Date("2006-07-05"), keep = FALSE)
smaller_gtfs$calendar
#>    service_id monday tuesday wednesday thursday friday saturday sunday
#>        <char>  <int>   <int>     <int>    <int>  <int>    <int>  <int>
#> 1:         WE      0       0         0        0      0        1      1
#>    start_date   end_date
#>        <Date>     <Date>
#> 1: 2006-07-01 2006-07-31
```
