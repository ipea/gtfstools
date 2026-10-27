# Get trip duration

Returns the duration of each specified `trip_id`.

## Usage

``` r
get_trip_duration(gtfs, trip_id = NULL, unit = "min", from = NULL, to = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md).

- trip_id:

  A string vector including the `trip_id`s to have their duration
  calculated. If `NULL` (the default) the function calculates the
  duration of every `trip_id` in the GTFS.

- unit:

  A string representing the time unit in which the duration is desired.
  One of `"s"` (seconds), `"min"` (minutes, the default), `"h"` (hours)
  or `"d"` (days).

- from:

  A string, in the "HH:MM:SS" format. Only trips that depart from their
  first stop at or after `from` are included. If `NULL` (the default),
  there is no lower limit.

- to:

  A string, in the "HH:MM:SS" format. Only trips that depart from their
  first stop at or before `to` are included. If `NULL` (the default),
  there is no upper limit.

## Value

A `data.table` containing the duration of each specified trip.

## Details

The duration of a trip is defined as the time difference between its
last arrival time and its first departure time, as specified in the
`stop_times` table. Trips without any arrival time or without any
departure time get a `NA` duration, with a warning.

Existing `_secs` columns in `stop_times` (e.g. created with
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md))
are used as-is, not recalculated from the time strings.

`from` and `to` are compared with the departure time of the first stop
of each trip, in `stop_sequence` order (which must then be an integer
column). The time is read as the durations are: from
`departure_time_secs`, if present, or else from `departure_time`, so use
times past `"24:00:00"` for departures after midnight. For trips listed
in `frequencies`, these are template times, not the times of each
departure. Trips whose first departure is blank are never included when
`from` or `to` is given.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

trip_duration <- get_trip_duration(gtfs)
head(trip_duration)
#> Key: <trip_id>
#>      trip_id duration
#>       <char>    <num>
#> 1: 2002-10-0       48
#> 2: 2105-10-0      108
#> 3: 2105-10-1      111
#> 4: 2161-10-0       94
#> 5: 2161-10-1       93
#> 6: 4491-10-0       69

trip_ids <- c("CPTM L07-0", "2002-10-0")
trip_duration <- get_trip_duration(gtfs, trip_id = trip_ids)
trip_duration
#> Key: <trip_id>
#>       trip_id duration
#>        <char>    <num>
#> 1:  2002-10-0       48
#> 2: CPTM L07-0      136

trip_duration <- get_trip_duration(gtfs, trip_id = trip_ids, unit = "h")
trip_duration
#> Key: <trip_id>
#>       trip_id duration
#>        <char>    <num>
#> 1:  2002-10-0 0.800000
#> 2: CPTM L07-0 2.266667
```
