# Get the node of each stop

Groups stops by parent station: the node of a stop is its topmost
parent. Parents that are other stops are followed up to a stop without
parent, by pointer doubling, and the parent of that stop, if any, is the
node.

## Usage

``` r
get_stop_node_keys(stop_id, parent_station, ignored_parents)
```

## Arguments

- stop_id:

  A character vector of `stop_id`s, without duplicates.

- parent_station:

  A character vector with the parent of each stop, or `NULL`.

- ignored_parents:

  A character vector of `stop_id`s that are not considered parents.

## Value

A character vector with the node of each stop.
