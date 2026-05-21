# Convert frequencies to stop times

Creates `stop_times` entries based on the frequencies specified in the
`frequencies` table.

## Usage

``` r
frequencies_to_stop_times(gtfs, trip_id = NULL, force = FALSE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- trip_id:

  A character vector including the `trip_id`s to have their frequencies
  converted to `stop_times` entries. If `NULL` (the default), the
  function converts all trips listed in the `frequencies` table.

- force:

  Whether to convert trips specified in the `frequencies` table even if
  they are not described in `stop_times` (defaults to `FALSE`). When set
  to `TRUE`, these mismatched trip are removed from the `frequencies`
  table and their correspondent entries in `trips` are substituted by
  what would be their converted counterpart.

## Value

A GTFS object with updated `frequencies`, `stop_times` and `trips`
tables.

## Details

A single trip described in a `frequencies` table may yield multiple
trips after converting the GTFS. Let's say, for example, that the
`frequencies` table describes a trip called `"example_trip"`, that
starts at 08:00 and stops at 09:00, with a 30 minutes headway.

In practice, that means that one trip will depart at 08:00, another at
08:30 and yet another at 09:00. `frequencies_to_stop_times()` appends a
`"_<n>"` suffix to the newly created trips to differentiate each one of
them (e.g. in this case, the new trips, described in the `trips` and
`stop_times` tables, would be called `"example_trip_1"`,
`"example_trip_2"` and `"example_trip_3"`).

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
trip <- "CPTM L07-0"

# converts all trips listed in the frequencies table
converted_gtfs <- frequencies_to_stop_times(gtfs)

# converts only the specified trip_id
converted_gtfs <- frequencies_to_stop_times(gtfs, trip)

# how the specified trip_id was described in the frequencies table
head(gtfs$frequencies[trip_id == trip])
#>       trip_id start_time end_time headway_secs
#>        <char>     <char>   <char>        <int>
#> 1: CPTM L07-0   04:00:00 04:59:00          720
#> 2: CPTM L07-0   05:00:00 05:59:00          360
#> 3: CPTM L07-0   06:00:00 06:59:00          360
#> 4: CPTM L07-0   07:00:00 07:59:00          360
#> 5: CPTM L07-0   08:00:00 08:59:00          360
#> 6: CPTM L07-0   09:00:00 09:59:00          480

# the first row of each equivalent stop_times entry in the converted gtfs
equivalent_stop_times <- converted_gtfs$stop_times[grepl(trip, trip_id)]
equivalent_stop_times[equivalent_stop_times[, .I[1], by = trip_id]$V1]
#>             trip_id arrival_time departure_time stop_id stop_sequence
#>              <char>       <char>         <char>  <char>         <int>
#>   1:   CPTM L07-0_1     04:00:00       04:00:00   18940             1
#>   2:   CPTM L07-0_2     04:12:00       04:12:00   18940             1
#>   3:   CPTM L07-0_3     04:24:00       04:24:00   18940             1
#>   4:   CPTM L07-0_4     04:36:00       04:36:00   18940             1
#>   5:   CPTM L07-0_5     04:48:00       04:48:00   18940             1
#>  ---                                                                 
#> 157: CPTM L07-0_157     23:00:00       23:00:00   18940             1
#> 158: CPTM L07-0_158     23:12:00       23:12:00   18940             1
#> 159: CPTM L07-0_159     23:24:00       23:24:00   18940             1
#> 160: CPTM L07-0_160     23:36:00       23:36:00   18940             1
#> 161: CPTM L07-0_161     23:48:00       23:48:00   18940             1
```
