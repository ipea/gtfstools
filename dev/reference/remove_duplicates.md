# Remove duplicated entries

Removes duplicated entries from GTFS objects tables.

## Usage

``` r
remove_duplicates(gtfs)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipeagit.github.io/gtfstools/dev/reference/read_gtfs.md).

## Value

A GTFS object containing only unique entries.

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

# this gtfs includes some duplicated entries
gtfs$agency
#>    agency_id agency_name                               agency_url
#>       <char>      <char>                                   <char>
#> 1:         1     SPTRANS http://www.sptrans.com.br/?versao=011019
#> 2:         1     SPTRANS http://www.sptrans.com.br/?versao=011019
#>      agency_timezone agency_lang
#>               <char>      <char>
#> 1: America/Sao_Paulo          pt
#> 2: America/Sao_Paulo          pt

gtfs <- remove_duplicates(gtfs)
gtfs$agency
#>    agency_id agency_name                               agency_url
#>       <char>      <char>                                   <char>
#> 1:         1     SPTRANS http://www.sptrans.com.br/?versao=011019
#>      agency_timezone agency_lang
#>               <char>      <char>
#> 1: America/Sao_Paulo          pt
```
