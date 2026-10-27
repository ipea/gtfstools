# Convert stop times to frequencies

Converts scheduled trips, described only in `stop_times`, into
frequency-based trips, described in `frequencies`. Trips that follow the
same route and sequence of stops are summarised, in each hour of the
day, by a single template trip and the headway between their departures.
This is a lossy approximation of the original schedule.

## Usage

``` r
stop_times_to_frequencies(gtfs, trip_id = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to be converted. If `NULL`
  (the default), the function converts all trips listed in `stop_times`
  that are not already listed in `frequencies`.

## Value

A GTFS object with updated `frequencies`, `stop_times` and `trips`
tables (and `transfers`, when present). If the given GTFS object has no
`frequencies` table, one is created.

## Details

Trips are grouped by `route_id`, `service_id`, `direction_id` and
`shape_id` (the last two only if present in `trips`) and by their
sequence of stops, as identified by
[`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/reference/get_stop_times_patterns.md).
Each group is split into one-hour slots of the clock, from `HH:00:00`
(included) to the next `HH:00:00` (excluded), by the earliest
`departure_time` of each trip in `stop_times`, regardless of
`stop_sequence` (so times after midnight written as `"00:30:00"` instead
of `"24:30:00"` misplace the trip). Slots after midnight are kept as
such (e.g. `"25:00:00"` to `"26:00:00"`).

In each slot with `n` trips, the trip with the earliest departure (ties
broken by `trip_id`) becomes the template and keeps its `trip_id` and
its `trips` and `stop_times` entries. A `frequencies` entry is added for
it, from the start to the end of the slot, with
`headway_secs = ceiling(3600 / n)` and `exact_times = 0`. The other
trips are removed from `trips`, `stop_times` and `transfers`;
`transfers` entries of the template now apply to all of its departures.
Other tables that may refer to trips, such as `attributions` and
`translations`, are not changed.

Slots with a single trip are also converted. Only the trips in `trip_id`
are grouped and converted; other trips are never removed, even if they
share a group and a slot with converted ones. Trips already listed in
`frequencies` (with a warning, if listed in `trip_id`), trips not listed
in `trips` and trips without any `departure_time` are left unchanged.

Converting the result back with
[`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/reference/frequencies_to_stop_times.md)
yields the same number of trips in each slot with at most 60 trips
(approximately the same otherwise), evenly spaced from the start of the
slot.

Existing `_secs` columns in `stop_times` and `frequencies` (e.g. created
with
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md))
are used as-is and filled in for the new `frequencies` entries.

## Examples

``` r
library(dplyr)

data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# converts all trips
converted_gtfs <- stop_times_to_frequencies(gtfs)
nrow(gtfs$trips)
#> [1] 348
nrow(converted_gtfs$trips)
#> [1] 340
head(converted_gtfs$frequencies)
#>      trip_id start_time end_time headway_secs exact_times
#>       <char>     <char>   <char>        <int>       <int>
#> 1: 143765725   05:00:00 06:00:00         3600           0
#> 2: 143765729   06:00:00 07:00:00         3600           0
#> 3: 143765727   10:00:00 11:00:00         3600           0
#> 4: 143765726   14:00:00 15:00:00         3600           0
#> 5: 143765724   16:00:00 17:00:00         3600           0
#> 6: 143765723   17:00:00 18:00:00         3600           0

# converts only the trips of one route
route_trips <- gtfs$trips |>
  filter(route_id == gtfs$trips$route_id[1]) |>
  pull(trip_id)
converted_gtfs <- stop_times_to_frequencies(gtfs, route_trips)

# converting back yields evenly spaced scheduled trips
back_gtfs <- frequencies_to_stop_times(converted_gtfs)
```
