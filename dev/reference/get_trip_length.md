# Get trip length

Returns the length of each specified `trip_id`, based either on the
`shapes` or the `stop_times` file (or both).

## Usage

``` r
get_trip_length(
  gtfs,
  trip_id = NULL,
  file = NULL,
  unit = "km",
  sort_sequence = FALSE
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to have their length
  calculated If `NULL` (the default), the function calculates the length
  of each `trip_id` in the GTFS.

- file:

  A character vector specifying the file from which lengths should be
  calculated (either one of or both `shapes` and `stop_times`). If
  `NULL` (the default), the function attempts to calculate the lengths
  from both files, but only raises an error if none of the files exist.

- unit:

  A string representing the unit in which lengths are desired. Either
  `"km"` (the default) or `"m"`.

- sort_sequence:

  A logical specifying whether to sort shapes and timetables by
  `shape_pt_sequence` and `stop_sequence`, respectively. Defaults to
  `FALSE`, otherwise spec-compliant feeds, in which shape/timetables
  points are already ordered by `shape_pt_sequence`/`stop_sequence`,
  would be penalized through longer processing times. Lengths calculated
  from trip trajectories generated with unordered sequences do not
  correctly depict the actual trip lengths.

## Value

A `data.table` containing the length of each specified trip.

## Details

Please check
[`get_trip_geometry()`](https://ipeagit.github.io/gtfstools/dev/reference/get_trip_geometry.md)
documentation to understand how geometry generation, and consequently
length calculation, differs depending on the chosen file.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

trip_length <- get_trip_length(gtfs)
head(trip_length)
#>       trip_id   length origin_file
#>        <char>    <num>      <char>
#> 1: CPTM L07-0 60.71894      shapes
#> 2: CPTM L07-1 60.71894      shapes
#> 3: CPTM L08-0 41.79037      shapes
#> 4: CPTM L08-1 41.79037      shapes
#> 5: CPTM L09-0 31.88906      shapes
#> 6: CPTM L09-1 31.88906      shapes

# the above is identical to
trip_length <- get_trip_length(gtfs, file = c("shapes", "stop_times"))
head(trip_length)
#>       trip_id   length origin_file
#>        <char>    <num>      <char>
#> 1: CPTM L07-0 60.71894      shapes
#> 2: CPTM L07-1 60.71894      shapes
#> 3: CPTM L08-0 41.79037      shapes
#> 4: CPTM L08-1 41.79037      shapes
#> 5: CPTM L09-0 31.88906      shapes
#> 6: CPTM L09-1 31.88906      shapes

trip_ids <- c("CPTM L07-0", "2002-10-0")
trip_length <- get_trip_length(gtfs, trip_id = trip_ids)
trip_length
#>       trip_id    length origin_file
#>        <char>     <num>      <char>
#> 1: CPTM L07-0 60.718942      shapes
#> 2:  2002-10-0  7.162009      shapes
#> 3: CPTM L07-0 55.176541  stop_times
#> 4:  2002-10-0  5.247691  stop_times
```
