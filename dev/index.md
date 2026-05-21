# gtfstools

[![CRAN
status](https://www.r-pkg.org/badges/version/gtfstools)](https://CRAN.R-project.org/package=gtfstools)
[![gtfstools status
badge](https://dhersz.r-universe.dev/badges/gtfstools)](https://dhersz.r-universe.dev)
[![B
status](https://github.com/ipeaGIT/gtfstools/workflows/check/badge.svg)](https://github.com/ipeaGIT/gtfstools/actions?query=workflow%3Acheck)
[![Codecov test
coverage](https://codecov.io/gh/ipeaGIT/gtfstools/branch/main/graph/badge.svg)](https://app.codecov.io/gh/ipeaGIT/gtfstools?branch=main)
[![Lifecycle:
experimental](https://lifecycle.r-lib.org/articles/figures/lifecycle-stable.svg)](https://lifecycle.r-lib.org/articles/stages.html)
[![CRAN/METACRAN Total
downloads](http://cranlogs.r-pkg.org/badges/grand-total/gtfstools?color=yellow)](https://CRAN.R-project.org/package=gtfstools)

**gtfstools** offers a set of convenient tools for editing and analysing
transit feeds in GTFS format. Feeds are read as a `list` of
`data.table`s, allowing for easy and fast data manipulation. Many of
this package’s features are based on functions from other packages,
especially [`{tidytransit}`](https://github.com/r-transit/tidytransit)
and [`{gtfs2gps}`](https://github.com/ipeaGIT/gtfs2gps).

## Installation

Stable version:

``` r

install.packages("gtfstools")
```

Development version:

``` r

# either
install.packages("gtfstools", repos = "https://dhersz.r-universe.dev")

# or
# install.packages("remotes")
remotes::install_github("ipeaGIT/gtfstools")
```

This package requires a working installation of
[`{sf}`](https://github.com/r-spatial/sf). Please check [this
link](https://github.com/r-spatial/sf#installing) for more information
on how to install it.

## Usage

Please read **gtfstools** vignettes for more on the package usage:

- Basic usage: reading, analysing, manipulating and writing feeds. Run
  [`vignette("gtfstools")`](https://ipeagit.github.io/gtfstools/dev/articles/gtfstools.md)
  or check it on the website ([Introduction to
  gtfstools](https://ipeagit.github.io/gtfstools/articles/gtfstools.html)).
- Filtering GTFS feeds. Run
  [`vignette("filtering", package = "gtfstools")`](https://ipeagit.github.io/gtfstools/dev/articles/filtering.md)
  or check it on the website ([Filtering GTFS
  feeds](https://ipeagit.github.io/gtfstools/articles/filtering.html)).
- Validating GTFS feeds. Run
  [`vignette("validating", package = "gtfstools")`](https://ipeagit.github.io/gtfstools/dev/articles/validating.md)
  or check it on the website ([Validating GTFS
  feeds](https://ipeagit.github.io/gtfstools/articles/validating.html)).

## Related packages

- [`{tidytransit}`](https://github.com/r-transit/tidytransit)
- [`{gtfs2gps}`](https://github.com/ipeaGIT/gtfs2gps)
- [`{gtfsrouter}`](https://github.com/UrbanAnalyst/gtfsrouter)

## Acknowledgement [![IPEA](reference/figures/ipea_logo.png)](https://www.ipea.gov.br)

**gtfstools** is developed by a team at the Institute for Applied
Economic Research (Ipea), Brazil.
