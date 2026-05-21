# Get trip duration

Returns the duration of each specified `trip_id`.

## Usage

``` r
get_trip_duration(gtfs, trip_id = NULL, unit = "min")
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A string vector including the `trip_id`s to have their duration
  calculated. If `NULL` (the default) the function calculates the
  duration of every `trip_id` in the GTFS.

- unit:

  A string representing the time unit in which the duration is desired.
  One of `"s"` (seconds), `"min"` (minutes, the default), `"h"` (hours)
  or `"d"` (days).

## Value

A `data.table` containing the duration of each specified trip.

## Details

The duration of a trip is defined as the time difference between its
last arrival time and its first departure time, as specified in the
`stop_times` table.

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
