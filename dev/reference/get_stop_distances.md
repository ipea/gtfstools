# Get distances between stops

Returns the distance between each pair of stops visited by the given
trips and/or routes.

## Usage

``` r
get_stop_distances(gtfs, trip_id = NULL, route_id = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s whose stops should be
  considered. If `NULL` (the default), all trips are considered. An
  empty vector selects no trip.

- route_id:

  A character vector including the `route_id`s whose stops should be
  considered. If `NULL` (the default), all routes are considered. An
  empty vector selects no route.

## Value

A `data.table` with the columns `from_stop_id`, `to_stop_id` and
`distance` (in meters), with one row for each pair of distinct stops,
sorted by `from_stop_id` and `to_stop_id`. It is empty if fewer than two
stops are selected.

## Details

The stops are selected as in
[`get_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_stops.md):
only the stops listed in the `stop_times` entries of the selected trips
are considered.

Distances are great-circle distances ("as the crow flies") between the
stops' coordinates, not distances along the trips' shapes or the street
network.

Each pair of stops appears only once, with the `stop_id` that comes
first in the C locale (the order used by `data.table`) as
`from_stop_id`. If a `stop_id` is listed more than once in `stops`, only
its first entry is used. Stops without coordinates have `NA` distances.

The size of the result grows with the square of the number of stops:
about 1 GB of memory is used for 5,500 stops, and about 3 GB for 10,000
stops. A warning is raised when more than 1 GB is needed, so on large
feeds please select only the trips or routes of interest. More than
65,536 stops can't be used at once, raising an error.

## See also

[`get_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_stops.md),
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# distances between the stops visited by a trip
distances <- get_stop_distances(gtfs, trip_id = "CPTM L07-0")
head(distances)
#>    from_stop_id to_stop_id  distance
#>          <char>     <char>     <num>
#> 1:        18916      18917  1861.838
#> 2:        18916      18919  3237.855
#> 3:        18916      18920  5469.577
#> 4:        18916      18921 11841.754
#> 5:        18916      18922  5921.628
#> 6:        18916      18923  4827.782

# distances between the stops visited by the trips of a route
distances <- get_stop_distances(gtfs, route_id = "CPTM L07")
head(distances)
#>    from_stop_id to_stop_id  distance
#>          <char>     <char>     <num>
#> 1:        18916      18917  1861.838
#> 2:        18916      18919  3237.855
#> 3:        18916      18920  5469.577
#> 4:        18916      18921 11841.754
#> 5:        18916      18922  5921.628
#> 6:        18916      18923  4827.782
```
