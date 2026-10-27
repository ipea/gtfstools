# Raise the deprecation condition of the `sort_sequence` argument

`sort_sequence` was deprecated after gtfstools 1.4.0: the functions that
took it now always sort by the sequence columns. Passing `TRUE` raises a
warning, and passing `FALSE` raises an error.

## Usage

``` r
check_deprecated_sort_sequence(sort_sequence, fn_name, columns)
```

## Arguments

- sort_sequence:

  The value passed by the user.

- fn_name:

  The name of the function the argument was passed to.

- columns:

  The sequence columns the function sorts by.

## Value

Invisibly returns `NULL`, if it doesn't raise an error.
