# Convert a time of day to seconds and check its order

Converts the `from` and `to` strings of a time of day to seconds after
midnight, raising an error attributed to the calling function if `from`
is not earlier than `to`. Unlike `dwell_time_window()`, both ends are
required and they can't be equal. The callers validate the format of the
strings themselves, so that those errors keep naming the user-facing
function.

## Usage

``` r
time_of_day_window(from, to)
```

## Arguments

- from, to:

  Strings in the "HH:MM:SS" format.

## Value

An integer vector with `from` and `to` in seconds after midnight.
