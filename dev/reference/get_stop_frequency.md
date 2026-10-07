# Get stop frequency

Returns the number of departures and the mean headway at each specified
`stop_id` within a given time of day, by `service_id`. Optionally, the
departures can also be counted by `route_id` (and by `direction_id`, if
the field is present in the `trips` table).

## Usage

``` r
get_stop_frequency(gtfs, stop_id = NULL, by_route = FALSE, from, to)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- stop_id:

  A character vector including the `stop_id`s to have their frequencies
  calculated. If `NULL` (the default), the function calculates the
  frequency of every `stop_id` in the GTFS.

- by_route:

  A logical. Whether the departures should be counted by `route_id` (and
  by `direction_id`, if present in the `trips` table) at each stop.
  Defaults to `FALSE`, in which case the departures of every route that
  serves a stop are pooled together.

- from:

  A string. The starting point of the time of day, in the "HH:MM:SS"
  format.

- to:

  A string. The ending point of the time of day, in the "HH:MM:SS"
  format. Must be later than `from`.

## Value

A `data.table` with the columns `stop_id`, `route_id` and `direction_id`
(only if `by_route` is `TRUE`, the latter only if present in the `trips`
table), `service_id`, `departures` (the number of departures from the
stop within the time of day, including each departure generated from the
`frequencies` table) and `mean_headway` (the mean headway within the
time of day, in minutes). Stops with no departures within the time of
day are not included.

## Details

The function counts stop departures: each `stop_times` entry with a
departure time is a departure from its stop, except for the entry of the
last stop of each trip (the one with the highest `stop_sequence`), from
which vehicles don't depart. Entries with blank departure times (such as
those of stops that are not timepoints) are not counted, so their times
should be interpolated beforehand to count them. A stop visited twice by
the same trip is counted twice. Its results are therefore not comparable
to those of
[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md),
which counts trips.

The `stop_times` entries of trips listed in the `frequencies` table are
just templates: these trips depart every `headway_secs` from
`start_time` until (but not including) `end_time`, and each of these
departures visits the template's stops with the times shifted
accordingly, as in
[`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md).
Trips without any departure time in `stop_times` don't generate
departures. An error is raised if the `frequencies` table has invalid
entries for the trips that serve the specified stops, even if they don't
have any departure time.

The stops are those listed in `stop_times`, which are never stations.
Use
[`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md)
to get the stops of a station and sum their departures.

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
Trips with an `NA` `direction_id` are grouped together.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

stop_frequency <- get_stop_frequency(
  gtfs,
  from = "07:00:00",
  to = "09:00:00"
)
head(stop_frequency)
#> Key: <stop_id, service_id>
#>      stop_id service_id departures mean_headway
#>       <char>     <char>      <int>        <num>
#> 1: 100014307        USD         10     12.00000
#> 2: 100014308        USD         10     12.00000
#> 3: 100014309        USD          9     13.33333
#> 4: 100014321        USD         11     10.90909
#> 5: 100014331        USD          9     13.33333
#> 6: 100014332        USD          9     13.33333

stop_ids <- c("18848", "18960")
stop_frequency <- get_stop_frequency(
  gtfs,
  stop_id = stop_ids,
  by_route = TRUE,
  from = "07:00:00",
  to = "09:00:00"
)
stop_frequency
#> Key: <stop_id, route_id, direction_id, service_id>
#>    stop_id route_id direction_id service_id departures mean_headway
#>     <char>   <char>        <int>     <char>      <int>        <num>
#> 1:   18848 METRÔ L2            0        USD        105     1.142857
#> 2:   18848 METRÔ L2            1        USD        118     1.016949
#> 3:   18960 CPTM L08            0        USD         24     5.000000
#> 4:   18960 CPTM L08            1        USD         21     5.714286
#> 5:   18960 CPTM L09            0        USD         30     4.000000
```
