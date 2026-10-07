# Interpolate missing stop times

Fills blank `arrival_time`s and `departure_time`s in `stop_times`,
assuming that vehicles travel at a constant speed between consecutive
stops with known times (timepoints).

## Usage

``` r
interpolate_stop_times(gtfs, trip_id = NULL, method = "shapes")
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to have their stop times
  interpolated. If `NULL` (the default), the function interpolates the
  stop times of every `trip_id` in the GTFS.

- method:

  A string, either `"shapes"` (the default) or `"euclidean"`. `"shapes"`
  measures lengths along the trip's shape, described in the `shapes`
  table, while `"euclidean"` measures the straight-line (great-circle)
  distances between consecutive stops. If the GTFS object doesn't have a
  `shapes` table, or if its `trips` table doesn't have a `shape_id`
  column, `"euclidean"` is used instead, with a warning.

## Value

A GTFS object whose `stop_times` has its blank times filled in. The
order of the rows and the other columns are kept. The given GTFS object
is not modified.

## Details

Within each trip, ordered by `stop_sequence`, a stop whose arrival and
departure times are both blank gets a time interpolated linearly on the
distance travelled from the preceding timepoint, as measured by
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md).
In other words, the vehicle travels between two timepoints at a constant
speed: the distance between them divided by the time from the departure
at the first to the arrival at the second. Interpolated stops get equal
arrival and departure times (no dwell time), rounded to the nearest
second. Times past `"24:00:00"` are supported. If the distance between
two timepoints is 0, their times are spread evenly between the stops in
between.

A timepoint with only one of its two times blank gets the other time in
both columns. If `stop_times` has a `timepoint` column, interpolated
stops get `timepoint = 0` (approximate times). The column is not created
if it doesn't exist.

Some stops are left blank, with a warning:

- stops before a trip's first or after its last timepoint, including
  every stop of trips with fewer than two timepoints;

- stops between timepoints whose distance can't be calculated, e.g.
  trips not linked to a shape or stops without coordinates;

- stops between timepoints in which the arrival is earlier than the
  previous departure. This usually happens when times after midnight are
  written as `"00:30:00"` instead of `"24:30:00"`.

Times are blank when they are `NA`, empty or whitespace-only strings, or
`"NA"`. Malformed time strings are left unchanged, with a warning, and
are not used as timepoints. Rows without a `trip_id` are left unchanged.
Times are read from the time strings, and existing `_secs` columns (e.g.
created with
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md))
are updated to match. For trips listed in `frequencies`, the template
times are interpolated.

The `stops` table is required to interpolate times between timepoints,
as well as the `shapes` table and the `shape_id` column in `trips` with
`method = "shapes"` (see
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)).

## See also

[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
[`get_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_speed.md),
[`set_trip_speed()`](https://ipea.github.io/gtfstools/dev/reference/set_trip_speed.md)

## Examples

``` r
data_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
trip <- "T2-1@1#520"

# only the first and last stops of each trip have times
head(gtfs$stop_times[trip_id == trip])
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: T2-1@1#520     05:20:00       05:20:00    3609             1
#> 2: T2-1@1#520                                3608             2
#> 3: T2-1@1#520                                3564             3
#> 4: T2-1@1#520                                6336             4
#> 5: T2-1@1#520                                3633             5
#> 6: T2-1@1#520                                5544             6

# distances measured along the trips' shapes. some trips of this feed have
# times past midnight written as "00:xx:xx", so they are left blank
interpolated_gtfs <- suppressWarnings(interpolate_stop_times(gtfs))
head(interpolated_gtfs$stop_times[trip_id == trip])
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: T2-1@1#520     05:20:00       05:20:00    3609             1
#> 2: T2-1@1#520     05:20:27       05:20:27    3608             2
#> 3: T2-1@1#520     05:22:00       05:22:00    3564             3
#> 4: T2-1@1#520     05:24:02       05:24:02    6336             4
#> 5: T2-1@1#520     05:25:55       05:25:55    3633             5
#> 6: T2-1@1#520     05:26:31       05:26:31    5544             6

# the speed is now known between every pair of consecutive stops
head(get_trip_speed(interpolated_gtfs, trip, by = "segment"))
#>       trip_id segment from_stop_id to_stop_id    speed
#>        <char>   <int>       <char>     <char>    <num>
#> 1: T2-1@1#520       1         3609       3608 18.97450
#> 2: T2-1@1#520       2         3608       3564 19.07504
#> 3: T2-1@1#520       3         3564       6336 19.04637
#> 4: T2-1@1#520       4         6336       3633 19.05867
#> 5: T2-1@1#520       5         3633       5544 19.32197
#> 6: T2-1@1#520       6         5544       3644 18.78885

# straight-line distances between stops, for a single trip
interpolated_gtfs <- interpolate_stop_times(
  gtfs,
  trip_id = trip,
  method = "euclidean"
)
head(interpolated_gtfs$stop_times[trip_id == trip])
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: T2-1@1#520     05:20:00       05:20:00    3609             1
#> 2: T2-1@1#520     05:20:29       05:20:29    3608             2
#> 3: T2-1@1#520     05:21:30       05:21:30    3564             3
#> 4: T2-1@1#520     05:23:27       05:23:27    6336             4
#> 5: T2-1@1#520     05:25:21       05:25:21    3633             5
#> 6: T2-1@1#520     05:26:01       05:26:01    5544             6
```
