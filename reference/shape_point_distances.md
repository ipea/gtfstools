# Distance from each shape point to the previous one

Distance from each shape point to the previous one

## Usage

``` r
shape_point_distances(shape_id, lat, lon)
```

## Arguments

- shape_id, lat, lon:

  The `shape_id` and coordinates of the shape points, sorted by shape
  and sequence, so that the points of each shape are contiguous.

## Value

A numeric vector of distances in meters, on the same sphere used by
`{s2}`. The first point of each shape is 0 meters away from its
"previous" point, whatever its coordinates. For any other point, a
missing coordinate in it or in the previous point gives `NA`.
