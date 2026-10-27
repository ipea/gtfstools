# Sum a vector, or return NA if it has no values

Sum a vector, or return NA if it has no values

## Usage

``` r
sum_or_na(x)
```

## Arguments

- x:

  A numeric vector. Non-finite values (`NA`, `Inf`, `-Inf`) are ignored.

## Value

The sum of the finite values of `x`, or `NA` if there are none.
