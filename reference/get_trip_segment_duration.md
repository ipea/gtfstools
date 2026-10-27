# Get trip segments' duration

Returns the duration of segments between stops of each specified
`trip_id`.

## Usage

``` r
get_trip_segment_duration(
  gtfs,
  trip_id = NULL,
  unit = "min",
  sort_sequence,
  from = NULL,
  to = NULL
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md).

- trip_id:

  A string vector including the `trip_id`s to have their segments'
  duration calculated. If `NULL` (the default) the function calculates
  the segments' duration of every `trip_id` in the GTFS.

- unit:

  A string representing the time unit in which the duration is desired.
  One of `"s"` (seconds), `"min"` (minutes, the default), `"h"` (hours)
  or `"d"` (days).

- sort_sequence:

  Deprecated; do not supply. Timetables are now always sorted by
  `stop_sequence`. Passing `TRUE` raises a warning, and passing `FALSE`
  raises an error.

- from:

  A string, in the "HH:MM:SS" format. Only segments that depart from
  their first stop at or after `from` are included. If `NULL` (the
  default), there is no lower limit.

- to:

  A string, in the "HH:MM:SS" format. Only segments that depart from
  their first stop at or before `to` are included. If `NULL` (the
  default), there is no upper limit.

## Value

A `data.table` containing the segments' duration of each specified trip.

## Details

A trip segment is defined as the path between two subsequent stops in
the same trip. The duration of a segment is defined as the time
difference between its arrival time and its departure time, as specified
in the `stop_times` file.

Existing `_secs` columns in `stop_times` (e.g. created with
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md))
are used as-is, not recalculated from the time strings.

`from` and `to` are compared with the departure time of the first stop
of each segment, read as the durations are (from `departure_time_secs`,
if present), so use times past `"24:00:00"` for departures after
midnight. For trips listed in `frequencies`, these are template times,
not the times of each departure. Segments whose departure is blank are
never included when `from` or `to` is given.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

trip_segment_dur <- get_trip_segment_duration(gtfs)
head(trip_segment_dur)
#>      trip_id segment duration
#>       <char>   <int>    <num>
#> 1: 2002-10-0       1 2.166667
#> 2: 2002-10-0       2 2.166667
#> 3: 2002-10-0       3 2.166667
#> 4: 2002-10-0       4 2.166667
#> 5: 2002-10-0       5 2.166667
#> 6: 2002-10-0       6 2.166667

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

# use the from and to arguments to keep only the segments that depart
# within a time of day
trip_segment_dur <- get_trip_segment_duration(
  gtfs,
  from = "07:00:00",
  to = "09:00:00"
)
head(trip_segment_dur)
#>      trip_id segment duration
#>       <char>   <int>    <num>
#> 1: 2002-10-0       1 2.166667
#> 2: 2161-10-0       1 1.733333
#> 3: 4491-10-0       1 1.600000
#> 4: 4491-10-0       2 1.600000
#> 5: 4491-10-0       3 1.600000
#> 6: 4491-10-0       4 1.600000
```
