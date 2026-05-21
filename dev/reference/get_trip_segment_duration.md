# Get trip segments' duration

Returns the duration of segments between stops of each specified
`trip_id`.

## Usage

``` r
get_trip_segment_duration(
  gtfs,
  trip_id = NULL,
  unit = "min",
  sort_sequence = FALSE
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A string vector including the `trip_id`s to have their segments'
  duration calculated. If `NULL` (the default) the function calculates
  the segments' duration of every `trip_id` in the GTFS.

- unit:

  A string representing the time unit in which the duration is desired.
  One of `"s"` (seconds), `"min"` (minutes, the default), `"h"` (hours)
  or `"d"` (days).

- sort_sequence:

  A logical specifying whether to sort timetables by `stop_sequence`.
  Defaults to `FALSE`, otherwise spec-compliant feeds, in which
  timetables points are already ordered by `stop_sequence`, would be
  penalized through longer processing times. Durations calculated from
  unordered timetables do not correctly depict the real life segment
  durations.

## Value

A `data.table` containing the segments' duration of each specified trip.

## Details

A trip segment is defined as the path between two subsequent stops in
the same trip. The duration of a segment is defined as the time
difference between its arrival time and its departure time, as specified
in the `stop_times` file.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

trip_segment_dur <- get_trip_segment_duration(gtfs)
head(trip_segment_dur)
#>       trip_id segment duration
#>        <char>   <int>    <num>
#> 1: CPTM L07-0       1        8
#> 2: CPTM L07-0       2        8
#> 3: CPTM L07-0       3        8
#> 4: CPTM L07-0       4        8
#> 5: CPTM L07-0       5        8
#> 6: CPTM L07-0       6        8

# use the trip_id argument to control which trips are analyzed
trip_segment_dur <- get_trip_segment_duration(gtfs, trip_id = "CPTM L07-0")
trip_segment_dur
#>        trip_id segment duration
#>         <char>   <int>    <num>
#>  1: CPTM L07-0       1        8
#>  2: CPTM L07-0       2        8
#>  3: CPTM L07-0       3        8
#>  4: CPTM L07-0       4        8
#>  5: CPTM L07-0       5        8
#>  6: CPTM L07-0       6        8
#>  7: CPTM L07-0       7        8
#>  8: CPTM L07-0       8        8
#>  9: CPTM L07-0       9        8
#> 10: CPTM L07-0      10        8
#> 11: CPTM L07-0      11        8
#> 12: CPTM L07-0      12        8
#> 13: CPTM L07-0      13        8
#> 14: CPTM L07-0      14        8
#> 15: CPTM L07-0      15        8
#> 16: CPTM L07-0      16        8
#> 17: CPTM L07-0      17        8

# use the unit argument to control in which unit the durations are calculated
trip_segment_dur <- get_trip_segment_duration(gtfs, "CPTM L07-0", unit = "s")
trip_segment_dur
#>        trip_id segment duration
#>         <char>   <int>    <int>
#>  1: CPTM L07-0       1      480
#>  2: CPTM L07-0       2      480
#>  3: CPTM L07-0       3      480
#>  4: CPTM L07-0       4      480
#>  5: CPTM L07-0       5      480
#>  6: CPTM L07-0       6      480
#>  7: CPTM L07-0       7      480
#>  8: CPTM L07-0       8      480
#>  9: CPTM L07-0       9      480
#> 10: CPTM L07-0      10      480
#> 11: CPTM L07-0      11      480
#> 12: CPTM L07-0      12      480
#> 13: CPTM L07-0      13      480
#> 14: CPTM L07-0      14      480
#> 15: CPTM L07-0      15      480
#> 16: CPTM L07-0      16      480
#> 17: CPTM L07-0      17      480
```
