# Make a GTFS copy with a field of a different class

Creates a copy of a GTFS object while changing the class of a given
field. Used for testing.

## Usage

``` r
copy_gtfs_diff_field_class(gtfs, file, field, class)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- file:

  File whose field must have the class changed.

- field:

  Field to have the class changed.

- class:

  The desired class.

## Value

A GTFS object with the field of desired class.
