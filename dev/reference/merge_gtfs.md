# Merge GTFS files

Combines many GTFS objects into a single one.

## Usage

``` r
merge_gtfs(..., files = NULL, prefix = FALSE)
```

## Arguments

- ...:

  GTFS objects to be merged. Each argument can either be a GTFS or a
  list of GTFS objects.

- files:

  A character vector listing the GTFS tables to be merged. If `NULL`
  (the default), all tables are merged.

- prefix:

  Either a logical or a character vector (defaults to `FALSE`). Whether
  to add a prefix to the value of id fields that identify from which
  GTFS object the value comes from. If `TRUE`, the prefixes will range
  from `"1"` to `n`, where `n` is the number of objects passed to the
  function. If a character vector, its elements will be used to identify
  the GTFS objects, and the length of the vector must equal the total
  amount of objects passed in `...` (the first element will identify the
  first GTFS, the second element the second GTFS, and so on).

## Value

A GTFS object in which each table is a combination (by row) of the
tables from the specified GTFS objects.

## Examples

``` r
spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")

spo_gtfs <- read_gtfs(spo_path)
names(spo_gtfs)
#> [1] "agency"      "calendar"    "frequencies" "routes"      "shapes"     
#> [6] "stop_times"  "stops"       "trips"      

ggl_gtfs <- read_gtfs(ggl_path)
names(ggl_gtfs)
#>  [1] "calendar_dates"  "fare_attributes" "fare_rules"      "feed_info"      
#>  [5] "frequencies"     "levels"          "pathways"        "routes"         
#>  [9] "shapes"          "stop_times"      "stops"           "transfers"      
#> [13] "translations"    "trips"           "agency"          "attributions"   
#> [17] "calendar"       

merged_gtfs <- merge_gtfs(spo_gtfs, ggl_gtfs)
names(merged_gtfs)
#>  [1] "agency"          "calendar"        "frequencies"     "routes"         
#>  [5] "shapes"          "stop_times"      "stops"           "trips"          
#>  [9] "calendar_dates"  "fare_attributes" "fare_rules"      "feed_info"      
#> [13] "levels"          "pathways"        "transfers"       "translations"   
#> [17] "attributions"   

# use a list() to programatically merge many GTFS objects
gtfs_list <- list(spo_gtfs, ggl_gtfs)
merged_gtfs <- merge_gtfs(gtfs_list)

# 'prefix' helps disambiguating from which GTFS each id comes from.
# if TRUE, the ids range from 1:n, where n is the number of gtfs
merged_gtfs <- merge_gtfs(gtfs_list, prefix = TRUE)
merged_gtfs$agency
#>      agency_id    agency_name                               agency_url
#>         <char>         <char>                                   <char>
#> 1:         1_1        SPTRANS http://www.sptrans.com.br/?versao=011019
#> 2:         1_1        SPTRANS http://www.sptrans.com.br/?versao=011019
#> 3: 2_agency001 Transit Agency       http://www.transitcommuterbus.com/
#>      agency_timezone agency_lang
#>               <char>      <char>
#> 1: America/Sao_Paulo          pt
#> 2: America/Sao_Paulo          pt
#> 3:               PST          en

# if a character vector, its elements will be used to identify the each gtfs
merged_gtfs <- merge_gtfs(gtfs_list, prefix = c("spo", "ggl"))
merged_gtfs$agency
#>        agency_id    agency_name                               agency_url
#>           <char>         <char>                                   <char>
#> 1:         spo_1        SPTRANS http://www.sptrans.com.br/?versao=011019
#> 2:         spo_1        SPTRANS http://www.sptrans.com.br/?versao=011019
#> 3: ggl_agency001 Transit Agency       http://www.transitcommuterbus.com/
#>      agency_timezone agency_lang
#>               <char>      <char>
#> 1: America/Sao_Paulo          pt
#> 2: America/Sao_Paulo          pt
#> 3:               PST          en
```
