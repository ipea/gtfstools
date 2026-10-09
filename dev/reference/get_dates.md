# Get service dates

Returns the dates on which the GTFS object has service.

## Usage

``` r
get_dates(gtfs, as_date = TRUE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- as_date:

  A logical. Whether to return the dates as a `Date` vector (`TRUE`, the
  default) or as a character vector in the `"YYYYMMDD"` format used by
  GTFS (`FALSE`).

## Value

A sorted vector of unique dates, either of class `Date` or a character
vector, depending on `as_date`. It is empty, without a warning, if the
GTFS object has no service date.

## Details

The GTFS object has service on a date if at least one of its services
runs on it. A service runs on the dates between the `start_date` and
`end_date` of its `calendar` entry whose weekday is flagged, minus the
dates removed from it in `calendar_dates` (`exception_type` 2), plus the
dates added to it (`exception_type` 1). Either table may be missing. If
the `trips` table has a `service_id` field, services not used by any
trip are ignored, so each returned date keeps at least one trip when
passed to
[`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md).
`feed_info` dates are not used.

## See also

[`get_calendar_overlap()`](https://ipea.github.io/gtfstools/dev/reference/get_calendar_overlap.md),
[`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md)

## Examples

``` r
data_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# the calendar covers all of July 2006, but only weekends (plus 2006-07-03
# and 2006-07-04, added by calendar_dates) are returned, because the
# weekday service "WD" is not used by any trip
get_dates(gtfs)
#>  [1] "2006-07-01" "2006-07-02" "2006-07-03" "2006-07-04" "2006-07-08"
#>  [6] "2006-07-09" "2006-07-15" "2006-07-16" "2006-07-22" "2006-07-23"
#> [11] "2006-07-29" "2006-07-30"

# dates may also be returned in the "YYYYMMDD" format used by GTFS
get_dates(gtfs, as_date = FALSE)
#>  [1] "20060701" "20060702" "20060703" "20060704" "20060708" "20060709"
#>  [7] "20060715" "20060716" "20060722" "20060723" "20060729" "20060730"
```
