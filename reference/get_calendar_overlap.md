# Get calendar overlap

Returns the periods in which all the given GTFS feeds have service, or
the number of trips each feed runs on each of its service days. Either
result can also be plotted. Useful to pick a date on which several feeds
can be analysed together (e.g. when routing on the networks of different
agencies).

## Usage

``` r
get_calendar_overlap(gtfs, resolution = "daily", plot = FALSE)
```

## Arguments

- gtfs:

  Either a character vector with the paths to GTFS `.zip` files or a
  list of GTFS objects, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md)
  (a single GTFS object must be wrapped in a list).

- resolution:

  A string. `"daily"` (the default) returns the number of trips of each
  feed on each of its service days, and `"periods"` the periods in which
  all feeds have service.

- plot:

  A logical. Whether to return a plot of the result instead of the
  result itself (requires the `{ggplot2}` package). Defaults to `FALSE`.

## Value

If `plot = FALSE` and `resolution = "periods"`, a `data.table` with one
row per period of consecutive days on which all feeds have service, and
the columns `start_date`, `end_date` (both included in the period) and
`n_days`. It has no rows if there is no such day.

If `plot = FALSE` and `resolution = "daily"`, a `data.table` with one
row per feed and service day, and the columns `feed`, `date`, `n_trips`
(the number of trips that run on the day) and `overlap` (whether all
feeds have service on the day).

If `plot = TRUE`, a `ggplot` object with dates on the x axis and one row
per feed (top to bottom in the given order). With
`resolution = "periods"`, it shows a bar spanning each feed's service
days. With `resolution = "daily"`, it shows a box plot of when each
feed's trips run: the box spans the days by which a quarter and three
quarters of its trips have run, with a line on the day by which half
have, and the whiskers reach its first and last service days. In both,
the overlap periods are shaded.

## Details

A feed has service on a day if at least one of its services runs on it,
according to `calendar` and `calendar_dates` (either may be missing). A
service both added and removed on a day in `calendar_dates` runs on it.
If `trips` has a `service_id` field, services not used by any trip are
ignored. `feed_info` dates are not used. A warning is raised for feeds
without any service day, and a message when two or more feeds have no
day with service in all of them.

In `n_trips`, a trip listed in `frequencies` counts once per departure,
as in
[`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/reference/frequencies_to_stop_times.md)
with `strategy = "exact"`, except that the departures of overlapping
entries of the same trip are added up (identical entries count once). A
trip with an invalid `frequencies` entry counts once, with a warning.
Departures after midnight (times past `"24:00:00"`) count on the
previous day. Without a `trips` table with a `service_id` field,
`n_trips` is `NA` and the daily plot shows no box for the feed.

Feeds are named after their file names (without the extension) or list
names; unnamed feeds are named `"feed_1"`, `"feed_2"`, etc., and
duplicated names are made unique. Overlap periods are shaded only when
two or more feeds are given.

## See also

[`merge_gtfs()`](https://ipea.github.io/gtfstools/reference/merge_gtfs.md),
[`filter_by_service_id()`](https://ipea.github.io/gtfstools/reference/filter_by_service_id.md)

## Examples

``` r
spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")

# feeds may be given as paths to their .zip files
daily_trips <- get_calendar_overlap(c(spo_path, poa_path))
head(daily_trips)
#>        feed       date n_trips overlap
#>      <char>     <Date>   <int>  <lgcl>
#> 1: spo_gtfs 2008-01-01    7948   FALSE
#> 2: spo_gtfs 2008-01-02    7948   FALSE
#> 3: spo_gtfs 2008-01-03    7948   FALSE
#> 4: spo_gtfs 2008-01-04    7948   FALSE
#> 5: spo_gtfs 2008-01-05    7945   FALSE
#> 6: spo_gtfs 2008-01-06    7945   FALSE

# or as a list of GTFS objects, whose names are used as feed names
feeds <- list(spo = read_gtfs(spo_path), poa = read_gtfs(poa_path))
get_calendar_overlap(feeds, resolution = "periods")
#>    start_date   end_date n_days
#>        <Date>     <Date>  <int>
#> 1: 2019-01-18 2019-04-18     91

if (requireNamespace("ggplot2", quietly = TRUE)) {
  get_calendar_overlap(feeds, plot = TRUE)
}

```
