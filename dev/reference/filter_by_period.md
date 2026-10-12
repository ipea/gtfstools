# Filter GTFS object by period

Filters a GTFS object by the services that run on at least one day of a
period, keeping (or dropping) the relevant entries in each file.

## Usage

``` r
filter_by_period(gtfs, start_date, end_date, keep = TRUE, trim = TRUE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- start_date, end_date:

  A `Date` (including `IDate`) or a string in the `"YYYYMMDD"` or
  `"YYYY-MM-DD"` formats. The first and last days of the period, both
  included. `end_date` must not be earlier than `start_date`.

- keep:

  A logical. Whether the entries related to the services that run in the
  specified period should be kept or dropped (defaults to `TRUE`, which
  keeps the entries).

- trim:

  A logical. Whether the calendars of the kept services should be cut to
  the period (defaults to `TRUE`), so that the GTFS object has no
  service outside it. Ignored when `keep` is `FALSE`.

## Value

The GTFS object passed to the `gtfs` parameter, after the filtering
process.

## Details

The services are selected as when filtering by each day of the period
with
[`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md),
whose details also apply here: the services that run on at least one day
of the period are kept (or dropped).

With `trim = TRUE`, the kept services are then cut to the period: the
`start_date` and `end_date` of their `calendar` entries are clipped to
it (entries left without any day are removed), and the `calendar_dates`
entries outside it are removed. Each service then runs on exactly the
same days within the period as before, and on no day outside it. The
`feed_info` table is not changed. With `trim = FALSE`, the services are
kept as a whole, so they may still run on days outside the period.

The period is first clipped to the dates covered by the `calendar` and
`calendar_dates` tables, on which the services can run, so the days of
the period outside them add no work. The memory used still grows with
the number of days the period shares with each service's calendar.

## See also

[`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md),
[`get_active_services()`](https://ipea.github.io/gtfstools/dev/reference/get_active_services.md),
[`get_dates()`](https://ipea.github.io/gtfstools/dev/reference/get_dates.md)

Other filtering functions:
[`filter_by_agency_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_agency_id.md),
[`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md),
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

gtfs$calendar
#>    service_id monday tuesday wednesday thursday friday saturday sunday
#>        <char>  <int>   <int>     <int>    <int>  <int>    <int>  <int>
#> 1:         WE      0       0         0        0      0        1      1
#> 2:         WD      1       1         1        1      1        0      0
#>    start_date   end_date
#>        <Date>     <Date>
#> 1: 2006-07-01 2006-07-31
#> 2: 2006-07-01 2006-07-31
gtfs$calendar_dates
#>    service_id       date exception_type
#>        <char>     <Date>          <int>
#> 1:         WD 2006-07-03              2
#> 2:         WE 2006-07-03              1
#> 3:         WD 2006-07-04              2
#> 4:         WE 2006-07-04              1

# keeps the services that run in the first week of july 2006, with their
# calendars cut to that week
smaller_gtfs <- filter_by_period(gtfs, "2006-07-01", "2006-07-07")
smaller_gtfs$calendar
#>    service_id monday tuesday wednesday thursday friday saturday sunday
#>        <char>  <int>   <int>     <int>    <int>  <int>    <int>  <int>
#> 1:         WE      0       0         0        0      0        1      1
#> 2:         WD      1       1         1        1      1        0      0
#>    start_date   end_date
#>        <Date>     <Date>
#> 1: 2006-07-01 2006-07-07
#> 2: 2006-07-01 2006-07-07

# keeps the same services, with their whole calendars
smaller_gtfs <- filter_by_period(
  gtfs,
  "2006-07-01",
  "2006-07-07",
  trim = FALSE
)
smaller_gtfs$calendar
#>    service_id monday tuesday wednesday thursday friday saturday sunday
#>        <char>  <int>   <int>     <int>    <int>  <int>    <int>  <int>
#> 1:         WE      0       0         0        0      0        1      1
#> 2:         WD      1       1         1        1      1        0      0
#>    start_date   end_date
#>        <Date>     <Date>
#> 1: 2006-07-01 2006-07-31
#> 2: 2006-07-01 2006-07-31

# dates may also be given as Date objects. drops the services that run in
# the period
smaller_gtfs <- filter_by_period(
  gtfs,
  as.Date("2006-07-03"),
  as.Date("2006-07-04"),
  keep = FALSE
)
smaller_gtfs$calendar
#>    service_id monday tuesday wednesday thursday friday saturday sunday
#>        <char>  <int>   <int>     <int>    <int>  <int>    <int>  <int>
#> 1:         WD      1       1         1        1      1        0      0
#>    start_date   end_date
#>        <Date>     <Date>
#> 1: 2006-07-01 2006-07-31
```
