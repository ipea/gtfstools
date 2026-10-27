# Set a minimum dwell time

Raises the dwell time of each specified `trip_id` at each specified
`stop_id` to at least `min_dwell_time`, i.e. makes vehicles stay at
least that long at the stops, by delaying the `departure_time` at these
stops in `stop_times` and shifting the later times of the trips
accordingly.

## Usage

``` r
set_min_dwell_time(
  gtfs,
  min_dwell_time,
  unit = "s",
  trip_id = NULL,
  stop_id = NULL,
  from = NULL,
  to = NULL,
  route_type = NULL,
  by_reference = FALSE
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- min_dwell_time:

  A non-negative number, the minimum dwell time, in `unit`. It's rounded
  to the nearest whole second.

- unit:

  A string representing the time unit in which `min_dwell_time` is
  given. One of `"s"` (seconds, the default), `"min"` (minutes), `"h"`
  (hours) or `"d"` (days).

- trip_id:

  A character vector including the `trip_id`s to have their dwell times
  raised. If `NULL` (the default), the dwell times of every `trip_id` in
  the GTFS (or of every trip of the given `route_type`s) are raised.

- stop_id:

  A character vector including the `stop_id`s at which the dwell times
  are raised. If `NULL` (the default), the dwell times are raised at
  every `stop_id` in the GTFS.

- from:

  A string, in the "HH:MM:SS" format. Only visits whose arrival time is
  at or after `from` are changed. If `NULL` (the default), there is no
  lower limit.

- to:

  A string, in the "HH:MM:SS" format. Only visits whose arrival time is
  at or before `to` are changed. If `NULL` (the default), there is no
  upper limit.

- route_type:

  An integer vector of `route_type`s (see
  [`filter_by_route_type()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_type.md)).
  If given, only trips of routes of these types are changed; together
  with the other selection arguments, it restricts their selection.
  `route_type`s not listed in `routes` are ignored. If `NULL` (the
  default), trips of any type are changed.

- by_reference:

  Whether to update `stop_times`' `data.table` by reference. Defaults to
  `FALSE`.

## Value

If `by_reference` is set to `FALSE`, returns a GTFS object with the time
columns of its `stop_times` adjusted. Else, returns a GTFS object
invisibly (note that in this case the original GTFS object is altered).

## Details

Visits are selected as in
[`set_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_dwell_time.md).
At each selected visit whose dwell time is shorter than
`min_dwell_time`, the arrival time is kept and the departure time is set
to the arrival time plus `min_dwell_time`.

The first and last visits with both an arrival and a departure time of
each trip are never raised (use
[`set_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_dwell_time.md)
for them). They are found among all the visits of the trip, not only the
selected ones, and the times of the last visit may still be shifted by
an earlier visit.

Negative dwell times (departure earlier than arrival) are raised like
any other shorter dwell time, so a `min_dwell_time` of 0 raises only
these. When they come from times after midnight written as `"00:30:00"`
instead of `"24:30:00"`, the later times of the trip are shifted by
about a day.

Otherwise it works as
[`set_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_dwell_time.md).

## See also

[`set_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/set_dwell_time.md),
[`get_dwell_time()`](https://ipea.github.io/gtfstools/dev/reference/get_dwell_time.md),
[`fix_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/fix_gtfs.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# vehicles stay 0 seconds at the stops of this trip. make them stay at least
# 30 seconds at each intermediate stop
head(get_dwell_time(gtfs, trip_id = "CPTM L07-0"))
#>       trip_id stop_id stop_sequence dwell_time
#>        <char>  <char>         <int>      <num>
#> 1: CPTM L07-0   18940             1          0
#> 2: CPTM L07-0   18920             2          0
#> 3: CPTM L07-0   18919             3          0
#> 4: CPTM L07-0   18917             4          0
#> 5: CPTM L07-0   18916             5          0
#> 6: CPTM L07-0   18965             6          0

new_gtfs <- set_min_dwell_time(gtfs, 30, trip_id = "CPTM L07-0")
head(get_dwell_time(new_gtfs, trip_id = "CPTM L07-0"))
#>       trip_id stop_id stop_sequence dwell_time
#>        <char>  <char>         <int>      <num>
#> 1: CPTM L07-0   18940             1          0
#> 2: CPTM L07-0   18920             2         30
#> 3: CPTM L07-0   18919             3         30
#> 4: CPTM L07-0   18917             4         30
#> 5: CPTM L07-0   18916             5         30
#> 6: CPTM L07-0   18965             6         30
```
