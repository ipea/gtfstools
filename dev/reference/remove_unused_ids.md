# Remove unused ids

Removes the ids that the feed doesn't use, with their entries in every
file. A trip is used if it has `stop_times`, and anything that a used
trip refers to, directly or indirectly, is used too. Entries that refer
to removed ids are removed as well, including those in `attributions`
and `translations`. When there are no `fare_rules`, `fare_attributes`
and their agencies are kept, since these fares apply to the whole feed.
Fares v2 and GTFS-Flex files are left unchanged, so they may still refer
to removed ids.

## Usage

``` r
remove_unused_ids(gtfs)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

## Value

The GTFS object without unused ids.

## See also

[`filter_by_trip_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_trip_id.md),
[`remove_duplicates()`](https://ipea.github.io/gtfstools/dev/reference/remove_duplicates.md)

## Examples

``` r
data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
nrow(gtfs$agency)
#> [1] 37

gtfs <- remove_unused_ids(gtfs)
nrow(gtfs$agency)
#> [1] 1
```
