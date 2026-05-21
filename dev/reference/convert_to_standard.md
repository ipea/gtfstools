# Convert a gtfstools' GTFS into a standards-compliant GTFS

Converts a gtfstools' GTFS into a standards-compliant GTFS (i.e. date
fields are converted from Date to integer).

## Usage

``` r
convert_to_standard(gtfs)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

## Value

The GTFS object passed to the `gtfs` parameter, after converting the
relevant fields.
