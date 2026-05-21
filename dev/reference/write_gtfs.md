# Write GTFS files

Writes GTFS objects as GTFS `.zip` files.

## Usage

``` r
write_gtfs(
  gtfs,
  path,
  files = NULL,
  standard_only = FALSE,
  as_dir = FALSE,
  overwrite = TRUE,
  quiet = TRUE
)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- path:

  The path to the `.zip` file in which the feed should be written to.

- files:

  A character vector containing the name of the elements to be written
  to the feed. If `NULL` (the default), all elements inside the GTFS
  object are written.

- standard_only:

  Whether to write only standard files and fields (defaults to `FALSE`,
  which doesn't drop extra files and fields).

- as_dir:

  Whether to write the feed as a directory, instead of a `.zip` file
  (defaults to `FALSE`, which means that the field is written as a zip
  file).

- overwrite:

  Whether to overwrite existing `.zip` file (defaults to `TRUE`).

- quiet:

  Whether to hide log messages and progress bars (defaults to `TRUE`).

## Value

Invisibly returns the same GTFS object passed to the `gtfs` parameter.

## See also

Other io functions:
[`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

tmp_dir <- file.path(tempdir(), "tmpdir")
dir.create(tmp_dir)
list.files(tmp_dir) #'
#> character(0)
tmp_file <- tempfile(pattern = "gtfs", tmpdir = tmp_dir, fileext = ".zip")
write_gtfs(gtfs, tmp_file)
list.files(tmp_dir)
#> [1] "gtfs1c077d349c4.zip"

gtfs_all_files <- read_gtfs(tmp_file)
names(gtfs_all_files)
#> [1] "agency"      "calendar"    "frequencies" "routes"      "shapes"     
#> [6] "stop_times"  "stops"       "trips"      

write_gtfs(gtfs, tmp_file, files = "stop_times")
gtfs_stop_times <- read_gtfs(tmp_file)
names(gtfs_stop_times)
#> [1] "stop_times"
```
