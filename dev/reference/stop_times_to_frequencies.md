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
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to be converted. If `NULL`
  (the default), the function converts all trips listed in `stop_times`
  that are not already listed in `frequencies`.

## Value

A GTFS object with updated `frequencies`, `stop_times` and `trips`
tables (and `transfers`, when present). If the given GTFS object has no
`frequencies` table, one is created.

## Details

Trips are grouped together when they share the same `route_id`,
`service_id`, `direction_id` and `shape_id` (these last two only when
present in `trips`) and the same sequence of stops (their spatial
pattern, as identified by
[`get_stop_times_patterns()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_times_patterns.md)).
Each group is then split into one-hour slots of the clock, from
`HH:00:00` (included) to the next `HH:00:00` (not included), according
to the first departure time of each trip. Slots after midnight are kept
as such (e.g. from `"25:00:00"` to `"26:00:00"`).

In each slot with `n` trips:

- the trip that departs first (ties broken by `trip_id`) becomes the
  template. It keeps its `trip_id`, its `trips` entry and its
  `stop_times` entries, so travel times may differ from one hour to
  another. As in any frequency-based trip, only its times relative to
  its first departure matter;

- a `frequencies` entry is added for the template, from the start to the
  end of the slot, with `headway_secs = ceiling(3600 / n)` and
  `exact_times = 0` (frequency-based service);

- the other trips are removed from `trips`, `stop_times` and
  `transfers`. Their own departure times, travel times and other `trips`
  fields (e.g. `trip_headsign`, `block_id`) are lost. `transfers`
  entries that refer to the template now apply to all of its departures.
  Other tables that may refer to trips, such as `attributions` and
  `translations`, are not changed.

Slots with a single trip are also converted (with a headway of one
hour), so that every converted trip becomes frequency-based. Only the
trips in `trip_id` are grouped and converted: other trips are never
removed, even if they share a group and a slot with converted ones.
Trips already listed in `frequencies` (with a warning, if listed in
`trip_id`), trips not listed in `trips` and trips without any
`departure_time` are left unchanged.

This conversion is useful for tools that treat frequency-based trips
differently from scheduled ones, such as the `time_window` parameter of
`{r5r}`, which draws departure times within the headways of
frequency-based trips.

Converting the result back with
[`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
yields the same number of trips in each slot, as long as it has at most
60 trips (one departure per minute). Slots with more trips yield
approximately the same number of trips. The departures of the new trips,
however, are evenly spaced from the start of the slot.

Existing `_secs` columns in `stop_times` and `frequencies` (e.g. created
with
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md))
are used as-is, not recalculated from the time strings, and are filled
in for the new `frequencies` entries.

## Examples

``` r
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
route_trips <- gtfs$trips[route_id == gtfs$trips$route_id[1]]$trip_id
converted_gtfs <- stop_times_to_frequencies(gtfs, route_trips)

# converting back yields evenly spaced scheduled trips
back_gtfs <- frequencies_to_stop_times(converted_gtfs)
```
