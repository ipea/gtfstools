# Get active services

Returns the services that are active on the given dates.

## Usage

``` r
get_active_services(gtfs, date)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- date:

  A `Date` vector (including `IDate`) or a character vector of dates in
  the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats.

## Value

A `data.table` with the columns `date` (of class `Date`) and
`service_id`, with one row for each service active on each of the given
dates, sorted by `date` and then by `service_id` (in the C locale, so
uppercase letters come before lowercase ones). Dates on which no service
is active have no rows. `service_id` is never `NA`.

## Details

A service is active on a date if its `calendar` entry spans the date and
flags its weekday, unless the date is removed from it in
`calendar_dates` (`exception_type` 2), or if the date is added to it in
`calendar_dates` (`exception_type` 1). An addition wins over a removal
on the same date, and either table may be missing. If the `trips` table
has a `service_id` field, services not used by any trip are not
returned, as in
[`get_dates()`](https://ipea.github.io/gtfstools/dev/reference/get_dates.md).
If no service is active, an empty table is returned without a warning.

## See also

[`get_dates()`](https://ipea.github.io/gtfstools/dev/reference/get_dates.md),
[`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md)

## Examples

``` r
data_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

get_active_services(gtfs, "20060703")
#>          date service_id
#>        <Date>     <char>
#> 1: 2006-07-03         WE

# several dates, also as Date objects. only the weekend service "WE" is
# returned, because the weekday service "WD" is not used by any trip
get_active_services(gtfs, as.Date(c("2006-07-01", "2006-07-05")))
#>          date service_id
#>        <Date>     <char>
#> 1: 2006-07-01         WE
```
