# Get stop times patterns

Identifies spatial and spatiotemporal patterns within the `stop_times`
table. Please see the details to understand what a "pattern" means in
each of these cases.

## Usage

``` r
get_stop_times_patterns(
  gtfs,
  trip_id = NULL,
  type = "spatial",
  sort_sequence = FALSE
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to have their `stop_times`
  entries analyzed. If `NULL` (the default), the function analyses the
  pattern of every `trip_id` in the GTFS.

- type:

  A string specifying the type of patterns to be analyzed. Either
  `"spatial"` (the default) or "spatiotemporal".

- sort_sequence:

  A logical specifying whether to sort timetables by `stop_sequence`.
  Defaults to `FALSE`, otherwise spec-compliant feeds, in which
  timetables points are already ordered by `stop_sequence`, would be
  penalized through longer processing times. Pattern identification
  based on unordered timetables may result in multiple ids identifying
  what would be the same pattern, had the table been ordered.

## Value

A `data.table` associating each `trip_id` to a `pattern_id`.

## Details

Two trips are assigned to the same spatial `pattern_id` if they travel
along the same sequence of stops. They are assigned to the same
spatiotemporal `pattern_id`, on the other hand, if they travel along the
same sequence of stops and they take the same time between stops. Please
note that, in such case, only the time between stops is taken into
account, and the time that the trip started is ignored (e.g. if two
trips depart from stop A and follow the same sequence of stops to arrive
at stop B, taking both 1 hour to do so, their spatiotemporal pattern
will be considered the same, even if one departed at 6 am and another at
7 am). Please also note that the `stop_sequence` field is currently
ignored - which means that two stops are considered to follow the same
sequence if one is listed right below the other on the `stop_times`
table (e.g. if trip X lists stops A followed by stop B with
`stop_sequence`s 1 and 2, and trip Y lists stops A followed by stop B
with `stop_sequence`s 1 and 3, they are assigned to the same
`pattern_id`).

## Examples

``` r
data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

patterns <- get_stop_times_patterns(gtfs)
head(patterns)
#> Key: <trip_id>
#>      trip_id pattern_id
#>       <char>      <int>
#> 1: 143765655          1
#> 2: 143765656          2
#> 3: 143765658          3
#> 4: 143765659          3
#> 5: 143765660          3
#> 6: 143765661          3

# use the trip_id argument to control which trips are analyzed
patterns <- get_stop_times_patterns(
  gtfs,
  trip_id = c("143765658", "143765659", "143765660")
)
patterns
#> Key: <trip_id>
#>      trip_id pattern_id
#>       <char>      <int>
#> 1: 143765658          1
#> 2: 143765659          1
#> 3: 143765660          1

# use the type argument to control the type of pattern analyzed
patterns <- get_stop_times_patterns(
  gtfs,
  trip_id = c("143765658", "143765659", "143765660"),
  type = "spatiotemporal"
)
patterns
#> Key: <trip_id>
#>      trip_id pattern_id
#>       <char>      <int>
#> 1: 143765658          1
#> 2: 143765659          2
#> 3: 143765660          2
```
