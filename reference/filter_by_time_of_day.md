# Filter GTFS object by time of day

Filters a GTFS object by time of day, keeping (or dropping) the
`stop_times` and `frequencies` entries within it, and keeping the
entries of the other tables related to the trips that remain.

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
  [`read_gtfs()`](https://ipea.github.io/gtfstools/reference/read_gtfs.md).

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
  specified time of day (defaults to `TRUE`, which updates the fields).

## Value

The GTFS object passed to the `gtfs` parameter, after the filtering
process.

## Details

The time of day includes both `from` and `to`.

Trips listed in `frequencies` are filtered through their `frequencies`
entries; their `stop_times` entries are templates and are kept whatever
their times. With `keep = TRUE`, the entries that overlap the time of
day are kept; with `keep = FALSE`, those entirely within it are dropped.
With `update_frequencies = TRUE` and `keep = TRUE`, an entry that starts
before `from` starts at `from` (or, if `exact_times` is 1, at its first
departure at or after `from`), and an entry that ends after `to` ends
one second after `to`, so that a departure exactly at `to` is kept. With
`update_frequencies = TRUE` and `keep = FALSE`, an entry that crosses
`from` ends at `from`, an entry that crosses `to` starts one second
after `to` (or, if `exact_times` is 1, at its first departure after
`to`), and an entry that spans the whole time of day is split in two.
Entries left without any departure are removed, and trips left without
any entry are dropped from the feed.

The other trips are filtered through their `stop_times` entries, which
are within the time of day when the visit, from `arrival_time` to
`departure_time`, overlaps it (a blank time is ignored when the other is
known). With `full_trips = FALSE`, each entry is kept or dropped on its
own, and entries with both times blank (or, with `keep = FALSE`, either)
are dropped. With `full_trips = TRUE`, a trip with any entry within the
time of day is kept (`keep = TRUE`) or dropped (`keep = FALSE`) as a
whole, including its blank entries. The other tables are then filtered
to the trips left in `stop_times`, as in
[`filter_by_trip_id()`](https://ipea.github.io/gtfstools/reference/filter_by_trip_id.md),
with a warning if `stop_times` lists trips missing from `trips`.

Existing `_secs` columns in `stop_times` and `frequencies` (e.g. created
with
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md))
are used as-is, not recalculated from the time strings.

## See also

Other filtering functions:
[`filter_by_agency_id()`](https://ipea.github.io/gtfstools/reference/filter_by_agency_id.md),
[`filter_by_date()`](https://ipea.github.io/gtfstools/reference/filter_by_date.md),
[`filter_by_period()`](https://ipea.github.io/gtfstools/reference/filter_by_period.md),
[`filter_by_route_id()`](https://ipea.github.io/gtfstools/reference/filter_by_route_id.md),
[`filter_by_route_type()`](https://ipea.github.io/gtfstools/reference/filter_by_route_type.md),
[`filter_by_service_id()`](https://ipea.github.io/gtfstools/reference/filter_by_service_id.md),
[`filter_by_shape_id()`](https://ipea.github.io/gtfstools/reference/filter_by_shape_id.md),
[`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/reference/filter_by_spatial_extent.md),
[`filter_by_stop_id()`](https://ipea.github.io/gtfstools/reference/filter_by_stop_id.md),
[`filter_by_trip_id()`](https://ipea.github.io/gtfstools/reference/filter_by_trip_id.md),
[`filter_by_weekday()`](https://ipea.github.io/gtfstools/reference/filter_by_weekday.md)

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
#> 2: CPTM L07-0   06:00:00 06:00:01          360
#> 3: CPTM L07-1   05:00:00 05:59:00          360
#> 4: CPTM L07-1   06:00:00 06:00:01          360
#> 5: CPTM L08-0   05:00:00 05:59:00          480
#> 6: CPTM L08-0   06:00:00 06:00:01          300
head(smaller_gtfs$stop_times)
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     04:00:00       04:00:00   18940             1
#> 2: CPTM L07-0     04:08:00       04:08:00   18920             2
#> 3: CPTM L07-0     04:16:00       04:16:00   18919             3
#> 4: CPTM L07-0     04:24:00       04:24:00   18917             4
#> 5: CPTM L07-0     04:32:00       04:32:00   18916             5
#> 6: CPTM L07-0     04:40:00       04:40:00   18965             6

# frequencies entries are adjusted by default. use update_frequencies =
# FALSE to keep their original times
smaller_gtfs <- filter_by_time_of_day(
  gtfs,
  "05:30:00",
  "06:00:00",
  update_frequencies = FALSE
)
head(smaller_gtfs$frequencies)
#>       trip_id start_time end_time headway_secs
#>        <char>     <char>   <char>        <int>
#> 1: CPTM L07-0   05:00:00 05:59:00          360
#> 2: CPTM L07-0   06:00:00 06:59:00          360
#> 3: CPTM L07-1   05:00:00 05:59:00          360
#> 4: CPTM L07-1   06:00:00 06:59:00          360
#> 5: CPTM L08-0   05:00:00 05:59:00          480
#> 6: CPTM L08-0   06:00:00 06:59:00          300

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
#> 3: CPTM L07-0   06:00:01 06:59:00          360
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
