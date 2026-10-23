# Cluster stop nodes by distance

Finds the pairs of nodes within `max_dist` of each other with a grid of
cells at least `max_dist` wide, so that only nodes in neighbouring cells
are compared, and merges them with `cpp_merge_stop_clusters()`.

## Usage

``` r
cluster_stop_nodes(lat, lon, max_dist)
```

## Arguments

- lat, lon:

  Numeric vectors with the coordinates of each node, in degrees.

- max_dist:

  A number, in meters.

## Value

An integer vector with the cluster of each node. When every pair of
nodes is surely within `max_dist`, all nodes are in cluster 1 and the
pairs are not calculated.
