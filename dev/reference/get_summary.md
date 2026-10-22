# Get a summary of a GTFS feed

Runs a set of diagnostics on a GTFS feed (optionally restricted to some
dates, routes, modes, agencies and a time of day), writes them to a
report with tables and figures, renders the report to HTML and opens it
in the browser (in interactive sessions). The diagnostics are also
returned as a list of `data.table`s. This function does not validate or
look for quality issues in the GTFS feed. To do that, use
[`validate_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/validate_gtfs.md).

## Usage

``` r
get_summary(
  gtfs,
  date = NULL,
  route_id = NULL,
  mode = NULL,
  agency = NULL,
  from = NULL,
  to = NULL,
  output_dir = NULL,
  open_browser = TRUE,
  by_route_type = FALSE
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md),
  or the path to a GTFS file.

- date:

  A `Date` vector (including `IDate`) or a character vector of dates in
  the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. If given, only the
  services that run on these dates are described. If `NULL` (the
  default), the whole period covered by the feed is described.

- route_id:

  A character vector. If given, only these routes are described. If
  `NULL` (the default), all routes are described.

- mode:

  An integer vector of `route_type`s (see
  [`filter_by_route_type()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_type.md))
  or a character vector of mode names (`"tram"`, `"subway"`, `"rail"`,
  `"bus"`, `"ferry"`, `"cable_tram"`, `"aerial_lift"`, `"funicular"`,
  `"trolleybus"` and `"monorail"`, which correspond to the basic
  `route_type`s). If given, only routes of these modes are described. If
  `NULL` (the default), all modes are described.

- agency:

  A character vector of `agency_id`s. If given, only the services of
  these agencies are described. If `NULL` (the default), all agencies
  are described.

- from, to:

  Strings in the `"HH:MM:SS"` format. If given (both must be), only the
  trips that run within this time of day are described. If `NULL` (the
  default), the whole day is described.

- output_dir:

  A string. The directory in which the report is saved (created if
  needed). If `NULL` (the default), a `gtfstools` directory inside
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html) is used. Existing
  reports in this directory are overwritten.

- open_browser:

  A logical. Whether to open the HTML report in the browser, in
  interactive sessions (defaults to `TRUE`).

- by_route_type:

  A logical. Whether to break down the totals, speeds, distances and
  frequencies by transport mode (`route_type`), in addition to the whole
  selection (defaults to `FALSE`).

## Value

A named list of `data.table`s (invisibly, if the report was opened in
the browser):

- `files`: the tables in the feed (`file`) and their number of rows
  (`n_rows`), before any filtering;

- `agency`: the `agency_id`, `agency_name`, `agency_timezone`,
  `agency_url` and `agency_lang` columns (those present in the feed) of
  the agencies that run the selected trips (all agencies, if the
  selected routes have no `agency_id`);

- `services`: a single row summarising the calendar of the selected
  services, with the columns `start_date` and `end_date` (the first and
  last days with service), `n_days` (the number of days between them,
  both included), `n_service_days` (the number of days with service),
  `n_services` (the number of `service_id`s), `mean_trips_per_day` (over
  the days with service), `busiest_date` and `max_trips_per_day` (the
  day with the most trips and its number of trips) and `feed_start_date`
  and `feed_end_date` (from `feed_info`, `NA` if absent);

- `totals`: the columns `indicator`, `value` and `unit`, with the number
  of agencies, routes, trips and stops, the total and mean length of the
  shapes and of the trips (in km), the total duration of the trips (in
  hours), the mean duration of the trips (in minutes), the mean trip
  speed (in km/h) and the mean route headway (in minutes). The means are
  taken over the shapes and trips whose value is known. If
  `by_route_type = TRUE`, `value` is replaced by one column per mode
  followed by the column `all` (codes of extended `route_type`s, such as
  `"700"`, are non-syntactic names, so they need backticks);

- `speed`, `distance` and `frequency`: summary statistics (`n`, `min`,
  `q25`, `median`, `mean`, `q75`, `max` and `unit`) of the trip speeds
  (in km/h), of the trip lengths (in km) and of the route headways (in
  minutes). `frequency` also has the columns `date`, `from` and `to`,
  with the day and the time of day in which the headways were measured.
  If `by_route_type = TRUE`, these tables start with a `mode` column and
  have one row per mode followed by the row `all`.

The report is saved as `gtfs_summary.md` and `gtfs_summary.html`
(together with its figures) in `output_dir`.

## Details

The report requires the `{ggplot2}`, `{knitr}` and `{rmarkdown}`
packages, and [Pandoc](https://pandoc.org/), which is shipped with
RStudio.

The feed is filtered by agency, mode, route, date and time of day, in
this order. The time-of-day filter keeps the whole trips that run within
it (see
[`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md)
with `full_trips = TRUE`), so the trip speeds and lengths refer to whole
trips.

Trip lengths, durations and speeds are calculated with
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
[`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md)
and
[`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md).
Each trip is counted once, however many days it runs on and however many
departures the `frequencies` table lists for it. Trips with a zero or
negative duration count in the total and mean durations, but have no
speed. The total and mean shape lengths count each shape used by the
selected trips once, and the number of stops counts the stops visited by
the selected trips.

The `services` summary and the calendar chart in the report describe the
whole calendar of the selected services: when `date` is given, the
services that run on these dates are kept as a whole (see
[`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md)),
so they may also cover other days. The number of trips on each day is
calculated as in
[`get_calendar_overlap()`](https://ipea.github.io/gtfstools/dev/reference/get_calendar_overlap.md),
counting each departure listed in `frequencies`.

Route headways are calculated with
[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md),
by route (and by `direction_id`, if the field is present in the `trips`
table), on a single day: the day with the most trips among the given
`date`s, or in the whole feed if `date` is `NULL` (the earliest one, in
case of ties). They are measured within the given time of day or, if
`from` and `to` are `NULL`, from the first to the last departure of that
day, rounded out to whole hours. Trips that start on the previous day
and run after midnight are not counted, and times are in the local time
of each agency.

With `by_route_type = TRUE`, modes are named as in the `mode` argument,
extended `route_type`s by their code, and trips whose `route_type` is
unknown are grouped as `"unknown"`. Modes are ordered by `route_type`,
with `"unknown"` last. Each mode is described as if it were selected
alone (except that the headways of all modes are measured on the same
day and time of day), so stops, shapes and agencies shared by several
modes count in each of them. Only the numbers of routes and trips and
the total trip lengths and durations add up to the `all` column. Modes
whose routes have blank `agency_id`s count all the agencies of the
selection, and trips listed in `stop_times` but not in `trips` only
count in `all`. In the report, the histograms of the modes are overlaid.

## Examples

``` r
if (
  requireNamespace("ggplot2", quietly = TRUE) &&
    requireNamespace("knitr", quietly = TRUE) &&
    requireNamespace("rmarkdown", quietly = TRUE) &&
    rmarkdown::pandoc_available()
) {
  data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

  feed_summary <- get_summary(
    data_path,
    output_dir = tempdir(),
    open_browser = FALSE
  )
  feed_summary$totals

  # \donttest{
  feed_summary <- get_summary(
    data_path,
    mode = "bus",
    from = "07:00:00",
    to = "09:00:00",
    output_dir = tempdir(),
    open_browser = FALSE
  )
  feed_summary$frequency

  feed_summary <- get_summary(
    data_path,
    output_dir = tempdir(),
    open_browser = FALSE,
    by_route_type = TRUE
  )
  feed_summary$totals
  # }
}
#>               indicator     subway      rail       bus       all   unit
#>                  <char>      <num>     <num>     <num>     <num> <char>
#>  1:          n_agencies   1.000000   1.00000   1.00000   1.00000   <NA>
#>  2:            n_routes   6.000000   7.00000   6.00000  19.00000   <NA>
#>  3:             n_trips  12.000000  14.00000  10.00000  36.00000   <NA>
#>  4:             n_stops  88.000000 100.00000 466.00000 654.00000   <NA>
#>  5:  total_shape_length 196.966795 525.64661 173.31469 895.92810     km
#>  6:   mean_shape_length  16.413900  37.54619  17.33147  24.88689     km
#>  7:   total_trip_length 195.942016 524.74754 170.88814 891.57769     km
#>  8:    mean_trip_length  16.328501  37.48197  17.08881  24.76605     km
#>  9: total_trip_duration   7.263333  19.66667  15.81667  42.74667      h
#> 10:  mean_trip_duration  36.316667  84.28571  94.90000  71.24444    min
#> 11:     mean_trip_speed  27.364010  29.06481  10.94215  23.46380   km/h
#> 12:  mean_route_headway   6.283301  10.96129  65.08947  24.43757    min
```
