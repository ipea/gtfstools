# Get start and end times

Returns the earliest departure time and the latest arrival time listed
in the `stop_times` table, optionally restricted to the given trips
and/or to the trips active on the given dates.

## Usage

``` r
get_start_and_end_times(gtfs, trip_id = NULL, date = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to consider. If `NULL`
  (the default), all trips are considered.

- date:

  A `Date` vector (including `IDate`) or a character vector of dates in
  the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats. If given, only trips whose
  services are active on any of these dates are considered. If `NULL`
  (the default), trips are not restricted by date.

## Value

A named character vector of length 2, with the elements `start_time`
(the earliest `departure_time`) and `end_time` (the latest
`arrival_time`), in the `"HH:MM:SS"` format. Times past midnight keep
hours of 24 and above. If no stop time is considered, or if all their
times are empty, both elements are `NA`, without a warning.

## Details

Times are compared as seconds, not as strings, so `"5:00:00"` comes
before `"10:00:00"` (and is returned as `"05:00:00"`). Empty times are
ignored, and malformed ones are ignored with a warning.

When both `trip_id` and `date` are given, only the given trips that are
active on the given dates are considered. The services active on each
date are found with
[`get_active_services()`](https://ipea.github.io/gtfstools/dev/reference/get_active_services.md).
Trips listed in `stop_times` but not in `trips` are not considered when
`date` is given, and if the GTFS object has no `calendar` nor
`calendar_dates` tables, no trip is active.

The `frequencies` table is not used: the times of frequency-based trips
are taken from their template trips as they are listed in `stop_times`.
To consider all their departures, convert them with
[`frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/frequencies_to_stop_times.md)
first.

## See also

[`get_active_services()`](https://ipea.github.io/gtfstools/dev/reference/get_active_services.md),
[`get_trip_duration()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_duration.md)

## Examples

``` r
data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

get_start_and_end_times(gtfs)
#> start_time   end_time 
#> "04:50:00" "23:18:30" 

get_start_and_end_times(gtfs, trip_id = c("146389748", "146389727"))
#> start_time   end_time 
#> "06:20:00" "07:06:30" 

# restricted to the trips active on a given date
data_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

get_start_and_end_times(gtfs, date = "20060701")
#> start_time   end_time 
#> "00:06:10" "00:06:45" 
```
