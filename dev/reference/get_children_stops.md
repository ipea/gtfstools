# Get children stops recursively

Returns the (recursive) children stops of each specified `stop_id`.
Recursive in this context means it returns all children's children (i.e.
first children, then children's children, and then their children, and
so on).

## Usage

``` r
get_children_stops(gtfs, stop_id = NULL)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

- stop_id:

  A string vector including the `stop_id`s to have their children
  returned. If `NULL` (the default), the function returns the children
  of every `stop_id` in the GTFS.

## Value

A `data.table` containing the `stop_id`s and their children' `stop_id`s.
If a stop doesn't have a child, its correspondent `child_id` entry is
marked as `""`.

## Examples

``` r
data_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

children <- get_children_stops(gtfs)
head(children)
#>    stop_id child_id
#>     <char>   <char>
#> 1:     F12       E1
#> 2:     F12       E2
#> 3:     F12       E3
#> 4:     F12       E4
#> 5:     F12       E5
#> 6:     F12       N1

# use the stop_id argument to control which stops are analyzed
children <- get_children_stops(gtfs, stop_id = c("F12S", "F12N"))
children
#>    stop_id child_id
#>     <char>   <char>
#> 1:    F12S       B1
#> 2:    F12S       B3
#> 3:    F12N       B2
#> 4:    F12N       B4
#> 5:      B1         
#> 6:      B3         
#> 7:      B2         
#> 8:      B4         
```
