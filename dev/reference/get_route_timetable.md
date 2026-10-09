# Get route timetable

Returns the timetable of the given routes on the given dates: one row
for each stop time of their trips on each date on which the trip runs.

## Usage

``` r
get_route_timetable(gtfs, route_id = NULL, date = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- route_id:

  A character vector including the `route_id`s whose timetable should be
  built. If `NULL` (the default), the timetable of all routes is built.

- date:

  A `Date` vector (including `IDate`) or a character vector of dates in
  the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. If `NULL` (the default),
  all the dates on which the GTFS object has service (as returned by
  [`get_dates()`](https://ipea.github.io/gtfstools/dev/reference/get_dates.md))
  are used, which may result in a very large table.

## Value

A `data.table` with the column `date` (of class `Date`), followed by all
the columns of `trips` and all the columns of `stop_times` (`trip_id`
appears only once). It is sorted by `date` and `route_id`, and then the
trips of each route are sorted by their first departure time (and
`trip_id`), each with its stop times sorted by `stop_sequence`. If the
given routes have no trips on the given dates, an empty table with the
same columns is returned, without a warning.

## Details

A trip runs on a date if its service is active on it, as in
[`get_active_services()`](https://ipea.github.io/gtfstools/dev/reference/get_active_services.md),
so dates outside the period covered by the GTFS object are skipped.
Trips listed in `stop_times` but not in `trips` are not included.
Departure times are sorted as times, not as strings, and trips without
any departure time come last in their route. Duplicated rows in `trips`
and `stop_times` are kept.

Without `calendar` and `calendar_dates` tables, no trip runs, and an
empty table is returned. Columns other than `trip_id` present in both
`trips` and `stop_times` (not defined by the GTFS reference) appear
twice, the one from `stop_times` prefixed with `i.`, and the ones from
`trips` are used to sort the timetable.

`date` is the service date: stop times past 24:00:00 happen on the
following calendar day.

The `frequencies` table is not used: frequency-based trips appear with
the times of their template trips, as listed in `stop_times`. To include
all their departures, convert them with
[`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
first.

## See also

[`get_stop_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_timetable.md),
[`get_active_services()`](https://ipea.github.io/gtfstools/dev/reference/get_active_services.md),
[`get_dates()`](https://ipea.github.io/gtfstools/dev/reference/get_dates.md)

## Examples

``` r
data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

timetable <- get_route_timetable(gtfs, "1922_3", "20210104")
head(timetable)
#>          date route_id service_id   trip_id      trip_headsign trip_short_name
#>        <Date>   <char>     <char>    <char>             <char>          <char>
#> 1: 2021-01-04   1922_3          1 143767305 Falkensee, Bahnhof                
#> 2: 2021-01-04   1922_3          1 143767305 Falkensee, Bahnhof                
#> 3: 2021-01-04   1922_3          1 143767305 Falkensee, Bahnhof                
#> 4: 2021-01-04   1922_3          1 143767305 Falkensee, Bahnhof                
#> 5: 2021-01-04   1922_3          1 143767305 Falkensee, Bahnhof                
#> 6: 2021-01-04   1922_3          1 143767305 Falkensee, Bahnhof                
#>    direction_id block_id shape_id wheelchair_accessible bikes_allowed
#>           <int>   <char>   <char>                 <int>         <int>
#> 1:            1                17                    NA            NA
#> 2:            1                17                    NA            NA
#> 3:            1                17                    NA            NA
#> 4:            1                17                    NA            NA
#> 5:            1                17                    NA            NA
#> 6:            1                17                    NA            NA
#>    arrival_time departure_time      stop_id stop_sequence pickup_type
#>          <char>         <char>       <char>         <int>       <int>
#> 1:     08:20:00       08:20:00 100000710204             0           0
#> 2:     08:22:00       08:22:00 100000715601             1           0
#> 3:     08:23:30       08:23:30 100000719102             2           0
#> 4:     08:25:30       08:25:30 100000711602             3           0
#> 5:     08:26:30       08:26:30 100000711103             4           0
#> 6:     08:28:00       08:28:00 100000720102             5           0
#>    drop_off_type stop_headsign
#>            <int>        <char>
#> 1:             0              
#> 2:             0              
#> 3:             0              
#> 4:             0              
#> 5:             0              
#> 6:             0              

# several routes and dates, also as Date objects
timetable <- get_route_timetable(
  gtfs,
  route_id = c("1922_3", "1921_3"),
  date = as.Date(c("2021-01-04", "2021-01-09"))
)
table(timetable$date, timetable$route_id)
#>             
#>              1921_3 1922_3
#>   2021-01-04     22    446
#>   2021-01-09      0    175
```
