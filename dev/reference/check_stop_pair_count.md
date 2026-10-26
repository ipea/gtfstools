# Check the number of pairs of stops before comparing them

Raises an error if the pairs can't be indexed, and a warning if
comparing them may use a lot of memory (each pair takes about 64 bytes
at the peak).

## Usage

``` r
check_stop_pair_count(n_pairs, max_dist, arg_name, action, call)
```

## Arguments

- n_pairs:

  A number, the pairs of stops to be compared.

- max_dist:

  A number, the distance given by the user, in meters.

- arg_name:

  The name of the user-facing distance argument.

- action:

  A string that starts the warning, e.g. `"Merging stops"`.

- call:

  The environment of the user-facing function, so that the error
  mentions it.

## Value

Invisibly returns `NULL`, if it doesn't raise an error.
