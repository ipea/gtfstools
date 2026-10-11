# Write and render the report of get_summary()

Write and render the report of get_summary()

## Usage

``` r
write_summary_report(result, values, selection, output_dir)
```

## Arguments

- result:

  The list of diagnostics returned by
  [`get_summary()`](https://ipea.github.io/gtfstools/dev/reference/get_summary.md).

- values:

  A named list with the numeric vectors to be plotted (`speed`,
  `distance` and `frequency`) and the calendar chart created by
  [`get_calendar_overlap()`](https://ipea.github.io/gtfstools/dev/reference/get_calendar_overlap.md)
  (`calendar`, `NULL` if there is none).

- selection:

  A named list with the filters used (`NULL` elements mean no filter).

- output_dir:

  A string. The directory in which the report is saved.

## Value

The path to the HTML report.
