#' Merge GTFS files
#'
#' Combines many GTFS objects into a single one.
#'
#' @param ... GTFS objects to be merged. Each argument can either be a GTFS or
#' a list of GTFS objects.
#' @param files A character vector listing the GTFS tables to be merged. If
#' `NULL` (the default), all tables are merged.
#' @param prefix Either a logical or a character vector (defaults to `FALSE`).
#' Whether to add a prefix to the value of id fields that identify from which
#' GTFS object the value comes from. If `TRUE`, the prefixes will range from
#' `"1"` to `n`, where `n` is the number of objects passed to the function. If a
#' character vector, its elements will be used to identify the GTFS objects, and
#' the length of the vector must equal the total amount of objects passed in
#' `...` (the first element will identify the first GTFS, the second element the
#' second GTFS, and so on).
#'
#' @return A GTFS object in which each table is a combination (by row) of the
#' tables from the specified GTFS objects.
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
#'
#' spo_gtfs <- read_gtfs(spo_path)
#' names(spo_gtfs)
#'
#' ggl_gtfs <- read_gtfs(ggl_path)
#' names(ggl_gtfs)
#'
#' merged_gtfs <- merge_gtfs(spo_gtfs, ggl_gtfs)
#' names(merged_gtfs)
#'
#' # use a list() to programatically merge many GTFS objects
#' gtfs_list <- list(spo_gtfs, ggl_gtfs)
#' merged_gtfs <- merge_gtfs(gtfs_list)
#'
#' # 'prefix' helps disambiguating from which GTFS each id comes from.
#' # if TRUE, the ids range from 1:n, where n is the number of gtfs
#' merged_gtfs <- merge_gtfs(gtfs_list, prefix = TRUE)
#' merged_gtfs$agency
#'
#' # if a character vector, its elements will be used to identify the each gtfs
#' merged_gtfs <- merge_gtfs(gtfs_list, prefix = c("spo", "ggl"))
#' merged_gtfs$agency
#' @export
merge_gtfs <- function(..., files = NULL, prefix = FALSE) {
  checkmate::assert_character(files, null.ok = TRUE, any.missing = FALSE)

  # store gtfs objects in a list and unlist eventual lists of gtfs

  gtfs_objects <- list(...)

  is_list_of_gtfs <- vapply(gtfs_objects, is_gtfs_list, logical(1))

  gtfs_objects <- append(
    gtfs_objects[!is_list_of_gtfs],
    unlist(gtfs_objects[is_list_of_gtfs], recursive = FALSE)
  )
  gtfs_objects <- lapply(gtfs_objects, assert_and_assign_gtfs_object)

  # check if prefix is either a logical or a character vector with length equal
  # to the number of provided gtfs objects

  gtfs_count <- length(gtfs_objects)

  checkmate::assert(
    checkmate::check_logical(prefix, len = 1, any.missing = FALSE),
    checkmate::check_character(prefix, len = gtfs_count, any.missing = FALSE),
    combine = "or"
  )

  if (is.logical(prefix)) {
    list_of_prefixes <- as.character(seq.int(gtfs_count))
  } else {
    list_of_prefixes <- prefix
  }

  # only merge the tables specified by 'files'
  # if 'files' is NULL, then merge all possible files.
  # * with the exception of the '.' element, that may exist in tidygtfs objects
  # if not, check if the GTFS to be merged contain the files.
  # * if some of them are missing, throw a warning.
  # * if all of them are missing, throw an error.

  files_within_gtfs <- unlist(lapply(gtfs_objects, names))
  files_within_gtfs <- unique(files_within_gtfs)
  files_to_merge <- setdiff(files_within_gtfs, ".")

  if (!is.null(files)) {
    invalid_files <- files[! files %chin% files_within_gtfs]
    files_to_merge <- files[! files %chin% invalid_files]

    if (!identical(invalid_files, character(0))) {
      if (!identical(files_to_merge, character(0))) {
        warning(
          "None of the GTFS to be merged contain the following files: ",
          paste0("'", invalid_files, "'", collapse = ", ")
        )
      } else if (identical(files_to_merge, character(0))) {
        stop(
          "None of the GTFS to be merged contain the files passed to 'files'"
        )
      }
    }
  }

  # merge specified files using rbindlist - loop over each file to merge, then
  # use rbindlist to bind all correspondent data.tables to a single data.table.

  merged_gtfs <- lapply(
    files_to_merge,
    function(file) {
      data.table::rbindlist(
        lapply(gtfs_objects, function(gtfs_object) gtfs_object[[file]]),
        fill = TRUE,
        idcol = "origin_gtfs"
      )
    }
  )

  # using fill = TRUE in data.table::rbindlist introduces some NA_character.
  # change those to "" to keep consistency (empty character entries are read as
  # "" by data.table::fread)

  for (dt in seq_along(merged_gtfs)) {
    # determine the character columns in each data.table

    charac_cols <- which(vapply(merged_gtfs[[dt]], is.character, logical(1)))

    # then substitute NA by ""

    for (col in charac_cols) {
      data.table::set(
        merged_gtfs[[dt]],
        i = which(is.na(merged_gtfs[[dt]][[col]])),
        j = col,
        value = ""
      )
    }
  }

  # if prefix is TRUE or a list of prefixes, then add the prefixes to the ids.
  # some fields that end with "_id" should not be changed (e.g. direction_id in
  # trips, which is actually an enum, not an id).

  unchanged_ids <- c("direction_id")

  if (!isFALSE(prefix)) {
    for (dt in merged_gtfs) {
      # determine the id columns (or columns that refer to ids) in each table.
      # direction_id, from trips, ends with _id but is an enum and should not be
      # changed.
      # field_value, from translations, doesn't end with _id but refers to an
      # id, thus should be changed.

      id_cols <- names(dt)[(grepl("_id$", names(dt)))]
      id_cols <- setdiff(id_cols, "direction_id")
      if (!is.null(dt[["field_value"]])) id_cols <- c(id_cols, "field_value")

      # then add the prefix to the id value

      for (col in id_cols) {
        dt[
          get(col) != "",
          eval(col) := paste0(list_of_prefixes[origin_gtfs], "_", get(col))
        ]
      }
    }
  }

  for (dt in merged_gtfs) dt[, origin_gtfs := NULL]

  # create a gtfs object from the current list of gtfs tables in merged_gtfs

  names(merged_gtfs) <- files_to_merge
  merged_gtfs <- gtfsio::new_gtfs(merged_gtfs, "dt_gtfs")

  return(merged_gtfs)
}


is_gtfs_list <- function(x) {
  is_gtfs_object <- vapply(
    x,
    function(i) checkmate::test_class(i, "gtfs"),
    logical(1)
  )
  all(is_gtfs_object)
}
