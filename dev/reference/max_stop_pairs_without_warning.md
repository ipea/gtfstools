# Maximum number of stop pairs without a warning

The number of pairs of stops above which
[`get_stop_distances()`](https://ipea.github.io/gtfstools/dev/reference/get_stop_distances.md)
warns about its memory use: 15 million pairs, which take about 1 GB at
the peak (about 5,500 stops). A function, so tests can lower it.

## Usage

``` r
max_stop_pairs_without_warning()
```

## Value

A number.
