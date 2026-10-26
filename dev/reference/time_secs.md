# Get the times of a column in seconds after midnight

Returns the existing `<time_col>_secs` column as-is when the table has
one (other functions use these columns as-is, see
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/dev/reference/convert_time_to_seconds.md))
and converts the time strings otherwise. The vector returned may be the
table's own column, so callers must only read it or put it in a new
table.

## Usage

``` r
time_secs(dt, time_col)
```

## Arguments

- dt:

  A `data.table` with a time column (e.g. `stop_times`).

- time_col:

  The name of the time string column (e.g. `"departure_time"`).

## Value

An integer (or, from an existing column, possibly double) vector of
seconds after midnight.
