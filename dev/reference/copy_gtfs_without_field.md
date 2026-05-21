# Make a GTFS copy without a given field from a given file

Creates a copy of a GTFS object without a given field from a given file.
Used for testing.

## Usage

``` r
copy_gtfs_without_field(gtfs, file, field)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- file:

  File from which the field must be removed.

- field:

  Field to be removed.

## Value

A GTFS object without the given field.
