# Get parent stations recursively

Returns the (recursive) parent stations of each specified `stop_id`.
Recursive in this context means it returns all parents' parents (i.e.
first parents, then parents' parents, and then their parents, and so
on).

## Usage

``` r
get_parent_station(gtfs, stop_id = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- stop_id:

  A string vector including the `stop_id`s to have their parents
  returned. If `NULL` (the default), the function returns the parents of
  every `stop_id` in the GTFS.

## Value

A `data.table` containing the `stop_id`s and their `parent_station`s. If
a stop doesn't have a parent, its correspondent `parent_station` entry
is marked as `""`.

## See also

[`get_children_stops()`](https://ipeagit.github.io/gtfstools/dev/reference/get_children_stops.md)

## Examples

``` r
data_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")

gtfs <- read_gtfs(data_path)

parents <- get_parent_station(gtfs)
head(parents)
#>    stop_id parent_station
#>     <char>         <char>
#> 1:     F12               
#> 2:      E1            F12
#> 3:      E2            F12
#> 4:      E3            F12
#> 5:      E4            F12
#> 6:      E5            F12

# use the stop_id argument to control which stops are analyzed
parents <- get_parent_station(gtfs, c("B1", "B2"))
parents
#>    stop_id parent_station
#>     <char>         <char>
#> 1:      B1           F12S
#> 2:      B2           F12N
#> 3:    F12S            F12
#> 4:    F12N            F12
#> 5:     F12               
```
