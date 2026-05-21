# Coerce lists and GTFS objects from other packages into gtfstools-compatible GTFS objects

Coerces an existing object, such as a `list` or a GTFS object created
from other packages (`{tidytransit}` and `{gtfsio}`, for example) into a
gtfstools-compatible GTFS object - i.e. one whose internal tables are
represented with `data.table`s and whose fields are formatted like the
fields of a feed read with
[`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

`as_dt_gtfs()` is an S3 generic, with methods for:

- `tidygtfs`: the class of GTFS objects read with
  `tidytransit::read_gtfs()`. This method converts all `tibble`s to
  `data.table`s and convert time columns, represented as `hms` objects
  in a `tidygtfs`, to strings in the `"HH:MM:SS"` format.

- `gtfs`: the class of GTFS objects read with
  [`gtfsio::import_gtfs()`](https://r-transit.github.io/gtfsio/reference/import_gtfs.html).
  This method convert all date fields, represented as `integer`s in
  `{gtfsio}`'s representation, to `Date` objects.

- `list`: this method tries to convert the elements of a list into
  `data.table`s. Please note that all list elements must inherit from
  `data.frame` and must be named. This method does not try not convert
  fields to the representation used in `{gtfstools}`, as it does not
  have any information on how they are formatted in the first place.

## Usage

``` r
as_dt_gtfs(gtfs, ...)

# S3 method for class 'tidygtfs'
as_dt_gtfs(gtfs, calculate_distance = TRUE, ...)

# S3 method for class 'gtfs'
as_dt_gtfs(gtfs, ...)

# S3 method for class 'list'
as_dt_gtfs(gtfs, ...)
```

## Arguments

- gtfs:

  The object that should be coerced to a `dt_gtfs`.

- ...:

  Ignored.

- calculate_distance:

  A logical. Passed to
  [`convert_sf_to_shapes()`](https://ipeagit.github.io/gtfstools/dev/reference/convert_sf_to_shapes.md),
  which only affects the output when the object to be converted includes
  a `shapes` element. Controls whether this function, used to convert a
  `LINESTRING sf` into a GTFS `shapes` table, should calculate and
  populate the `shape_dist_traveled` column. This column is used to
  describe the distance along the shape from each one of its points to
  its first point. Defaults to `TRUE`.

## Value

A `dt_gtfs` GTFS object.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

gtfsio_gtfs <- gtfsio::import_gtfs(data_path)
class(gtfsio_gtfs)
#> [1] "gtfs" "list"

gtfstools_gtfs <- as_dt_gtfs(gtfsio_gtfs)
class(gtfstools_gtfs)
#> [1] "dt_gtfs" "gtfs"    "list"   

gtfs_like_list <- unclass(gtfsio_gtfs)
class(gtfs_like_list)
#> [1] "list"

gtfstools_gtfs <- as_dt_gtfs(gtfs_like_list)
class(gtfstools_gtfs)
#> [1] "dt_gtfs" "gtfs"    "list"   
```
