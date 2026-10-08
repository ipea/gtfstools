# Get calendar overlap

Returns the periods in which all the given GTFS feeds have service, or a
timeline plot of each feed's service days with these periods
highlighted. Useful to pick a date on which several feeds can be
analysed together (e.g. when routing on the networks of different
agencies).

## Usage

``` r
get_calendar_overlap(gtfs, output = "df")
```

## Arguments

- gtfs:

  Either a character vector with the paths to GTFS `.zip` files or a
  list of GTFS objects, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md)
  (a single GTFS object must be wrapped in a list).

- output:

  A string. `"df"` (the default) returns the overlap periods as a
  `data.table`, and `"plot"` a timeline of each feed's service days
  (requires the `{ggplot2}` package).

## Value

If `output = "df"`, a `data.table` with one row per period of
consecutive days on which all feeds have service, and the columns
`start_date`, `end_date` (both included in the period) and `n_days`. It
has no rows if there is no such day. If `output = "plot"`, a `ggplot`
object with one bar per feed (top to bottom in the given order) spanning
its service days, and the overlap periods shaded in the background.

## Details

A feed has service on a day if at least one of its services runs on it.
A service runs on the days between the `start_date` and `end_date` of
its `calendar` entry whose weekday is flagged, minus the days removed
from it in `calendar_dates` (`exception_type` 2), plus the days added to
it (`exception_type` 1). Either table may be missing. If the feed has a
`trips` table with a `service_id` field, services not used by any trip
are ignored. `feed_info` dates are not used. A warning is raised for
feeds without any service day.

Feeds are named after their file names (without the extension) or after
the list names. Unnamed feeds are named after their position
(`"feed_1"`, `"feed_2"`, etc.), and duplicated names are made unique.

## See also

[`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md),
[`filter_by_service_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_service_id.md)

## Examples

``` r
spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")

# feeds may be given as paths to their .zip files
get_calendar_overlap(c(spo_path, poa_path))
#>    start_date   end_date n_days
#>        <Date>     <Date>  <int>
#> 1: 2019-01-18 2019-04-18     91

# or as a list of GTFS objects, whose names are used as feed names
feeds <- list(spo = read_gtfs(spo_path), poa = read_gtfs(poa_path))
get_calendar_overlap(feeds)
#>    start_date   end_date n_days
#>        <Date>     <Date>  <int>
#> 1: 2019-01-18 2019-04-18     91

if (requireNamespace("ggplot2", quietly = TRUE)) {
  get_calendar_overlap(feeds, output = "plot")
}

```
