# Collapse days into periods of consecutive days

Collapse days into periods of consecutive days

## Usage

``` r
dates_to_periods(dates)
```

## Arguments

- dates:

  A sorted `Date` vector of unique days.

## Value

A `data.table` with the columns `start_date`, `end_date` and `n_days`,
with one row per period of consecutive days.
