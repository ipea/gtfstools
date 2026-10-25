# Get vehicle-miles travelled

Returns the vehicle-miles travelled (VMT) by each specified `route_id`:
the length of each of its trips, counted once for every departure of the
trip on every day on which its service runs. VMT can be restricted to
some dates and to a time of day.

## Usage

``` r
get_vmt(gtfs, route_id = NULL, date = NULL, from = NULL, to = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- route_id:

  A character vector including the `route_id`s to have their VKT
  calculated. If `NULL` (the default), the function calculates the VKT
  of every `route_id` in the GTFS. `route_id`s not listed in `trips` are
  ignored, with a warning.

- date:

  A `Date` vector (including `IDate`) or a character vector of dates in
  the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. If given, only these dates
  are counted. If `NULL` (the default), every day on which the services
  of the routes run is counted.

- from, to:

  Strings in the `"HH:MM:SS"` format. If given (both must be), only the
  departures at or after `from` and at or before `to` are counted. If
  `NULL` (the default), every departure is counted.

## Value

A `data.table` with the columns `route_id`, `n_days` (the number of
counted days on which at least one counted departure of the route runs),
`vmt` (the vehicle-miles travelled on these days) and `vmt_daily_mean`
(`vmt` divided by `n_days`, in miles per day), sorted by `route_id`.
Routes without any departure on the counted days (and within the time of
day) are not included.

## Details

The VMT is the vehicle-kilometres travelled calculated by
[`get_vkt()`](https://ipea.github.io/gtfstools/dev/reference/get_vkt.md),
converted to international miles (1 mile = 1.609344 km). See
[`get_vkt()`](https://ipea.github.io/gtfstools/dev/reference/get_vkt.md)
for how trips, departures, days and trip lengths are counted.

## See also

[`get_vkt()`](https://ipea.github.io/gtfstools/dev/reference/get_vkt.md),
[`get_route_frequency()`](https://ipea.github.io/gtfstools/dev/reference/get_route_frequency.md),
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# VMT of every route over every day of the feed's calendar
vmt <- get_vmt(gtfs)
head(vmt)
#>    route_id n_days        vmt vmt_daily_mean
#>      <char>  <int>      <num>          <num>
#> 1:  2002-10   4505  3070644.5      681.60810
#> 2:  2105-10   4505  6860989.4     1522.97212
#> 3:  2161-10   4505  7358451.1     1633.39647
#> 4:  4491-10   4505  4501789.5      999.28734
#> 5:  5290-10   4505 10214707.2     2267.41559
#> 6:  6450-51   3219   156885.9       48.73747

# VMT of two routes in the morning peak of a single day
get_vmt(
  gtfs,
  route_id = c("CPTM L07", "2002-10"),
  date = "2019-03-04",
  from = "07:00:00",
  to = "09:00:00"
)
#>    route_id n_days        vmt vmt_daily_mean
#>      <char>  <int>      <num>          <num>
#> 1:  2002-10      1   87.27909       87.27909
#> 2: CPTM L07      1 1581.20168     1581.20168
```
