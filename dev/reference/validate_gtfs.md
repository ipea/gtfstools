# Validate GTFS feed

Uses MobilityData's [GTFS
validator](https://github.com/MobilityData/gtfs-validator) to perform a
GTFS business rule validation. The results are available as an HTML
report (if validator v3.1.0 or higher is used) and in JSON format.
Please check the complete set of rules used in the validation
[here](https://github.com/MobilityData/gtfs-validator/blob/master/RULES.md).
Please note that this function requires a working installation of Java
11 or higher to work.

## Usage

``` r
validate_gtfs(
  gtfs,
  output_path,
  validator_path,
  overwrite = TRUE,
  html_preview = TRUE,
  pretty_json = FALSE,
  quiet = TRUE,
  n_threads = 1
)
```

## Arguments

- gtfs:

  The GTFS to be validated. Can be in the format of a GTFS object, of a
  path to a GTFS file, of a path to a directory or an URL to a feed.

- output_path:

  A string. The path to the directory that the validator will create and
  in which the results will be saved to.

- validator_path:

  A string. The path to the GTFS validator, previously downloaded with
  [`download_validator()`](https://ipeagit.github.io/gtfstools/dev/reference/download_validator.md).

- overwrite:

  A logical. Whether to overwrite existing validation results in
  `output_path`. Defaults to `TRUE`.

- html_preview:

  A logical. Whether to show HTML report in a viewer, such as RStudio or
  a browser. Defaults to `TRUE` (only works on interactive sessions).

- pretty_json:

  A logical. Whether JSON results should be printed in a readable way,
  that allows it to be inspected without manually formatting. Defaults
  to `FALSE`.

- quiet:

  A logical. Whether to hide informative messages. Defaults to `TRUE`.

- n_threads:

  An integer between 1 and the number of cores in the running machine.
  Control how many threads are used during the validation. Defaults to
  using all but one of the available cores.

## Value

Invisibly returns the normalized path to the directory where the
validation results were saved to.

## See also

Other validation:
[`download_validator()`](https://ipeagit.github.io/gtfstools/dev/reference/download_validator.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
output_path <- tempfile("validation_result")
validator_path <- download_validator(tempdir())
gtfs <- read_gtfs(data_path)

validate_gtfs(gtfs, output_path, validator_path)
list.files(output_path)
#> [1] "report.html"           "report.json"           "system_errors.json"   
#> [4] "validation_stderr.txt"

# works with feeds saved to disk
new_output_path <- tempfile("new_validation_result")
validate_gtfs(data_path, new_output_path, validator_path)
list.files(new_output_path)
#> [1] "report.html"           "report.json"           "system_errors.json"   
#> [4] "validation_stderr.txt"

# and with feeds pointed by an url
newer_output_path <- tempfile("newer_validation_result")
gtfs_url <- "https://github.com/ipeaGIT/gtfstools/raw/main/inst/extdata/spo_gtfs.zip"
validate_gtfs(gtfs_url, newer_output_path, validator_path)
list.files(newer_output_path)
#> [1] "report.html"           "report.json"           "system_errors.json"   
#> [4] "validation_stderr.txt"
```
