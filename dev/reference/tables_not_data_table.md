# Which tables of a GTFS object are data.frames but not data.tables

Tables edited with other tools (e.g.
[`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html))
may lose the `data.table` class. Elements that are not data.frames at
all (e.g. the `.` list of extra tables) are not flagged.

## Usage

``` r
tables_not_data_table(gtfs)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

## Value

A logical vector with one element per element of `gtfs`.
