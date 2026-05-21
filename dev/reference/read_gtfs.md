# Read GTFS files

Reads GTFS text files from either a local `.zip` file or an URL.

## Usage

``` r
read_gtfs(
  path,
  files = NULL,
  fields = NULL,
  skip = NULL,
  quiet = TRUE,
  encoding = "unknown"
)
```

## Arguments

- path:

  The path to a GTFS `.zip` file.

- files:

  A character vector containing the text files to be read from the GTFS
  (without the `.txt` extension). If `NULL` (the default) all existing
  files are read.

- fields:

  A named list containing the fields to be read from each text file, in
  the format `list(file = c("field1", "field2"))`. If `NULL` (the
  default), all fields from the files specified in `files` are read. If
  a file is specified in `files` but not in `fields`, all fields from
  that file will be read (i.e. you may specify in `fields` only files
  whose fields you want to subset).

- skip:

  A character vector containing the text files that should not be read
  from the GTFS, without the `.txt` extension. If `NULL` (the default),
  no files are skipped. Cannot be used if `files` is already set.

- quiet:

  Whether to hide log messages and progress bars (defaults to `TRUE`).

- encoding:

  A string, ultimately passed to
  [`data.table::fread()`](https://rdrr.io/pkg/data.table/man/fread.html).
  Defaults to `"unknown"`. Other possible options are `"UTF-8"` and
  `"Latin-1"`. Please note that this is not used to re-encode the input,
  but to enable handling encoded strings in their native encoding.

## Value

A `data.table`-based GTFS object: a `list` of `data.table`s in which
each table represents a GTFS text file.

## Details

The column types of each `data.table` in the final GTFS object conform
as closely as possible to the [Google's Static GTFS
Reference](https://developers.google.com/transit/gtfs/reference).
Exceptions are date-related columns (such as `calendar.txt`'s
`start_date` and `end_date`, for example), which are converted to `Date`
objects, instead of being kept as `integer`s, allowing for easier data
manipulation. These columns are converted back to `integer`s when
writing the GTFS object to a `.zip` file using
[`write_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/write_gtfs.md).

## See also

Other io functions:
[`write_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/write_gtfs.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)
names(gtfs)
#> [1] "agency"      "calendar"    "frequencies" "routes"      "shapes"     
#> [6] "stop_times"  "stops"       "trips"      

gtfs <- read_gtfs(data_path, files = c("trips", "stop_times"))
names(gtfs)
#> [1] "trips"      "stop_times"

gtfs <- read_gtfs(data_path, skip = "trips")
names(gtfs)
#> [1] "agency"      "calendar"    "frequencies" "routes"      "shapes"     
#> [6] "stop_times"  "stops"      

gtfs <- read_gtfs(data_path, fields = list(agency = "agency_id"))
names(gtfs)
#> [1] "agency"      "calendar"    "frequencies" "routes"      "shapes"     
#> [6] "stop_times"  "stops"       "trips"      
names(gtfs$agency)
#> [1] "agency_id"
```
