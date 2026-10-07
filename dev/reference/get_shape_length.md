# Get shape length

Returns the length of each specified `shape_id`, from its first to its
last point.

## Usage

``` r
get_shape_length(gtfs, shape_id = NULL, unit = "km")
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- shape_id:

  A character vector including the `shape_id`s to have their length
  calculated. If `NULL` (the default), the function calculates the
  length of every `shape_id` in the GTFS.

- unit:

  A string representing the unit in which lengths are desired. Either
  `"km"` (the default) or `"m"`.

## Value

A `data.table` with the `shape_id` and the `length` of each shape.

## Details

The points of each shape are sorted by `shape_pt_sequence` before the
length is calculated. Lengths are great-circle distances calculated with
the haversine formula, on a sphere with the same radius used by `{s2}`
(6,371,010 meters), regardless of whether
[`sf::sf_use_s2()`](https://r-spatial.github.io/sf/reference/s2.html) is
enabled. Shapes with any point with missing coordinates have `NA`
lengths.

A trip usually travels only part of its shape, from its first to its
last stop. Use
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)
to calculate the length of the trips.

## See also

[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

shape_length <- get_shape_length(gtfs)
head(shape_length)
#>    shape_id   length
#>      <char>    <num>
#> 1:    17838 20.55210
#> 2:    17839 20.55210
#> 3:    17840 15.05470
#> 4:    17841 15.05486
#> 5:    17842 22.59400
#> 6:    17843 22.59400

shape_length <- get_shape_length(gtfs, c("17846", "68962"), unit = "m")
shape_length
#>    shape_id   length
#>      <char>    <num>
#> 1:    17846 60718.94
#> 2:    68962 26162.11
```
