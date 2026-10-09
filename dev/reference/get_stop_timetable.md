# Get stop timetable

Returns the timetable of the given stops on the given dates: one row for
each stop time at these stops on each date on which its trip runs.

## Usage

``` r
get_stop_timetable(gtfs, stop_id = NULL, date = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- stop_id:

  A character vector including the `stop_id`s whose timetable should be
  built. If `NULL` (the default), the timetable of all stops is built.

- date:

  A `Date` vector (including `IDate`) or a character vector of dates in
  the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. If `NULL` (the default),
  all the dates on which the GTFS object has service (as returned by
  [`get_dates()`](https://ipea.github.io/gtfstools/dev/reference/get_dates.md))
  are used, which may result in a very large table.

## Value

A `data.table` with the column `date` (of class `Date`), followed by all
the columns of `trips` and all the columns of `stop_times` (`trip_id`
appears only once). It is sorted by `date`, `stop_id`, departure time
and `trip_id`. If no trip stops at the given stops on the given dates,
an empty table with the same columns is returned, without a warning.

## Details

A trip runs on a date if its service is active on it, as in
[`get_active_services()`](https://ipea.github.io/gtfstools/dev/reference/get_active_services.md),
so dates outside the period covered by the GTFS object are skipped.
Trips listed in `stop_times` but not in `trips` are not included.
Departure times are sorted as times, not as strings, and stop times with
an empty `departure_time` come last at each stop. Duplicated rows in
`trips` and `stop_times` are kept.

Without `calendar` and `calendar_dates` tables, no trip runs, and an
empty table is returned. Columns other than `trip_id` present in both
`trips` and `stop_times` (not defined by the GTFS reference) appear
twice, the one from `stop_times` prefixed with `i.`, and the ones from
`trips` are used to sort the timetable.

`date` is the service date: stop times past 24:00:00 happen on the
following calendar day.

Only the exact given stops are included: to include the stops of a
station, pass them with
[`get_children_stops()`](https://ipea.github.io/gtfstools/dev/reference/get_children_stops.md).
The `frequencies` table is not used: frequency-based trips appear with
the times of their template trips, as listed in `stop_times`. To include
all their departures, convert them with
[`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
first.

## See also

[`get_route_timetable()`](https://ipea.github.io/gtfstools/dev/reference/get_route_timetable.md),
[`get_active_services()`](https://ipea.github.io/gtfstools/dev/reference/get_active_services.md),
[`get_dates()`](https://ipea.github.io/gtfstools/dev/reference/get_dates.md)

## Examples

``` r
data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

timetable <- get_stop_timetable(gtfs, "100000720101", "20210104")
head(timetable)
#>          date route_id service_id   trip_id               trip_headsign
#>        <Date>   <char>     <char>    <char>                      <char>
#> 1: 2021-01-04 1923_700          8 146389715 Dallgow-Döberitz, Havelpark
#> 2: 2021-01-04   1921_3          1 143766496          Falkensee, Bahnhof
#> 3: 2021-01-04 1922_700          8 146388926          Falkensee, Bahnhof
#> 4: 2021-01-04 1921_700          8 146388330          Falkensee, Bahnhof
#> 5: 2021-01-04 1922_700          8 146388884          Falkensee, Bahnhof
#> 6: 2021-01-04 1923_700          8 146389713 Dallgow-Döberitz, Havelpark
#>    trip_short_name direction_id block_id shape_id wheelchair_accessible
#>             <char>        <int>   <char>   <char>                 <int>
#> 1:                            0                20                    NA
#> 2:                            1                12                    NA
#> 3:                            0                15                    NA
#> 4:                            1                13                    NA
#> 5:                            1                18                    NA
#> 6:                            0                20                    NA
#>    bikes_allowed arrival_time departure_time      stop_id stop_sequence
#>            <int>       <char>         <char>       <char>         <int>
#> 1:            NA     05:05:00       05:05:00 100000720101             3
#> 2:            NA     05:19:00       05:19:00 100000720101            17
#> 3:            NA     05:23:00       05:23:00 100000720101            20
#> 4:            NA     05:51:00       05:51:00 100000720101            18
#> 5:            NA     05:58:00       05:58:00 100000720101            26
#> 6:            NA     06:05:00       06:05:00 100000720101             3
#>    pickup_type drop_off_type stop_headsign
#>          <int>         <int>        <char>
#> 1:           0             0              
#> 2:           0             0              
#> 3:           0             0              
#> 4:           0             0              
#> 5:           0             0              
#> 6:           0             0              

# several dates, also as Date objects
timetable <- get_stop_timetable(
  gtfs,
  stop_id = "100000720101",
  date = as.Date(c("2021-01-04", "2021-01-09"))
)
table(timetable$date)
#> 
#> 2021-01-04 2021-01-09 
#>        106         28 
```
