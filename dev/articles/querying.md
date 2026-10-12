# Querying GTFS feeds

GTFS feeds hold a lot of information about transit services, but much of
it is not readily available in their tables. How often does a route run
during the morning peak? How long, and how fast, are its trips?
**gtfstools** includes many `get_*()` functions that extract this kind
of information from a feed and return it as a `data.table`. This
vignette will introduce you to some of them:

- [`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md):
  the number of departures and the mean headway of routes within a time
  of day;
- [`get_stop_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_frequency.md):
  the number of departures and the mean headway at stops within a time
  of day;
- [`get_stop_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_timetable.md):
  the timetable of stops on given dates;
- [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md):
  the length of trips;
- [`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md):
  the duration of trips;
- [`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md):
  the average speed of trips;
- [`get_summary()`](https://ipea.github.io/gtfstools/dev/reference/get_summary.md):
  a summary of the whole feed.

The other `get_*()` functions are listed in the [function
reference](https://ipea.github.io/gtfstools/reference/index.html). To
check which dates have service in several feeds at once, see
[`get_calendar_overlap()`](https://ipea.github.io/gtfstools/dev/reference/get_calendar_overlap.md)
and the [Checking the calendar overlap of GTFS
feeds](https://ipea.github.io/gtfstools/dev/articles/calendar_overlap.md)
vignette.

We will start by loading the packages required by this demonstration
into the current **R** session:

``` r

library(gtfstools)
```

## Frequencies and timetables

[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md)
counts the trips of each route that depart within a time of day, by
service (and by direction, when `direction_id` is present in `trips`).
Let’s see how often two routes of São Paulo’s feed run from 7 to 9 am:

``` r

spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(spo_path)

get_route_frequency(
  gtfs,
  route_id = c("CPTM L07", "2002-10"),
  from = "07:00:00",
  to = "09:00:00"
)
#> Key: <route_id, direction_id, service_id>
#>    route_id direction_id service_id departures mean_headway
#>      <char>        <int>     <char>      <int>        <num>
#> 1:  2002-10            0        USD         20            6
#> 2: CPTM L07            0        USD         20            6
#> 3: CPTM L07            1        USD         20            6
```

[`get_stop_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_frequency.md)
does the same for stops, counting each departure from each stop (except
from the last stop of each trip). Use `by_route = TRUE` to count the
departures of each route separately:

``` r

get_stop_frequency(
  gtfs,
  stop_id = c("18848", "18960"),
  from = "07:00:00",
  to = "09:00:00"
)
#> Key: <stop_id, service_id>
#>    stop_id service_id departures mean_headway
#>     <char>     <char>      <int>        <num>
#> 1:   18848        USD        223    0.5381166
#> 2:   18960        USD         75    1.6000000
```

[`get_stop_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_timetable.md)
returns the stop times at the given stops on the given dates, together
with the information of their trips. Let’s see the first departures from
a stop of Berlin’s feed on January 4, 2021
([`get_route_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_route_timetable.md)
does the same for routes):

``` r

ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
ber_gtfs <- read_gtfs(ber_path)

timetable <- get_stop_timetable(
  ber_gtfs,
  stop_id = "100000720101",
  date = "2021-01-04"
)
head(timetable[, .(date, trip_id, route_id, trip_headsign, departure_time)])
#>          date   trip_id route_id               trip_headsign departure_time
#>        <Date>    <char>   <char>                      <char>         <char>
#> 1: 2021-01-04 146389715 1923_700 Dallgow-Döberitz, Havelpark       05:05:00
#> 2: 2021-01-04 143766496   1921_3          Falkensee, Bahnhof       05:19:00
#> 3: 2021-01-04 146388926 1922_700          Falkensee, Bahnhof       05:23:00
#> 4: 2021-01-04 146388330 1921_700          Falkensee, Bahnhof       05:51:00
#> 5: 2021-01-04 146388884 1922_700          Falkensee, Bahnhof       05:58:00
#> 6: 2021-01-04 146389713 1923_700 Dallgow-Döberitz, Havelpark       06:05:00
```

## Trip lengths, durations and speeds

[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
snaps each stop of a trip to the closest point of the trip’s shape, and
measures the trip’s length along the shape, from its first to its last
stop. Use `by = "segment"` to get the length between each pair of
consecutive stops instead:

``` r

trip_ids <- c("CPTM L07-0", "2002-10-0")

# 'unit' argument defaults to "km"
get_trip_length(gtfs, trip_ids)
#>       trip_id   length
#>        <char>    <num>
#> 1:  2002-10-0  6.68867
#> 2: CPTM L07-0 60.58803
```

With `method = "euclidean"`, lengths are measured as straight lines
between stops. The same happens, with a warning, when the feed has no
`shapes` table or its `trips` have no `shape_id`. Trips not linked to a
usable shape get `NA` lengths, with a warning.

[`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md)
returns the time from the first departure to the last arrival of each
trip:

``` r

# 'unit' argument defaults to "min"
get_trip_duration(gtfs, trip_ids)
#> Key: <trip_id>
#>       trip_id duration
#>        <char>    <num>
#> 1:  2002-10-0       48
#> 2: CPTM L07-0      136
```

And
[`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md)
divides the length of each trip by its duration:

``` r

# 'unit' argument defaults to "km/h"
get_trip_speed(gtfs, trip_ids)
#> Key: <trip_id>
#>       trip_id     speed
#>        <char>     <num>
#> 1:  2002-10-0  8.360838
#> 2: CPTM L07-0 26.730015
```

## Summarising a feed

[`get_summary()`](https://ipea.github.io/gtfstools/dev/reference/get_summary.md)
runs a set of diagnostics on a feed, such as the number of routes, trips
and stops, and the distributions of trip speeds, lengths and route
headways. It returns them as a list of `data.table`s and writes an HTML
report with tables and figures, which is opened in the browser by
default in interactive sessions:

``` r

feed_summary <- get_summary(spo_path, open_browser = FALSE)

feed_summary$totals
#>               indicator     value   unit
#>                  <char>     <num> <char>
#>  1:          n_agencies   1.00000   <NA>
#>  2:            n_routes  19.00000   <NA>
#>  3:             n_trips  36.00000   <NA>
#>  4:             n_stops 654.00000   <NA>
#>  5:  total_shape_length 895.92810     km
#>  6:   mean_shape_length  24.88689     km
#>  7:   total_trip_length 891.57769     km
#>  8:    mean_trip_length  24.76605     km
#>  9: total_trip_duration  42.74667      h
#> 10:  mean_trip_duration  71.24444    min
#> 11:     mean_trip_speed  23.46380   km/h
#> 12:  mean_route_headway  24.43757    min
```

**Note:**

The results of these functions are readily available to be further
analyzed, or to be combined with the rest of **gtfstools**’ toolkit. For
more information on how to use other functions made available by the
package, please see the [introductory
vignette](https://ipea.github.io/gtfstools/dev/articles/gtfstools.md)
and the [function
reference](https://ipea.github.io/gtfstools/reference/index.html).
