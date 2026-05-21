# Filter GTFS object by time of day

Filters a GTFS object by time of day, keeping (or dropping) the relevant
entries in each file. Please see the details section for more
information on how this function filters the `frequencies` and
`stop_times` tables, as well as how it handles `stop_times` tables that
contain trips with some empty departure and arrival times.

## Usage

``` r
filter_by_time_of_day(
  gtfs,
  from,
  to,
  keep = TRUE,
  full_trips = FALSE,
  update_frequencies = TRUE
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- from:

  A string. The starting point of the time of day, in the "HH:MM:SS"
  format.

- to:

  A string. The ending point of the time of day, in the "HH:MM:SS"
  format.

- keep:

  A logical. Whether the entries related to the specified time of day
  should be kept or dropped (defaults to `TRUE`, which keeps the
  entries).

- full_trips:

  A logical. Whether trips should be treated as immutable blocks or each
  of its stops should be considered separately when filtering the
  `stop_times` table (defaults to `FALSE`, which considers each stop
  individually). Please check the details section for more information
  on how this parameter changes the function behaviour.

- update_frequencies:

  A logical. Whether the `frequencies` table should have its
  `start_time` and `end_time` fields updated to fit inside/outside the
  specified time of day (defaults to `FALSE`, which doesn't update the
  fields).

## Value

The GTFS object passed to the `gtfs` parameter, after the filtering
process.

## Details

When filtering the `frequencies` table, `filter_by_time_of_day()`
respects the `exact_times` field. This field indicates whether the
service follows a fixed schedule throughout the day or not. If it's 0
(or if it's not present), the service does not follow a fixed schedule.
Instead, the operators try to maintain the listed headways. In such
cases, if `update_frequencies` is `TRUE` we just update `start_time` and
`end_time` to the appropriate value of `from` or `to` (which of this
value is used depends on `keep`).

If `exact_times` is 1, however, operators try to strictly adhere to the
start times and headway. As a result, when updating the `start_time`
field we need to follow the listed headway. For example, take a trip
that has its start time listed as 06:00:00, its end time listed as
08:00:00 and its headway listed as 300 secs (5 minutes). If you decide
to filter the feed to keep the time of day between 06:32:00 and 08:00:00
while updating `frequencies`, the `start_time` field must be updated to
06:35:00 in order to preserve the correct departure times of this trips,
instead of simply updating it to 06:32:00.

Another things to keep an eye on when filtering the `frequencies` table
is that the corresponding `stop_times` entries of trips listed in the
`frequencies` table should not be filtered, even if their departure and
arrival times fall outside the specified time of day. This is because
the `stop_times` entries of `frequencies`' trips are just templates that
describe how long a segment between two stops takes, so the departure
and arrival times listed there do not actually represent the actual
departure and arrival times seen in practice. Taking the same example
listed above, the corresponding `stop_times` entries of that trip could
describe a departure from the first stop at 12:00:00 and an arrival at
the second stop at 12:03:00. That doesn't mean the trip will actually
leave and arrive at the stops at these times, but rather that it takes 3
minutes to get from the first to the second stop. So when the trip
departs from the first stop at 06:35:00, it will get to the second at
06:38:00.

When filtering the `stop_times` table, a few other details should be
observed. First, one could wish to filter a GTFS object in order to keep
all trips that cross a given time of day, whereas others may want to
keep only the specific entries that fall inside the specified time of
day. For example, take a trip that leaves the first stop at 06:30:00,
gets to the second at 06:35:00 and then gets to the third at 06:45:00.
When filtering to keep entire trips that cross the time of day between
06:30:00 and 06:40:00, all three stops will have to be kept. If,
however, you want to keep only the entries that fall within the
specified time of day, only the first two should be kept. To control
such behaviour you need to set the `full_trips` parameter. When it's
`TRUE`, the function behaves like the first case, and when it's `FALSE`,
like the second.

When using `full_trips` in conjunction with `keep`, please note how
their behaviour stack. When both are `TRUE`, trips are always fully
kept. When `keep` is `FALSE`, however, trips are fully dropped, even if
some of their stops are visited outside the specified time of day.

Finally, please note that many GTFS feeds may contain `stop_times`
entries with empty departure and arrival times. In such cases, filtering
by time of day with `full_trips` as `FALSE` will drop the entries with
empty times. Please set `full_trips` to `TRUE` to preserve these
entries.

## See also

Other filtering functions:
[`filter_by_agency_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_agency_id.md),
[`filter_by_route_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_id.md),
[`filter_by_route_type()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_route_type.md),
[`filter_by_service_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_service_id.md),
[`filter_by_sf()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_sf.md),
[`filter_by_shape_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_shape_id.md),
[`filter_by_spatial_extent()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md),
[`filter_by_stop_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_stop_id.md),
[`filter_by_trip_id()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_trip_id.md),
[`filter_by_weekday()`](https://ipeagit.github.io/gtfstools/dev/reference/filter_by_weekday.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# taking a look at the original frequencies and stop_times
head(gtfs$frequencies)
#>       trip_id start_time end_time headway_secs
#>        <char>     <char>   <char>        <int>
#> 1: CPTM L07-0   04:00:00 04:59:00          720
#> 2: CPTM L07-0   05:00:00 05:59:00          360
#> 3: CPTM L07-0   06:00:00 06:59:00          360
#> 4: CPTM L07-0   07:00:00 07:59:00          360
#> 5: CPTM L07-0   08:00:00 08:59:00          360
#> 6: CPTM L07-0   09:00:00 09:59:00          480
head(gtfs$stop_times)
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     04:00:00       04:00:00   18940             1
#> 2: CPTM L07-0     04:08:00       04:08:00   18920             2
#> 3: CPTM L07-0     04:16:00       04:16:00   18919             3
#> 4: CPTM L07-0     04:24:00       04:24:00   18917             4
#> 5: CPTM L07-0     04:32:00       04:32:00   18916             5
#> 6: CPTM L07-0     04:40:00       04:40:00   18965             6

smaller_gtfs <- filter_by_time_of_day(gtfs, "05:00:00", "06:00:00")

# filter_by_time_of_day filters the frequencies table but doesn't filter the
# stop_times table because they're just templates
head(smaller_gtfs$frequencies)
#>       trip_id start_time end_time headway_secs
#>        <char>     <char>   <char>        <int>
#> 1: CPTM L07-0   05:00:00 05:59:00          360
#> 2: CPTM L07-1   05:00:00 05:59:00          360
#> 3: CPTM L08-0   05:00:00 05:59:00          480
#> 4: CPTM L08-1   05:00:00 05:59:00          480
#> 5: CPTM L09-0   05:00:00 05:59:00          480
#> 6: CPTM L09-1   05:00:00 05:59:00          480
head(smaller_gtfs$stop_times)
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     04:00:00       04:00:00   18940             1
#> 2: CPTM L07-0     04:08:00       04:08:00   18920             2
#> 3: CPTM L07-0     04:16:00       04:16:00   18919             3
#> 4: CPTM L07-0     04:24:00       04:24:00   18917             4
#> 5: CPTM L07-0     04:32:00       04:32:00   18916             5
#> 6: CPTM L07-0     04:40:00       04:40:00   18965             6

# frequencies entries can be adjusted using update_frequencies = TRUE
smaller_gtfs <- filter_by_time_of_day(
  gtfs,
  "05:30:00",
  "06:00:00",
  update_frequencies = TRUE
)
head(smaller_gtfs$frequencies)
#>       trip_id start_time end_time headway_secs
#>        <char>     <char>   <char>        <int>
#> 1: CPTM L07-0   05:30:00 05:59:00          360
#> 2: CPTM L07-1   05:30:00 05:59:00          360
#> 3: CPTM L08-0   05:30:00 05:59:00          480
#> 4: CPTM L08-1   05:30:00 05:59:00          480
#> 5: CPTM L09-0   05:30:00 05:59:00          480
#> 6: CPTM L09-1   05:30:00 05:59:00          480

# when keep = FALSE, the behaviour of the function in general, and of
# update_frequencies in particular, is a bit different
smaller_gtfs <- filter_by_time_of_day(
  gtfs,
  "05:30:00",
  "06:00:00",
  keep = FALSE,
  update_frequencies = TRUE
)
head(smaller_gtfs$frequencies)
#>       trip_id start_time end_time headway_secs
#>        <char>     <char>   <char>        <int>
#> 1: CPTM L07-0   04:00:00 04:59:00          720
#> 2: CPTM L07-0   05:00:00 05:30:00          360
#> 3: CPTM L07-0   06:00:00 06:59:00          360
#> 4: CPTM L07-0   07:00:00 07:59:00          360
#> 5: CPTM L07-0   08:00:00 08:59:00          360
#> 6: CPTM L07-0   09:00:00 09:59:00          480

# let's remove the frequencies table to check the behaviour of full_trips
gtfs$frequencies <- NULL
smaller_gtfs <- filter_by_time_of_day(
  gtfs,
  "05:30:00",
  "06:00:00"
)
head(smaller_gtfs$stop_times)
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     05:36:00       05:36:00   18926            13
#> 2: CPTM L07-0     05:44:00       05:44:00   18971            14
#> 3: CPTM L07-0     05:52:00       05:52:00   18972            15
#> 4: CPTM L07-0     06:00:00       06:00:00   18973            16
#> 5: CPTM L07-1     05:36:00       05:36:00   18965            13
#> 6: CPTM L07-1     05:44:00       05:44:00   18916            14

smaller_gtfs <- filter_by_time_of_day(
  gtfs,
  "05:30:00",
  "06:00:00",
  full_trips = TRUE
)
head(smaller_gtfs$stop_times)
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     04:00:00       04:00:00   18940             1
#> 2: CPTM L07-0     04:08:00       04:08:00   18920             2
#> 3: CPTM L07-0     04:16:00       04:16:00   18919             3
#> 4: CPTM L07-0     04:24:00       04:24:00   18917             4
#> 5: CPTM L07-0     04:32:00       04:32:00   18916             5
#> 6: CPTM L07-0     04:40:00       04:40:00   18965             6
```
