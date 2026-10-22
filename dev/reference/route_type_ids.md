# Get the `route_id`s of the given `route_type`s

Returns the `route_id`s listed in `routes` with any of the given
`route_type`s. Types not listed in `routes` are ignored. Also checks the
`trips` table, which the callers use to get the trips of these routes,
so that a feed without it raises an error instead of selecting nothing.

## Usage

``` r
route_type_ids(gtfs, route_type)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- route_type:

  An integer vector of `route_type`s.

## Value

A character vector of `route_id`s.
