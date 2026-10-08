# Set route frequency

Sets the headway of each specified `route_id` within a given time of
day, by replacing its trips in that time of day with a single
frequency-based trip, described in the `frequencies` table.

## Usage

``` r
set_route_frequency(gtfs, route_id, headway, from, to)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- route_id:

  A character vector including the `route_id`s to have their frequency
  set.

- headway:

  A number. The headway to be set, in minutes. It is rounded to whole
  seconds and applies to every `route_id` (call the function once per
  route to set different headways).

- from:

  A string. The starting point of the time of day, in the "HH:MM:SS"
  format.

- to:

  A string. The ending point of the time of day, in the "HH:MM:SS"
  format. Must be later than `from`.

## Value

A GTFS object with updated `frequencies`, `trips` and `stop_times`
tables (and `transfers`, when present). If the given GTFS object has no
`frequencies` table, one is created.

## Details

The departures of the routes are grouped as in
[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md):
by `route_id`, `service_id` and `direction_id` (if present in `trips`).
The function changes existing service, it does not create it, so groups
with no departure within the time of day are not modified. In each of
the other groups:

- the trips that depart within the time of day are replaced by a single
  template trip: among the trips of the stop pattern (as identified by
  [`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_times_patterns.md))
  with the most departures within the time of day, the one that departs
  first. Its travel times apply to all the new departures. The trips of
  other patterns that depart within the time of day are removed
  (frequency-based ones lose their `frequencies` entries within the time
  of day, see below);

- a `frequencies` entry is added for the template, from `from` to `to`,
  with `headway_secs` set to `headway` and `exact_times = 0`
  (frequency-based service). A scheduled template thus becomes a
  frequency-based trip, and the `transfers` entries that refer to it now
  apply to all of its departures;

- the existing `frequencies` entries of the group's trips are clipped to
  the time of day, keeping the departures outside it exactly as before
  (when converted with
  [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
  with `strategy = "exact"`). Trips left without any departure are
  removed from `trips`, `stop_times` and `transfers`.

As in
[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md),
a departure is within the time of day when it happens at or after `from`
and before `to`, so
[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md)
reports the new headway (exactly, when the length of the time of day is
a multiple of `headway`). Departures after midnight are listed with
times greater than "24:00:00", so a time of day such as
"24:00:00"-"26:00:00" should be used for them. Scheduled trips that
depart before `from` are not changed, even if they run within the time
of day. Groups whose trips within the time of day have no departure time
in `stop_times` can't have a template, and are left unchanged with a
warning. Removed trips may leave unused entries in other tables, such as
`shapes` and `calendar`, which can be removed with
[`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md).

The `stop_times` table requires the `stop_id` and `stop_sequence`
fields. Existing `_secs` columns in `frequencies` (e.g. created with
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md))
are updated.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

get_route_frequency(
  gtfs,
  route_id = "CPTM L07",
  from = "07:00:00",
  to = "09:00:00"
)
#> Key: <route_id, direction_id, service_id>
#>    route_id direction_id service_id departures mean_headway
#>      <char>        <int>     <char>      <int>        <num>
#> 1: CPTM L07            0        USD         20            6
#> 2: CPTM L07            1        USD         20            6

# sets a 10 minutes headway from 7 to 9 am
new_gtfs <- set_route_frequency(
  gtfs,
  route_id = "CPTM L07",
  headway = 10,
  from = "07:00:00",
  to = "09:00:00"
)
get_route_frequency(
  new_gtfs,
  route_id = "CPTM L07",
  from = "07:00:00",
  to = "09:00:00"
)
#> Key: <route_id, direction_id, service_id>
#>    route_id direction_id service_id departures mean_headway
#>      <char>        <int>     <char>      <int>        <num>
#> 1: CPTM L07            0        USD         12           10
#> 2: CPTM L07            1        USD         12           10

# use frequencies_to_stop_times() to get the scheduled trips
new_gtfs <- frequencies_to_stop_times(new_gtfs)
```
