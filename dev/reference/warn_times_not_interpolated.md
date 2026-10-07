# Warn about stop times that couldn't be interpolated

Warn about stop times that couldn't be interpolated

## Usage

``` r
warn_times_not_interpolated(n_left, left_trips, back_trips)
```

## Arguments

- n_left:

  The number of stop times left blank.

- left_trips:

  The trips with blank stop times outside two timepoints or whose
  distances couldn't be calculated.

- back_trips:

  The trips with blank stop times between timepoints in which the
  arrival is earlier than the previous departure.

## Value

Invisibly returns `NULL`. Called for its warning.
