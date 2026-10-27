# Warn about trips not linked to a usable shape

Warn about trips not linked to a usable shape

## Usage

``` r
warn_trips_without_shape(trip_ids)
```

## Arguments

- trip_ids:

  The `trip_id`s of the trips not linked to a shape with at least two
  distinct points.

## Value

Invisibly returns `NULL`. Raises a warning of class
`"gtfstools_trips_without_shape"`, whose `trip_id` field holds the given
`trip_id`s.
