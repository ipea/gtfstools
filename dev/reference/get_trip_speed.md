# Get trip speed

Returns the speed of each specified `trip_id`, based on the geometry
created from either the `shapes` or the `stop_times` file (or both).

## Usage

``` r
get_trip_speed(
  gtfs,
  trip_id = NULL,
  file = "shapes",
  unit = "km/h",
  sort_sequence = FALSE
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to have their speeds
  calculated. If `NULL` (the default), the function calculates the speed
  of every `trip_id` in the GTFS.

- file:

  The file from which geometries should be generated, either `shapes` or
  `stop_times` (geometries are used to calculate the length of a trip).
  Defaults to `shapes`.

- unit:

  A string representing the unit in which the speeds are desired. Either
  `"km/h"` (the default) or `"m/s"`.

- sort_sequence:

  Ultimately passed to
  [`get_trip_length()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_length.md),
  a logical specifying whether to sort shapes and timetables by
  `shape_pt_sequence` and `stop_sequence`, respectively. Speeds
  calculated from trip trajectories generated with unordered sequences
  do not correctly depict the actual trip speeds. Defaults to `FALSE`,
  otherwise spec-compliant feeds, in which shape/timetables points are
  already ordered by `shape_pt_sequence`/`stop_sequence`, would be
  penalized through longer processing times.

## Value

A `data.table` containing the duration of each specified trip and the
file from which geometries were generated.

## Details

Please check
[`get_trip_geometry()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_geometry.md)
documentation to understand how geometry generation differs depending on
the chosen file.

## See also

[`get_trip_geometry()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_geometry.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

trip_speed <- get_trip_speed(gtfs)
head(trip_speed)
#>      trip_id origin_file     speed
#>       <char>      <char>     <num>
#> 1: 2002-10-0      shapes  8.952511
#> 2: 2105-10-0      shapes 10.253365
#> 3: 2105-10-1      shapes  9.795292
#> 4: 2161-10-0      shapes 11.182534
#> 5: 2161-10-1      shapes 11.784458
#> 6: 4491-10-0      shapes 13.203560

trip_ids <- c("CPTM L07-0", "2002-10-0")
trip_speed <- get_trip_speed(gtfs, trip_ids)
trip_speed
#>       trip_id origin_file     speed
#>        <char>      <char>     <num>
#> 1:  2002-10-0      shapes  8.952511
#> 2: CPTM L07-0      shapes 26.787768

trip_speed <- get_trip_speed(
  gtfs,
  trip_ids,
  file = c("shapes", "stop_times")
)
trip_speed
#>       trip_id origin_file     speed
#>        <char>      <char>     <num>
#> 1:  2002-10-0      shapes  8.952511
#> 2:  2002-10-0  stop_times  6.559614
#> 3: CPTM L07-0      shapes 26.787768
#> 4: CPTM L07-0  stop_times 24.342591

trip_speed <- get_trip_speed(gtfs, trip_ids, unit = "m/s")
trip_speed
#>       trip_id origin_file    speed
#>        <char>      <char>    <num>
#> 1:  2002-10-0      shapes 2.486809
#> 2: CPTM L07-0      shapes 7.441047
```
