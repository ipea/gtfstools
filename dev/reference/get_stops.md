# Get stops

Returns the stops visited by the given trips and/or routes.

## Usage

``` r
get_stops(gtfs, trip_id = NULL, route_id = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s whose stops should be
  returned. If `NULL` (the default), all trips are considered. An empty
  vector selects no trip.

- route_id:

  A character vector including the `route_id`s whose stops should be
  returned. If `NULL` (the default), all routes are considered. An empty
  vector selects no route.

## Value

A `data.table` with the entries of the `stops` table that are visited by
the selected trips, with all its columns and in its original order.

## Details

A trip is selected if it is listed in `trip_id` (when given) and belongs
to one of the routes listed in `route_id` (when given), so when both are
given only the trips that satisfy both are selected. When `route_id` is
given, trips not listed in the `trips` table can't be matched to a route
and are not selected. Ids not found in the feed raise a warning.

Only the stops listed in the `stop_times` entries of the selected trips
are returned, so their parent stations, entrances, etc. are not. Please
use
[`get_parent_station()`](https://ipea.github.io/gtfstools/dev/reference/get_parent_station.md)
and
[`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md)
to get these. Stops listed in `stop_times` but not in `stops` are not
returned.

## See also

[`get_parent_station()`](https://ipea.github.io/gtfstools/dev/reference/get_parent_station.md),
[`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md),
[`filter_by_trip_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_trip_id.md),
[`filter_by_route_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_route_id.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# stops visited by a trip
stops <- get_stops(gtfs, trip_id = "CPTM L07-0")
head(stops)
#>    stop_id               stop_name stop_desc  stop_lat  stop_lon
#>     <char>                  <char>    <char>     <num>     <num>
#> 1:   18916                 Piqueri           -23.50421 -46.71500
#> 2:   18917          Lapa (linha 7)           -23.51754 -46.70395
#> 3:   18919             Água Branca           -23.52123 -46.68924
#> 4:   18920 Palmeiras - Barra Funda           -23.52532 -46.66655
#> 5:   18921                   Perus           -23.40405 -46.75447
#> 6:   18922                 Jaraguá           -23.45550 -46.73848

# stops visited by the trips of a route
stops <- get_stops(gtfs, route_id = "CPTM L07")
head(stops)
#>    stop_id               stop_name stop_desc  stop_lat  stop_lon
#>     <char>                  <char>    <char>     <num>     <num>
#> 1:   18916                 Piqueri           -23.50421 -46.71500
#> 2:   18917          Lapa (linha 7)           -23.51754 -46.70395
#> 3:   18919             Água Branca           -23.52123 -46.68924
#> 4:   18920 Palmeiras - Barra Funda           -23.52532 -46.66655
#> 5:   18921                   Perus           -23.40405 -46.75447
#> 6:   18922                 Jaraguá           -23.45550 -46.73848

# stops visited by any trip
stops <- get_stops(gtfs)
nrow(stops)
#> [1] 654
```
