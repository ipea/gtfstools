# Refresh the `*_secs` columns of a table after its time strings changed

Functions that rewrite time strings keep any pre-existing `<time>_secs`
columns in sync, because other functions use these columns as-is (see
[`convert_time_to_seconds()`](https://ipea.github.io/gtfstools/reference/convert_time_to_seconds.md)).
Columns that don't exist are skipped.

## Usage

``` r
refresh_secs_columns(dt, time_cols, rows = NULL)
```

## Arguments

- dt:

  A `data.table`, modified by reference.

- time_cols:

  A character vector with the names of the time string columns (e.g.
  `"departure_time"`).

- rows:

  An integer vector with the rows whose times changed, or `NULL` for all
  rows.

## Value

The table, invisibly.
