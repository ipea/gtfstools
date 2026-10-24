# Build the nodes and links of a transit network

Build the nodes and links of a transit network

## Usage

``` r
build_service_network(
  gtfs,
  from_secs,
  to_secs,
  max_walk_dist,
  walk_speed,
  call = parent.frame()
)
```

## Arguments

- gtfs:

  A GTFS object.

- from_secs, to_secs:

  The time of day, in seconds after midnight.

- max_walk_dist:

  The maximum distance of transfer links, in meters.

- walk_speed:

  The walking speed, in km/h.

- call:

  The environment of the call that errors are raised from.

## Value

A list with the `node` and `link` tables of the network, as described in
[`build_graph()`](https://ipea.github.io/gtfstools/dev/reference/build_graph.md).
