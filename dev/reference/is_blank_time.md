# Check which time strings are blank

Check which time strings are blank

## Usage

``` r
is_blank_time(x)
```

## Arguments

- x:

  A character vector of time strings.

## Value

A logical vector, `TRUE` where the time is `NA`, an empty or
whitespace-only string, or `"NA"`.
[`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md)
uses the same rule.
