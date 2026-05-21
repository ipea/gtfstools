# Convert a standards-compliant GTFS into a gtfstools' GTFS

Converts a standards-compliant GTFS into a gtfstools' GTFS (i.e. one in
which date fields are Date objects, not integers).

## Usage

``` r
convert_from_standard(gtfs)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

## Value

The GTFS object passed to the `gtfs` parameter, after converting the
relevant fields.
