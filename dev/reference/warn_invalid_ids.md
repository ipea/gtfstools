# Warn about ids missing from a table, with cli

The cli counterpart of
[`warn_missing_ids()`](https://ipea.github.io/gtfstools/dev/reference/warn_missing_ids.md),
whose base [`warning()`](https://rdrr.io/r/base/warning.html) text the
older callers keep. Raises a warning of class
`gtfstools_invalid_<id_name>` listing the distinct elements of `id` not
found in `existing_id`.

## Usage

``` r
warn_invalid_ids(id, existing_id, table, id_name)
```

## Arguments

- id:

  A character vector of ids given by the user, or `NULL`.

- existing_id:

  A character vector of the ids that exist in the table.

- table:

  The name of the table, used in the warning message.

- id_name:

  The name of the id field, used in the warning message and in the
  condition class.

## Value

The distinct missing ids, invisibly (`NULL` if `id` is `NULL`).
