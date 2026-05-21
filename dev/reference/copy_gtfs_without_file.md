# Make a GTFS copy without a given file

Creates a copy of a GTFS object without a given file. Used for testing.

## Usage

``` r
copy_gtfs_without_file(gtfs, file)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- file:

  File to be removed.

## Value

A GTFS object without the given file.
