# Calculate the vehicle-kilometres travelled by groups of trips

Calculate the vehicle-kilometres travelled by groups of trips

## Usage

``` r
calculate_vkt(gtfs, trips, date, window, lengths = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trips:

  A `data.table` with the columns `trip_id`, `service_id` and `group`
  (the group of each trip, such as its route), in the order of the
  `trips` table.

- date:

  A `Date` vector with the days to be counted, or `NULL` to count every
  day on which the services of `trips` run.

- window:

  An integer vector with the start and end of the time of day, in
  seconds after midnight, as returned by
  [`time_of_day_window()`](https://ipea.github.io/gtfstools/dev/reference/time_of_day_window.md),
  or `NULL` to count every departure.

- lengths:

  A `data.table` with the columns `trip_id` and `length` (in km, or in
  the unit in which the vkt is wanted), as returned by
  [`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
  or `NULL` to calculate the lengths of the counted trips (in km).

## Value

A `data.table` with the columns `group`, `n_days`, `vkt` and
`vkt_daily_mean`, as described in
[`get_vkt()`](https://ipea.github.io/gtfstools/dev/reference/get_vkt.md),
with one row for each group in `trips`, in their order. Groups without
any counted departure have `n_days` 0 and `NA` vkt.
