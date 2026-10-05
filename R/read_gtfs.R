#' Read GTFS files
#'
#' Reads GTFS text files from either a local `.zip` file or an URL.
#'
#' @param path The path to a GTFS `.zip` file.
#' @param files A character vector containing the text files to be read from the
#'   GTFS (without the `.txt` extension). If `NULL` (the default) all existing
#'   files are read.
#' @param fields A named list containing the fields to be read from each text
#'   file, in the format `list(file = c("field1", "field2"))`. If `NULL` (the
#'   default), all fields from the files specified in `files` are read. If a
#'   file is specified in `files` but not in `fields`, all fields from that file
#'   will be read (i.e. you may specify in `fields` only files whose fields you
#'   want to subset).
#' @param skip A character vector containing the text files that should not be
#'   read from the GTFS, without the `.txt` extension. If `NULL` (the default),
#'   no files are skipped. Cannot be used if `files` is already set.
#' @param quiet Whether to hide log messages and progress bars (defaults to
#'   `TRUE`).
#' @param encoding A string, ultimately passed to [data.table::fread()].
#'   Defaults to `"unknown"`. Other possible options are `"UTF-8"` and
#'   `"Latin-1"`. Please note that this is not used to re-encode the input, but
#'   to enable handling encoded strings in their native encoding.
#'
#' @return A `data.table`-based GTFS object: a `list` of `data.table`s in which
#' each table represents a GTFS text file.
#'
#' @section Details:
#' The column types of each `data.table` in the final GTFS object conform as
#' closely as possible to the [Google's Static GTFS Reference](
#' https://developers.google.com/transit/gtfs/reference). Exceptions are
#' date-related columns (such as `calendar.txt`'s `start_date` and `end_date`,
#' for example), which are converted to `Date` objects, instead of being kept as
#' `integer`s, allowing for easier data manipulation. These columns are
#' converted back to `integer`s when writing the GTFS object to a `.zip` file
#' using [write_gtfs()].
#'
#' @family io functions
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#'
#' gtfs <- read_gtfs(data_path)
#' names(gtfs)
#'
#' gtfs <- read_gtfs(data_path, files = c("trips", "stop_times"))
#' names(gtfs)
#'
#' gtfs <- read_gtfs(data_path, skip = "trips")
#' names(gtfs)
#'
#' gtfs <- read_gtfs(data_path, fields = list(agency = "agency_id"))
#' names(gtfs)
#' names(gtfs$agency)
#'
#' @export
read_gtfs <- function(path,
                      files = NULL,
                      fields = NULL,
                      skip = NULL,
                      quiet = TRUE,
                      encoding = "unknown") {

  # inputs are more thoroughly checked in gtfsio::import_gtfs()

  checkmate::assert_string(path)
  checkmate::assert_character(files, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_list(fields, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_character(skip, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_logical(quiet, any.missing = FALSE, len = 1)
  checkmate::assert(
    checkmate::check_names(
      encoding,
      subset.of = c("unknown", "UTF-8", "Latin-1")
    ),
    checkmate::check_string(encoding),
    combine = "and"
  )

  # read gtfs file using {gtfsio} and convert relevant fields from standard type

  gtfs <- gtfsio::import_gtfs(
    path,
    files = files,
    fields = fields,
    skip = skip,
    quiet = quiet,
    encoding = encoding
  )

  # stopgap for an upstream issue: data.table::fread() keeps the doubled quotes
  # ("") that escape a quote inside quoted fields, so we unescape them here.
  # id and time columns are skipped for performance

  for (file in names(gtfs)) {
    if (!data.table::is.data.table(gtfs[[file]])) next
    for (col in names(gtfs[[file]])) {
      x <- gtfs[[file]][[col]]
      if (!is.character(x) || grepl("_(id|time)$", col)) next
      if (any(grepl("\"\"", x, fixed = TRUE, useBytes = TRUE))) {
        x <- gsub("\"\"", "\"", x, fixed = TRUE)
        data.table::set(gtfs[[file]], j = col, value = x)
      }
    }
  }

  gtfs <- convert_from_standard(gtfs)

  return(gtfs)

}
