# Editing GTFS feeds

GTFS feeds describe the transit services of a city or region as they
are. Quite often, however, one wants to analyze how things would be if
they were different: what if a bus route ran more frequently, or if a
rail line were faster? Answering such questions requires editing the
feed, changing its service levels, travel times or the way its schedules
are described, and then feeding the result to routing and accessibility
tools.

**gtfstools** includes several functions to edit GTFS feeds. The editing
functions currently available are:

- [`set_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/set_route_frequency.md):
  sets the headway of routes within a time of day;
- [`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md):
  sets the average speed of trips, or of a segment of them;
- [`stop_times_to_frequencies()`](https://ipea.github.io/gtfstools/dev/reference/stop_times_to_frequencies.md):
  approximates scheduled trips by frequency-based ones;
- [`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md):
  fills blank stop times, assuming a constant speed between stops with
  known times;
- [`set_max_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_max_speed.md):
  caps the speed of trips, slowing down only the parts that are faster
  than a maximum speed;
- [`set_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_dwell_time.md):
  sets how long vehicles stay at stops;
- [`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md):
  converts frequency-based trips into scheduled ones;
- [`merge_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/merge_gtfs.md):
  combines several feeds into a single one;
- [`remove_duplicates()`](https://ipea.github.io/gtfstools/dev/reference/remove_duplicates.md):
  removes duplicated entries from the feed’s tables;
- [`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md):
  removes the ids that the feed doesn’t use, with their entries in every
  table;
- [`fix_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/fix_gtfs.md):
  cleans a feed in one call, removing duplicated entries and unused ids,
  optionally capping the speed of trips and filling blank stop times.

This vignette will introduce you to the first four functions and will
cover their usage in detail. By default, they return an edited copy of
the feed and leave the given GTFS object unchanged.

We will start by loading the packages required by this demonstration
into the current **R** session:

``` r

library(gtfstools)
library(dplyr)
```

## Setting route frequencies

The number of departures of a route is one of the main levers of a
transit network, and one that is frequently changed in scenario
analyses.
[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md)
tells us how many departures each route has within a time of day, and
its mean headway. Let’s see how frequently the route `T2` of Porto
Alegre’s feed runs during the morning peak:

``` r

path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(path)

get_route_frequency(
  gtfs,
  route_id = "T2",
  from = "07:00:00",
  to = "09:00:00"
)
#> Key: <route_id, direction_id, service_id>
#>    route_id direction_id service_id departures mean_headway
#>      <char>        <int>     <char>      <int>        <num>
#> 1:       T2            0       T2@1         17     7.058824
#> 2:       T2            0       T2@2          8    15.000000
#> 3:       T2            0       T2@5          5    24.000000
```

The route runs on three different services (`T2@1` on weekdays, for
example), each with a different headway.
[`set_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/set_route_frequency.md)
sets a single headway, in minutes, to all of them. Let’s say we want the
route to run every 10 minutes from 7 to 9 am:

``` r

new_gtfs <- set_route_frequency(
  gtfs,
  route_id = "T2",
  headway = 10,
  from = "07:00:00",
  to = "09:00:00"
)

get_route_frequency(
  new_gtfs,
  route_id = "T2",
  from = "07:00:00",
  to = "09:00:00"
)
#> Key: <route_id, direction_id, service_id>
#>    route_id direction_id service_id departures mean_headway
#>      <char>        <int>     <char>      <int>        <num>
#> 1:       T2            0       T2@1         12           10
#> 2:       T2            0       T2@2         12           10
#> 3:       T2            0       T2@5         12           10

new_gtfs$frequencies
#> Index: <trip_id>
#>       trip_id start_time end_time headway_secs exact_times
#>        <char>     <char>   <char>        <int>       <int>
#> 1: T2-1@1#702   07:00:00 09:00:00          600           0
#> 2: T2-1@2#701   07:00:00 09:00:00          600           0
#> 3: T2-1@5#701   07:00:00 09:00:00          600           0
```

Under the hood, the function replaces the trips that depart within the
time of day by a single template trip per service (and per direction,
when `direction_id` is present in `trips`), taken from its most common
sequence of stops. The departures of the template are described in the
`frequencies` table. Since this feed had no `frequencies` table, one has
been created. The template keeps its travel times between stops, which
apply to all of the new departures. Departures outside the time of day
are kept as before. Please note that departures after midnight are
listed with times greater than `"24:00:00"`, so a time of day such as
`"24:00:00"`-`"26:00:00"` should be used for them.

The trips removed by the function may leave unused entries in other
tables, such as `shapes` and `calendar`, which can be removed with
[`remove_unused_ids()`](https://ipea.github.io/gtfstools/dev/reference/remove_unused_ids.md).
If your routing software doesn’t support frequency-based trips,
[`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
converts them back into scheduled trips.

## Setting trip speeds

[`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
sets the average speed of trips by changing the `arrival_time` and
`departure_time` columns in the `stop_times` table. Let’s see how that
works using the trip `CPTM L07-0` of São Paulo’s feed. This trip is
described in the `frequencies` table, so its times are just a “template”
that describes how long it takes from one stop to another, relative to
each of its departures.

``` r

path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(path)

get_trip_speed(spo_gtfs, trip_id = "CPTM L07-0")
#> Key: <trip_id>
#>       trip_id    speed
#>        <char>    <num>
#> 1: CPTM L07-0 26.73002

# 'unit' argument defaults to "km/h"
new_speed_gtfs <- set_trip_speed(spo_gtfs, trip_id = "CPTM L07-0", speed = 50)

get_trip_speed(new_speed_gtfs, trip_id = "CPTM L07-0")
#> Key: <trip_id>
#>       trip_id    speed
#>        <char>    <num>
#> 1: CPTM L07-0 50.00388

new_speed_gtfs$stop_times |>
  filter(trip_id == "CPTM L07-0") |>
  select(stop_id, stop_sequence, arrival_time, departure_time)
#> Index: <trip_id>
#>     stop_id stop_sequence arrival_time departure_time
#>      <char>         <int>       <char>         <char>
#>  1:   18940             1     04:00:00       04:00:00
#>  2:   18920             2                            
#>  3:   18919             3                            
#>  4:   18917             4                            
#>  5:   18916             5                            
#>  6:   18965             6                            
#>  7:   18923             7                            
#>  8:   18922             8                            
#>  9: 4114459             9                            
#> 10:   18921            10                            
#> 11:   18924            11                            
#> 12:   18925            12                            
#> 13:   18926            13                            
#> 14:   18971            14                            
#> 15:   18972            15                            
#> 16:   18973            16                            
#> 17:   18974            17                            
#> 18:   18975            18     05:12:42       05:12:42
```

The duration of the trip is set to its length, measured along its shape,
divided by the given speed.
[`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
updates the arrival time at the last stop accordingly and sets the
arrival and departure times at intermediate stops to `""`. To fill in
the expected arrival and departure times of intermediate stops, you use
[`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md),
as we’ll see in a [later section](#interpolating-stop-times).

The
[`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)
function also includes a few other arguments that control which trips
and parts of trips are changed:

- `unit` sets the unit in which the speed is given, either `"km/h"` (the
  default), `"m/s"` or `"mph"`;
- `first_stop` and `last_stop` set the speed of only a segment of the
  trips, between two stops. The times at the stops after the segment are
  shifted by the change in its duration;
- `from` and `to` only change the trips that depart from the segment’s
  first stop between `from` “HH:MM:SS” and `to` “HH:MM:SS” (both
  included);
- `by_reference = TRUE` updates the `stop_times` table by reference,
  thus changing the given GTFS object.

## Converting stop times to frequencies

Some routing engines and other tools treat frequency-based trips
differently from scheduled ones. For example, the `time_window`
parameter of [`{r5r}`](https://ipea.github.io/r5r/) draws departure
times within the headways of frequency-based trips.
[`stop_times_to_frequencies()`](https://ipea.github.io/gtfstools/dev/reference/stop_times_to_frequencies.md)
converts scheduled trips, described only in `stop_times`, into
frequency-based trips, described in `frequencies`. Let’s convert all the
trips of Porto Alegre’s feed:

``` r

converted_gtfs <- stop_times_to_frequencies(gtfs)

nrow(gtfs$trips)
#> [1] 387
nrow(converted_gtfs$trips)
#> [1] 157

# frequencies of route T2 on weekdays, from 6 to 10 am
converted_gtfs$frequencies |>
  filter(
    startsWith(trip_id, "T2-1@1#"),
    start_time >= "06:00:00",
    start_time < "10:00:00"
  )
#>       trip_id start_time end_time headway_secs exact_times
#>        <char>     <char>   <char>        <int>       <int>
#> 1: T2-1@1#610   06:00:00 07:00:00          515           0
#> 2: T2-1@1#702   07:00:00 08:00:00          400           0
#> 3: T2-1@1#800   08:00:00 09:00:00          450           0
#> 4: T2-1@1#910   09:00:00 10:00:00          900           0

# the number of departures of route T2 is kept
get_route_frequency(
  converted_gtfs,
  route_id = "T2",
  from = "07:00:00",
  to = "09:00:00"
)
#> Key: <route_id, direction_id, service_id>
#>    route_id direction_id service_id departures mean_headway
#>      <char>        <int>     <char>      <int>        <num>
#> 1:       T2            0       T2@1         17     7.058824
#> 2:       T2            0       T2@2          8    15.000000
#> 3:       T2            0       T2@5          5    24.000000
```

The trips that share the same route, service, direction, shape and
sequence of stops are grouped together and split into one-hour slots of
the clock, according to their earliest departure time. In each slot, the
trip that departs first becomes a template trip, and a `frequencies`
entry is added for it, from the start to the end of the slot, with a
headway of `ceiling(3600 / n)` seconds, `n` being the number of trips in
the slot (e.g. the 9 trips of route `T2` that depart between 7 and 8 am
on weekdays give a headway of 400 seconds). The other trip ids in the
same template are removed from the `trips.txt` file, but it keeps the
same number of departures.

Please note that this is a lossy approximation of the original schedule:
the exact departure times of the removed trips, their travel times and
other fields in `trips` (e.g. `trip_headsign`) are lost. Converting the
result back with
[`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
yields the same number of trips in each slot (as long as it has at most
60 trips), but their departures are evenly spaced from the start of the
slot. To convert only some trips, pass their ids to the `trip_id`
argument.

## Interpolating stop times

Sometimes, GTFS feeds don’t report the arrival and departure times at
every stop: only the times at the first and last stops of each trip are
required, and the stops in between may be left blank. The stops with
known times are called timepoints. In Porto Alegre’s feed, for example,
only the first and last stops of each trip have times:

``` r

trip <- "T2-1@1#520"

gtfs$stop_times |> 
  filter(trip_id == trip) |> 
  select(stop_id, arrival_time, departure_time) |> 
  head()
#>    stop_id arrival_time departure_time
#>     <char>       <char>         <char>
#> 1:    3609     05:20:00       05:20:00
#> 2:    3608                            
#> 3:    3564                            
#> 4:    6336                            
#> 5:    3633                            
#> 6:    5544
```

[`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md)
fills these blank times, assuming that the vehicle travels between two
consecutive timepoints at a constant speed, with distances measured
along the trip’s shape:

``` r

interpolated_gtfs <- interpolate_stop_times(gtfs, trip_id = trip)

interpolated_gtfs$stop_times |> 
  filter(trip_id == trip) |> 
  select(stop_id, arrival_time, departure_time) |> 
  head()
#>    stop_id arrival_time departure_time
#>     <char>       <char>         <char>
#> 1:    3609     05:20:00       05:20:00
#> 2:    3608     05:20:27       05:20:27
#> 3:    3564     05:22:00       05:22:00
#> 4:    6336     05:24:02       05:24:02
#> 5:    3633     05:25:55       05:25:55
#> 6:    5544     05:26:31       05:26:31
```

Interpolated stops get equal arrival and departure times (i.e. no dwell
time), rounded to the nearest second, and `timepoint = 0` when the
`stop_times` table includes a `timepoint` column. In feeds without
shapes, use `method = "euclidean"` to measure distances as straight
lines between stops instead.

If `trip_id` is not given, the function interpolates the data to give
explicit stop times at every stop of every trip in the feed. Some stops
may be left blank, with a warning: for example, a few trips of Porto
Alegre’s feed list their times after midnight as `"00:xx:xx"`, instead
of `"24:xx:xx"`, so they seem to arrive before they depart and can’t be
interpolated.

**Note:**

All editing functions return a GTFS object readily available to be
manipulated and analyzed using the rest of **gtfstools**’ toolkit, or to
be written to disk with
[`write_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/write_gtfs.md).
For more information on how to use other functions made available by the
package, please see the [introductory
vignette](https://ipea.github.io/gtfstools/dev/articles/gtfstools.md)
and the [function
reference](https://ipea.github.io/gtfstools/reference/index.html).
