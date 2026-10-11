# Summarise a distribution

Summarise a distribution

## Usage

``` r
summarise_distribution(x, unit)
```

## Arguments

- x:

  A numeric vector. `NA`s are ignored.

- unit:

  A string. The unit of `x`.

## Value

A one-row `data.table` with the columns `n` (the number of non-`NA`
values), `min`, `q25`, `median`, `mean`, `q75`, `max` (all `NA` if there
are no non-`NA` values) and `unit`.
