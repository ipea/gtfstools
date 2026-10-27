# Warn about ids missing from a table

Raises a warning listing the elements of `id` not found in
`existing_id`. The warning is attributed to the function that called
this helper.

## Usage

``` r
warn_missing_ids(id, existing_id, table, id_name)
```

## Arguments

- id:

  A character vector of ids given by the user.

- existing_id:

  A character vector of the ids that exist in the table.

- table:

  The name of the table, used in the warning message.

- id_name:

  The name of the id field, used in the warning message.

## Value

The missing ids, invisibly.
