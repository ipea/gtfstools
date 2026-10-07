#' Remove unused ids
#'
#' Removes the ids that the feed doesn't use, with their entries in every
#' file. A trip is used if it has `stop_times`, and anything that a used trip
#' refers to, directly or indirectly, is used too. Entries that refer to
#' removed ids are removed as well, including those in `attributions` and
#' `translations`. When there are no `fare_rules`, `fare_attributes` and their
#' agencies are kept, since these fares apply to the whole feed. Fares v2 and
#' GTFS-Flex files are left unchanged, so they may still refer to removed ids.
#'
#' @template gtfs
#'
#' @return The GTFS object without unused ids.
#'
#' @seealso [filter_by_trip_id()], [remove_duplicates()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#' nrow(gtfs$agency)
#'
#' gtfs <- remove_unused_ids(gtfs)
#' nrow(gtfs$agency)
#'
#' @export
remove_unused_ids <- function(gtfs) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  gtfsio::assert_field_exists(gtfs, "trips", "trip_id")
  gtfsio::assert_field_exists(gtfs, "stop_times", "trip_id")

  used_trips <- gtfs$trips$trip_id[
    gtfs$trips$trip_id %chin% gtfs$stop_times$trip_id
  ]
  result <- filter_by_trip_id(gtfs, used_trips)

  # fares without fare_rules apply to the whole feed, so they and their
  # agencies are always used

  if (NROW(gtfs$fare_rules) == 0L && !is.null(gtfs$fare_attributes)) {
    result$fare_attributes <- gtfs$fare_attributes
    result$agency <- filter_agency_from_derived_agency_id(
      gtfs,
      c(result$agency$agency_id, gtfs$fare_attributes$agency_id)
    )$agency
  }

  result <- remove_dangling_references(result)

  return(result)
}

remove_dangling_references <- function(gtfs) {
  # ids that 'attributions' and 'translations' may refer to. files that are
  # absent or lack their id column are skipped, so rows pointing at them are
  # kept

  ids <- list(
    agency = gtfs$agency$agency_id,
    routes = gtfs$routes$route_id,
    trips = gtfs$trips$trip_id,
    stops = gtfs$stops$stop_id,
    pathways = gtfs$pathways$pathway_id,
    levels = gtfs$levels$level_id
  )
  ids <- Filter(Negate(is.null), ids)

  keys <- c(agency = "agency_id", routes = "route_id", trips = "trip_id")
  for (tbl in intersect(names(keys), names(ids))) {
    ref <- gtfs$attributions[[keys[[tbl]]]]
    if (!is.null(ref)) {
      gtfs$attributions <- gtfs$attributions[
        ref %chin% "" | ref %chin% ids[[tbl]]
      ]
    }
  }

  # 'stop_times' translations are identified by 'trip_id'

  translation_ids <- c("table_name", "record_id")
  if (gtfsio::check_field_exists(gtfs, "translations", translation_ids)) {
    ids$stop_times <- ids$trips
    ids$attributions <- gtfs$attributions$attribution_id

    tr <- gtfs$translations
    keep <- tr$record_id %chin% "" | !tr$table_name %chin% names(ids)
    for (tbl in names(ids)) {
      keep <- keep |
        (tr$table_name %chin% tbl & tr$record_id %chin% ids[[tbl]])
    }
    gtfs$translations <- tr[keep]
  }

  return(gtfs)
}
