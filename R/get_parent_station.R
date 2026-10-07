#' Get parent stations recursively
#'
#' Returns the (recursive) parent stations of each specified `stop_id`.
#' Recursive in this context means it returns all parents' parents (i.e. first
#' parents, then parents' parents, and then their parents, and so on).
#'
#' @template gtfs
#' @param stop_id A string vector including the `stop_id`s to have their parents
#'   returned. If `NULL` (the default), the function returns the parents of
#'   every `stop_id` in the GTFS.
#'
#' @return A `data.table` containing the `stop_id`s and their `parent_station`s.
#'   If a stop doesn't have a parent, its correspondent `parent_station` entry
#'   is marked as `""`.
#'
#' @seealso [get_children_stops()]
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
#'
#' gtfs <- read_gtfs(data_path)
#'
#' parents <- get_parent_station(gtfs)
#' head(parents)
#'
#' # use the stop_id argument to control which stops are analyzed
#' parents <- get_parent_station(gtfs, c("B1", "B2"))
#' parents
#'
#' @export
get_parent_station <- function(gtfs, stop_id = NULL) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_character(stop_id, null.ok = TRUE, any.missing = FALSE)

  gtfsio::assert_field_class(
    gtfs,
    "stops",
    c("stop_id", "parent_station"),
    rep("character", 2)
  )

  # select stop_ids to identify parents and raise warning if a given stop_id
  # doesn't exist in 'stops'

  if (!is.null(stop_id)) {
    invalid_stop_id <- warn_missing_ids(
      stop_id,
      gtfs$stops$stop_id,
      "stops",
      "stop_id"
    )

    stop_id <- setdiff(stop_id, invalid_stop_id)
  } else {
    stop_id <- gtfs$stops$stop_id
  }

  # create a "relational" vector, whose names are the stop ids and values are
  # the parent stations, used to lookup parent stations

  parents <- gtfs$stops$parent_station
  names(parents) <- gtfs$stops$stop_id

  result <- data.table::data.table(
    stop_id = stop_id,
    parent_station = rep(NA_character_, length(stop_id))
  )

  do_check <- TRUE

  while (do_check) {
    result[is.na(parent_station), parent_station := parents[stop_id]]

    # when a stop not listed in stops (in the stop_id field) is used to subset
    # the parents vector, it introduces a NA_character_ in the parent_station
    # columns. substitute NAs by "" because of that
    result[is.na(parent_station), parent_station := ""]

    # keep checking for recursive parents if new parents were found in this
    # iteration

    do_check <- FALSE

    found_parents <- setdiff(result$parent_station, "")

    if (!all(found_parents %chin% result$stop_id)) {
      new_parents <- unique(setdiff(found_parents, result$stop_id))

      result <- rbind(
        result,
        data.table::data.table(
          stop_id = new_parents,
          parent_station = NA_character_
        )
      )

      do_check <- TRUE
    }
  }

  return(result[])
}
