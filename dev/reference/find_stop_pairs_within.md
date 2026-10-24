# Find the pairs of stops within a distance of each other

Finds the pairs of points within `max_dist` of each other with a grid of
cells at least `max_dist` wide, so that only points in neighbouring
cells are compared.

## Usage

``` r
find_stop_pairs_within(lat, lon, max_dist, check_n_pairs)
```

## Arguments

- lat, lon:

  Numeric vectors with the coordinates of each point, in degrees. Points
  without coordinates are ignored.

- max_dist:

  A number, in meters.

- check_n_pairs:

  A function called with the number of pairs of points in neighbouring
  cells before they are listed, to check that they can be compared.

## Value

A `data.table` with the indices of the two points of each pair (`from`
smaller than `to`) and the `distance` between them, in meters.
