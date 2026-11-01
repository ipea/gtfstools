# Fix times after midnight written as early morning times

Rewrites the times after midnight of trips that run past it, when they
are written as early morning times (e.g. `"00:10:00"` after
`"23:50:00"`), as times past `"24:00:00"` (e.g. `"24:10:00"`), as
required by the GTFS specification. All gtfstools functions that
calculate or edit durations and speeds or use information on time of day
use `fix_overnight_times()` internally to fix the overnight times.

## Usage

``` r
fix_overnight_times(gtfs)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

## Value

A GTFS object with the time columns of its `stop_times` and the
`end_time` column of its `frequencies` fixed.

## Details

The arrival and departure times of each trip are read in order of
`stop_sequence`, ignoring blank times. A time more than 12 hours earlier
than the previous time of its trip is taken as a time after midnight, so
it and the later times of the trip are moved one day later (e.g.
`"00:10:00"` becomes `"24:10:00"`). Trips that run past a second
midnight are moved two days, and so on. A time more than 12 hours later
than the previous time of its trip undoes one of these days, so feeds
that mix both forms are also fixed (e.g. `"24:30:00"`, `"00:40:00"`,
`"24:50:00"` becomes `"24:30:00"`, `"24:40:00"`, `"24:50:00"`), and
trips whose times already follow the specification are left unchanged.
Blank times are kept blank. Only `stop_times` and `frequencies` are
modified; their existing `_secs` columns are updated to match.

Times earlier than the previous time of their trip by 12 hours or less
are left unchanged, with a warning. Times are never moved earlier, so
trips with known times more than 12 hours apart that follow the
specification (e.g. `"06:00:00"`, `"19:30:00"`) are left unchanged. Rows
with a missing `trip_id` or `stop_sequence` are left unchanged, and
stops with duplicated `stop_sequence`s are read in the order of their
rows (see
[`remove_duplicates()`](https://ipea.github.io/gtfstools/dev/reference/remove_duplicates.md)).

Trips whose times are all written after midnight as early morning times
(e.g. a trip of the previous service day departing at `"00:30:00"`)
can't be told apart from trips of the service day and are left
unchanged.

In `frequencies`, an `end_time` earlier than the `start_time` of its row
is moved by whole days to the first time later than the `start_time`
(e.g. `"23:00:00"`-`"01:00:00"` becomes `"23:00:00"`-`"25:00:00"`). A
`start_time` written as an early morning time is left unchanged. The
template times of trips listed in `frequencies` are fixed as any other
times, which doesn't change their departures, since only the differences
between them are used.

An error is raised if a fixed time would be later than `"9999:59:59"`.

## See also

[`fix_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/fix_gtfs.md),
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md)

## Examples

``` r
library(dplyr)

data_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

# this trip runs past midnight, but its last time is written as "00:02:00"
gtfs$stop_times |>
  filter(trip_id == "T2-1@1#2310", arrival_time != "") |>
  select(trip_id, stop_sequence, arrival_time, departure_time)
#>        trip_id stop_sequence arrival_time departure_time
#>         <char>         <int>       <char>         <char>
#> 1: T2-1@1#2310             1     23:10:00       23:10:00
#> 2: T2-1@1#2310            62     00:02:00       00:02:00

fixed_gtfs <- fix_overnight_times(gtfs)

fixed_gtfs$stop_times |>
  filter(trip_id == "T2-1@1#2310", arrival_time != "") |>
  select(trip_id, stop_sequence, arrival_time, departure_time)
#>        trip_id stop_sequence arrival_time departure_time
#>         <char>         <int>       <char>         <char>
#> 1: T2-1@1#2310             1     23:10:00       23:10:00
#> 2: T2-1@1#2310            62     24:02:00       24:02:00
```
