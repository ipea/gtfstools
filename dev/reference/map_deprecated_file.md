# Map the deprecated `file` argument to `method`

Raises a deprecation warning and returns the `method` that corresponds
to the given `file`.

## Usage

``` r
map_deprecated_file(file, fn_name)
```

## Arguments

- file:

  The value given to the deprecated `file` argument.

- fn_name:

  The name of the function whose argument is deprecated.

## Value

Either `"shapes"`, if `"shapes"` is included in `file`, or
`"euclidean"`.
