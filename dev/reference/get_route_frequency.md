# Get route frequency

Returns the number of departures and the mean headway of each specified
`route_id` within a given time of day, by `service_id` (and by
`direction_id`, if the field is present in the `trips` table).

## Usage

``` r
get_route_frequency(gtfs, route_id = NULL, from, to)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- route_id:

  A character vector including the `route_id`s to have their frequencies
  calculated. If `NULL` (the default), the function calculates the
  frequency of every `route_id` in the GTFS.

- from:

  A string. The starting point of the time of day, in the "HH:MM:SS"
  format.

- to:

  A string. The ending point of the time of day, in the "HH:MM:SS"
  format. Must be later than `from`.

## Value

A `data.table` with the columns `route_id`, `direction_id` (only if
present in the `trips` table), `service_id`, `departures` (the number of
departures within the time of day, including each departure generated
from the `frequencies` table) and `mean_headway` (the mean headway
within the time of day, in minutes). Routes with no departures within
the time of day are not included.

## Details

The function counts trips, not stop visits: each trip is counted once,
at its departure time, however many stops it visits within the time of
day. Its results are therefore not comparable to those of functions that
count the departures from each stop of a route, such as
`tidytransit::get_route_frequency()`.

The departure time of a trip is the earliest departure time listed for
it in `stop_times` (blank times are ignored). Trips listed in the
`frequencies` table depart every `headway_secs` from `start_time` until
(but not including) `end_time`, as in
[`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md),
so their `stop_times` entries, which are just templates, are not used
(and these trips are counted even if they are not listed in
`stop_times`). Trips not listed in `frequencies` use their `stop_times`
departure times, and trips without any departure time are ignored. An
error is raised if the `frequencies` table has invalid entries for the
specified routes.

A departure is counted when it happens at or after `from` and before
`to`, so that consecutive time windows (e.g. "06:00:00"-"07:00:00" and
"07:00:00"-"08:00:00") don't count the same departure twice. Please note
that this differs from
[`filter_by_time_of_day()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_time_of_day.md),
which keeps entries whose times are equal to `to`. Departures after
midnight are listed with times greater than "24:00:00" and belong to the
previous service day, so a time of day such as "24:00:00"-"26:00:00"
should be used to account for them.

The mean headway is the length of the time of day divided by the number
of departures. It is an average over the whole time of day, so it is
larger than the actual headway when service starts or ends within it.
When the `trips` table does not have a `direction_id` field, the
departures of both directions are pooled together. Trips with an `NA`
`direction_id` are grouped together.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

route_frequency <- get_route_frequency(
  gtfs,
  from = "07:00:00",
  to = "09:00:00"
)
head(route_frequency)
#> Key: <route_id, direction_id, service_id>
#>    route_id direction_id service_id departures mean_headway
#>      <char>        <int>     <char>      <int>        <num>
#> 1:  2002-10            0        USD         20      6.00000
#> 2:  2105-10            0        USD          7     17.14286
#> 3:  2105-10            1        USD          9     13.33333
#> 4:  2161-10            0        USD          9     13.33333
#> 5:  2161-10            1        USD         10     12.00000
#> 6:  4491-10            0        USD          7     17.14286

route_ids <- c("CPTM L07", "2002-10")
route_frequency <- get_route_frequency(
  gtfs,
  route_id = route_ids,
  from = "07:00:00",
  to = "09:00:00"
)
route_frequency
#> Key: <route_id, direction_id, service_id>
#>    route_id direction_id service_id departures mean_headway
#>      <char>        <int>     <char>      <int>        <num>
#> 1:  2002-10            0        USD         20            6
#> 2: CPTM L07            0        USD         20            6
#> 3: CPTM L07            1        USD         20            6
```
