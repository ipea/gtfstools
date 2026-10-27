# Convert seconds after midnight to time strings

Converts times in seconds after midnight to strings in the "HH:MM:SS"
format, as used in `stop_times` and `frequencies`. It is the counterpart
of
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md),
useful to write back times calculated from the `_secs` columns.

## Usage

``` r
convert_seconds_to_time(seconds)
```

## Arguments

- seconds:

  A numeric vector with whole numbers of seconds after midnight, between
  0 and 35999999 (`"9999:59:59"`). Values within floating-point
  tolerance of a whole number are rounded. `difftime` objects are
  converted to seconds first.

## Value

A character vector with the same length as `seconds`. `NA`s are
converted to `""`, as blank times in GTFS. Times past midnight keep
counting the hours (e.g. `"25:30:00"`). Names are dropped.

## See also

[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md)

## Examples

``` r
convert_seconds_to_time(c(0, 3600, 91800, NA))
#> [1] "00:00:00" "01:00:00" "25:30:00" ""        

data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
gtfs <- convert_time_to_seconds(gtfs, file = "stop_times")

# delay every departure by 5 minutes
delayed_departure <- convert_seconds_to_time(
  gtfs$stop_times$departure_time_secs + 300
)
head(delayed_departure)
#> [1] "04:05:00" "04:13:00" "04:21:00" "04:29:00" "04:37:00" "04:45:00"
```
