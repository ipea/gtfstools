# Map the deprecated `file` argument to `method`

Raises a deprecation warning and returns the `method` that corresponds
to the given `file`.

## Usage

``` r
map_deprecated_file(
  file,
  fn_name,
  details = paste0("Lengths are now measured from the first ",
    "to the last stop of each trip. Use ", "{.fun get_shape_length} to calculate the ",
    "length of the entire shapes.")
)
```

## Arguments

- file:

  The value given to the deprecated `file` argument.

- fn_name:

  The name of the function whose argument is deprecated.

- details:

  A string describing how the results differ from those obtained with
  `file`.

## Value

Either `"shapes"`, if `"shapes"` is included in `file`, or
`"euclidean"`.
