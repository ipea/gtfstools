# Download MobilityData's GTFS validator

Downloads MobilityData's command line tool to validate GTFS feeds.

## Usage

``` r
download_validator(path, version = "latest", force = FALSE, quiet = TRUE)
```

## Arguments

- path:

  A string. The directory where the validator should be saved to.

- version:

  A string. The version of the validator that should be downloaded.
  Defaults to `"latest"`, but accepts version numbers as strings (i.e.
  to download version v6.0.0 please enter `"6.0.0"`). Please check
  [MobilityData/gtfs-validator
  releases](https://github.com/MobilityData/gtfs-validator/releases) for
  the full set of available versions.

- force:

  A logical. Whether to overwrite a previously downloaded validator in
  `path`. Defaults to `FALSE`.

- quiet:

  A logical. Whether to hide log messages and progress bars. Defaults to
  `TRUE`.

## Value

Invisibly returns the normalized path to the downloaded validator.

## See also

Other validation:
[`validate_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/validate_gtfs.md)

## Examples

``` r
path <- tempdir()

download_validator(path)

# specifying a specific version
download_validator(path, version = "6.0.0")
```
