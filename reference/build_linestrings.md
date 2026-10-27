# Build linestrings from sequences of points

Build linestrings from sequences of points

## Usage

``` r
build_linestrings(points, id_col, x_col = "lon", y_col = "lat")
```

## Arguments

- points:

  A `data.table` with the coordinates of each point and an integer
  column identifying the linestring of each point. The points of each
  linestring must be contiguous and the ids increasing.

- id_col:

  The name of the column that identifies the linestrings.

- x_col, y_col:

  The names of the columns with the longitude and the latitude of each
  point.

## Value

A `sfc_LINESTRING` in WGS 84, with one linestring per id.
