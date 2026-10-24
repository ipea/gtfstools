# Infer the direction of trips

The trips of a route that share a pair of consecutive stops, in the same
order, are in the same direction, and so are the trips that share pairs
with them. The directions are the connected components of trips linked
by shared pairs, found by propagating the smallest trip number through
the pairs, and through the labels of labels, until it no longer changes.

## Usage

``` r
infer_trip_directions(trip_id, route_id, stop_id)
```

## Arguments

- trip_id, route_id, stop_id:

  The `trip_id`, `route_id` and `stop_id` of the visits of the trips, in
  which the visits of each trip are contiguous and in order.

## Value

An integer vector with the inferred direction of the trip of each visit,
numbered from 1 within each route in order of first appearance.
