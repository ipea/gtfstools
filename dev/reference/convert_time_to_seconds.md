# Convert time fields to seconds after midnight

Converts `stop_times`' and `frequencies`' fields in the "HH:MM:SS"
format to seconds after midnight. Instead of overwritting the existing
fields, creates new fields with the `_secs` suffix.

## Usage

``` r
convert_time_to_seconds(gtfs, file = NULL, by_reference = FALSE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- file:

  A character vector, specifying the file whose fields should be
  converted. If `NULL` (the default), the function attempts to convert
  the times from both files, but only raises an error if none of them
  exist.

- by_reference:

  Whether to update the tables by reference. Defaults to `FALSE`.

## Value

If `by_reference` is `FALSE`, returns a GTFS object with additional time
in seconds columns (identified by a `_secs` suffix). Else, returns a
GTFS object invisibly (please note that in such case the original GTFS
object is altered).

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

# by default converts both 'stop_times' and 'frequencies' times
converted_gtfs <- convert_time_to_seconds(gtfs)
head(converted_gtfs$stop_times)
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     04:00:00       04:00:00   18940             1
#> 2: CPTM L07-0     04:08:00       04:08:00   18920             2
#> 3: CPTM L07-0     04:16:00       04:16:00   18919             3
#> 4: CPTM L07-0     04:24:00       04:24:00   18917             4
#> 5: CPTM L07-0     04:32:00       04:32:00   18916             5
#> 6: CPTM L07-0     04:40:00       04:40:00   18965             6
#>    departure_time_secs arrival_time_secs
#>                  <int>             <int>
#> 1:               14400             14400
#> 2:               14880             14880
#> 3:               15360             15360
#> 4:               15840             15840
#> 5:               16320             16320
#> 6:               16800             16800
head(converted_gtfs$frequencies)
#>       trip_id start_time end_time headway_secs start_time_secs end_time_secs
#>        <char>     <char>   <char>        <int>           <int>         <int>
#> 1: CPTM L07-0   04:00:00 04:59:00          720           14400         17940
#> 2: CPTM L07-0   05:00:00 05:59:00          360           18000         21540
#> 3: CPTM L07-0   06:00:00 06:59:00          360           21600         25140
#> 4: CPTM L07-0   07:00:00 07:59:00          360           25200         28740
#> 5: CPTM L07-0   08:00:00 08:59:00          360           28800         32340
#> 6: CPTM L07-0   09:00:00 09:59:00          480           32400         35940

# choose which table to convert with 'file'
converted_gtfs <- convert_time_to_seconds(gtfs, file = "frequencies")
head(converted_gtfs$stop_times)
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     04:00:00       04:00:00   18940             1
#> 2: CPTM L07-0     04:08:00       04:08:00   18920             2
#> 3: CPTM L07-0     04:16:00       04:16:00   18919             3
#> 4: CPTM L07-0     04:24:00       04:24:00   18917             4
#> 5: CPTM L07-0     04:32:00       04:32:00   18916             5
#> 6: CPTM L07-0     04:40:00       04:40:00   18965             6
head(converted_gtfs$frequencies)
#>       trip_id start_time end_time headway_secs start_time_secs end_time_secs
#>        <char>     <char>   <char>        <int>           <int>         <int>
#> 1: CPTM L07-0   04:00:00 04:59:00          720           14400         17940
#> 2: CPTM L07-0   05:00:00 05:59:00          360           18000         21540
#> 3: CPTM L07-0   06:00:00 06:59:00          360           21600         25140
#> 4: CPTM L07-0   07:00:00 07:59:00          360           25200         28740
#> 5: CPTM L07-0   08:00:00 08:59:00          360           28800         32340
#> 6: CPTM L07-0   09:00:00 09:59:00          480           32400         35940

# original gtfs remained unchanged, as seen with the frequencies table above
# change original object without creating a copy with 'by_reference = TRUE'
convert_time_to_seconds(gtfs, by_reference = TRUE)
head(gtfs$stop_times)
#>       trip_id arrival_time departure_time stop_id stop_sequence
#>        <char>       <char>         <char>  <char>         <int>
#> 1: CPTM L07-0     04:00:00       04:00:00   18940             1
#> 2: CPTM L07-0     04:08:00       04:08:00   18920             2
#> 3: CPTM L07-0     04:16:00       04:16:00   18919             3
#> 4: CPTM L07-0     04:24:00       04:24:00   18917             4
#> 5: CPTM L07-0     04:32:00       04:32:00   18916             5
#> 6: CPTM L07-0     04:40:00       04:40:00   18965             6
#>    departure_time_secs arrival_time_secs
#>                  <int>             <int>
#> 1:               14400             14400
#> 2:               14880             14880
#> 3:               15360             15360
#> 4:               15840             15840
#> 5:               16320             16320
#> 6:               16800             16800
head(gtfs$frequencies)
#>       trip_id start_time end_time headway_secs start_time_secs end_time_secs
#>        <char>     <char>   <char>        <int>           <int>         <int>
#> 1: CPTM L07-0   04:00:00 04:59:00          720           14400         17940
#> 2: CPTM L07-0   05:00:00 05:59:00          360           18000         21540
#> 3: CPTM L07-0   06:00:00 06:59:00          360           21600         25140
#> 4: CPTM L07-0   07:00:00 07:59:00          360           25200         28740
#> 5: CPTM L07-0   08:00:00 08:59:00          360           28800         32340
#> 6: CPTM L07-0   09:00:00 09:59:00          480           32400         35940
```
