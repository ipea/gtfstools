# Parse dates given as `Date`s or strings

Validates a `date` argument given either as a `Date` vector or as a
character vector of dates in the `"YYYYMMDD"` or `"YYYY-MM-DD"` formats
(which may be mixed), and converts it to a `Date` vector.

## Usage

``` r
parse_dates(date, call = parent.frame(), arg = "date")
```

## Arguments

- date:

  The `date` argument to be parsed.

- call:

  The environment of the function whose `date` argument is parsed, in
  which errors are reported.

- arg:

  A string. The name of the argument, used in error messages.

## Value

A `Date` vector.
