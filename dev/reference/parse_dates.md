# Parse dates given as `Date`s or strings

Validates a `date` argument given either as a `Date` vector or as a
character vector of dates in the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats
(which may be mixed), and converts it to a `Date` vector.

## Usage

``` r
parse_dates(date, call = parent.frame())
```

## Arguments

- date:

  The `date` argument to be parsed.

- call:

  The environment of the function whose `date` argument is parsed, in
  which errors are reported.

## Value

A `Date` vector.
