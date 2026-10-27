# Build a transit network graph

Builds a frequency-based transit network from the trips that depart
within a time of day, and returns it as a set of tables in the General
Modeling Network Specification (GMNS) format or as an `{igraph}` or
`{tidygraph}` graph. The network can be used in transit assignment
models and in graph analyses, such as finding the shortest travel times
between stops.

## Usage

``` r
build_graph(
  gtfs,
  from,
  to,
  format = "gmns",
  max_walk_dist = 300,
  walk_speed = 5
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- from:

  A string. The starting point of the time of day, in the "HH:MM:SS"
  format.

- to:

  A string. The ending point of the time of day, in the "HH:MM:SS"
  format. Must be later than `from`.

- format:

  A string. The format of the graph: `"gmns"` (the default), `"igraph"`
  or `"tidygraph"`. The last two require the packages of the same name,
  which the function offers to install in interactive sessions.

- max_walk_dist:

  A number. The maximum great-circle distance, in meters, between two
  stops connected by walking transfer links. Defaults to 300.

- walk_speed:

  A number. The walking speed, in km/h, used to calculate the travel
  time of transfer links. Defaults to 5.

## Value

With `format = "gmns"`, a list with the `data.table`s `node`, `link` and
`config`, named after the GMNS files. With `format = "igraph"`, a
directed `igraph` graph, and with `format = "tidygraph"`, a directed
`tbl_graph`. Their vertices and edges have the columns of the `node` and
`link` tables as attributes, and the `name` of each vertex is its
`node_id`, as a string.

## Details

Nodes (`node_type`) are `"stop"` nodes, one per stop visited by the
trips, at the stop's coordinates, and `"service"` nodes, one per route
and direction at each of its stops, at the coordinates of the stop
(their `parent_node_id`). Links (`link_type`) are all directed:

- `"in_vehicle"` links connect the service nodes of consecutive stops of
  the trips. `travel_time` is the mean time from the departure at a stop
  to the arrival at the next, over the trips with both times (decreasing
  times are not used), weighted by their departures. `departures` is the
  number of departures of the trips of the network that run through the
  link. `length` is the great-circle distance between the stops, as in
  [`get_stop_distances()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_distances.md),
  and `free_speed` the length divided by the travel time (`NA` when the
  travel time is 0 or either is missing).

- `"boarding"` links connect each stop to the service nodes from which
  trips depart. `departures` is the number of departures from the stop
  of the trips of the network, so it may include departures after `to`
  from stops far along their routes. `travel_time` is half the mean
  headway (the length of the time of day divided by `departures`).

- `"alighting"` links connect each service node back to its stop, with a
  `travel_time` of 0.

- `"transfer"` links connect, in both directions, the stops at most
  `max_walk_dist` apart. `travel_time` is the length divided by
  `walk_speed`, which is also their `free_speed`.

Lengths are in meters, travel times in minutes and speeds in km/h.
Boarding and alighting links have a `length` of 0 and an `NA`
`free_speed`; alighting and transfer links have `NA` `departures`.
`route_id`, `direction_id` and `inferred_direction` are those of the
link's service node, and `NA` in transfer links.

The network includes the trips that depart from their first stop at or
after `from` and before `to`, as in
[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md),
so trips already running at `from` are not included. Trips listed in
`frequencies` are included once per departure generated within the time
of day, with their `stop_times` entries as templates. Trips without
`stop_times` entries are not included. The trips of every `service_id`
are pooled, so the feed should usually be filtered to a single day
first, with
[`filter_by_date()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_date.md)
or
[`filter_by_weekday()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_weekday.md).
Departures after midnight have times past "24:00:00", so use a time of
day such as "24:00:00"-"26:00:00" for them. Trips whose times wrongly go
back to "00:00:00" after midnight are placed by their earliest time.

Within a trip, consecutive `stop_times` entries at the same stop are one
visit, arriving at their first known time and departing at their last. A
trip that visits a stop more than once uses a different service node at
each visit (`visit` 1, 2, ...).

Directions come from the `direction_id` field of `trips`. Trips without
it (or with a blank `direction_id`) get an `inferred_direction` instead:
trips of a route that share a pair of consecutive stops, in the same
order, are in the same direction, and so are trips that share pairs with
them. The opposite directions of routes that share a pair of stops in
the same order (e.g. through a one-way loop or street) are thus inferred
as a single direction. Trips with a blank `direction_id` are never
assigned the direction of other trips of their route.

In-vehicle links whose trips all have blank or decreasing times have an
`NA` `travel_time`, with a warning;
[`igraph::distances()`](https://r.igraph.org/reference/distances.html)
doesn't accept it as a weight, and blank times can be filled beforehand
with
[`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md).
Alighting links, in-vehicle links between stops with the same times and
transfer links between stops at the same coordinates have a travel time
of 0;
[`igraph::closeness()`](https://r.igraph.org/reference/closeness.html)
and
[`igraph::betweenness()`](https://r.igraph.org/reference/betweenness.html)
require positive weights.

Departures are counted at every visit but the last of each trip, even
with a blank departure time, unlike in
[`get_stop_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_frequency.md).
The `transfers` and `pathways` tables, `parent_station`s and the
`pickup_type` and `drop_off_type` fields are not used. Large values of
`max_walk_dist` in dense feeds raise a warning when comparing the pairs
of stops may use a lot of memory, or an error when there are too many
pairs. Transfer links are not created across the antimeridian.

In the GMNS format, `node_id`, `x_coord`, `y_coord`, `node_type`,
`parent_node_id`, `link_id`, `from_node_id`, `to_node_id`, `directed`,
`length` and `free_speed` are GMNS fields; the other columns are
additional fields, as allowed by GMNS. `config` lists the units, the
coordinate reference system (EPSG:4326), the GMNS version (0.96) and the
time of day. Stops not listed in `stops` or without coordinates have
`NA` coordinates, with a warning (GMNS requires them). Free speeds may
exceed the 200 km/h maximum checked by GMNS validators.

## See also

The "Building transit network graphs" vignette
([`vignette("graphs", package = "gtfstools")`](https://ipea.github.io/gtfstools/dev/articles/graphs.md)),
which shows how to analyse and plot the network with `{igraph}`,
`{tidygraph}`, `{sfnetworks}` and `{ggraph}`.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# the services of every day are pooled together, so only the services of a
# single weekday are kept
gtfs <- filter_by_weekday(gtfs, "wednesday")

graph <- build_graph(gtfs, from = "07:00:00", to = "08:00:00")
names(graph)
#> [1] "node"   "link"   "config"
head(graph$node)
#>    node_id   x_coord   y_coord node_type parent_node_id   stop_id
#>      <int>     <num>     <num>    <char>          <int>    <char>
#> 1:       1 -46.61467 -23.53415      stop             NA 100014307
#> 2:       2 -46.61595 -23.53545      stop             NA 100014308
#> 3:       3 -46.61977 -23.53527      stop             NA 100014309
#> 4:       4 -46.61736 -23.54202      stop             NA 100014321
#> 5:       5 -46.61460 -23.53777      stop             NA 100014331
#> 6:       6 -46.61672 -23.53790      stop             NA 100014332
#>                 stop_name route_id direction_id inferred_direction visit
#>                    <char>   <char>        <int>              <int> <int>
#> 1:    R. Silva Teles, 281     <NA>           NA                 NA    NA
#> 2:     R. Silva Teles, 99     <NA>           NA                 NA    NA
#> 3:  R. João Teodoro, 1331     <NA>           NA                 NA    NA
#> 4: Lgo. Da Concordia, 125     <NA>           NA                 NA    NA
#> 5:        R. Oriente, 760     <NA>           NA                 NA    NA
#> 6:        R. Oriente, 556     <NA>           NA                 NA    NA
head(graph$link)
#>    link_id from_node_id to_node_id directed   length free_speed  link_type
#>      <int>        <int>      <int>   <lgcl>    <num>      <num>     <char>
#> 1:       1          655        656     TRUE 194.1362   6.720098 in_vehicle
#> 2:       2          656        666     TRUE 353.3803  12.232396 in_vehicle
#> 3:       3          657        674     TRUE 447.0238  12.572543 in_vehicle
#> 4:       4          658        672     TRUE 636.0825  22.018241 in_vehicle
#> 5:       5          659        682     TRUE 273.6917  10.481811 in_vehicle
#> 6:       6          660        659     TRUE 216.6252   8.296284 in_vehicle
#>    travel_time departures route_id direction_id inferred_direction
#>          <num>      <int>   <char>        <int>              <int>
#> 1:    1.733333          5  2161-10            0                 NA
#> 2:    1.733333          5  2161-10            0                 NA
#> 3:    2.133333          4  2105-10            1                 NA
#> 4:    1.733333          5  2161-10            0                 NA
#> 5:    1.566667          5  2161-10            1                 NA
#> 6:    1.566667          5  2161-10            1                 NA

# the tables can be written to the csv files of a GMNS network
gmns_dir <- tempfile("gmns")
dir.create(gmns_dir)
for (table in names(graph)) {
  gmns_file <- file.path(gmns_dir, paste0(table, ".csv"))
  data.table::fwrite(graph[[table]], gmns_file)
}
list.files(gmns_dir)
#> [1] "config.csv" "link.csv"   "node.csv"  

# the shortest travel times, in minutes, from a stop to the other stops
graph <- build_graph(
  gtfs,
  from = "07:00:00",
  to = "08:00:00",
  format = "igraph"
)
stop_nodes <- igraph::V(graph)[igraph::V(graph)$node_type == "stop"]
travel_times <- igraph::distances(
  graph,
  v = stop_nodes[1],
  to = stop_nodes,
  mode = "out",
  weights = igraph::E(graph)$travel_time
)

# stops that can't be reached have an infinite travel time
is_reachable <- is.finite(travel_times)
sum(is_reachable)
#> [1] 639
summary(travel_times[is_reachable])
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>    0.00   35.67   53.21   57.91   74.17  167.39 
```
