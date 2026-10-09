# Merge the overlapping calendar intervals of each service and weekday

Merge the overlapping calendar intervals of each service and weekday

## Usage

``` r
merge_service_intervals(service_intervals)
```

## Arguments

- service_intervals:

  A `data.table` with the columns `sid`, `weekday`, `first_day` and
  `last_day` (integer days since 1970-01-01).

## Value

A `data.table` with the same columns, in which the intervals of a
service on a weekday don't overlap. `service_intervals` is reordered by
reference.
