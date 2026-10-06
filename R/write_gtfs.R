#' Write GTFS files
#'
#' Writes GTFS objects as GTFS `.zip` files.
#'
#' @template gtfs
#' @param path The path to the `.zip` file in which the feed should be written
#'   to.
#' @param files A character vector containing the name of the elements to be
#'   written to the feed. If `NULL` (the default), all elements inside the GTFS
#'   object are written.
#' @param standard_only Whether to write only standard files and fields
#'   (defaults to `FALSE`, which doesn't drop extra files and fields).
#' @param as_dir Whether to write the feed as a directory, instead of a `.zip`
#'   file (defaults to `FALSE`, which means that the field is written as a zip
#'   file).
#' @param overwrite Whether to overwrite existing `.zip` file (defaults to
#'   `TRUE`).
#' @param quiet Whether to hide log messages and progress bars (defaults to
#'   `TRUE`).
#' @param compression_level A number between 1 and 9 indicating how much the
#'   `.zip` file should be compressed. Lower levels write faster but create
#'   larger files. Defaults to 6, which is usually several times faster than 9
#'   and creates files of very similar size. Ignored when `as_dir = TRUE`.
#'
#' @return Invisibly returns the same GTFS object passed to the `gtfs`
#' parameter.
#'
#' @family io functions
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' tmp_dir <- file.path(tempdir(), "tmpdir")
#' dir.create(tmp_dir)
#' list.files(tmp_dir) #'
#' tmp_file <- tempfile(pattern = "gtfs", tmpdir = tmp_dir, fileext = ".zip")
#' write_gtfs(gtfs, tmp_file)
#' list.files(tmp_dir)
#'
#' gtfs_all_files <- read_gtfs(tmp_file)
#' names(gtfs_all_files)
#'
#' write_gtfs(gtfs, tmp_file, files = "stop_times")
#' gtfs_stop_times <- read_gtfs(tmp_file)
#' names(gtfs_stop_times)
#'
#' @export
write_gtfs <- function(gtfs,
                       path,
                       files = NULL,
                       standard_only = FALSE,
                       as_dir = FALSE,
                       overwrite = TRUE,
                       quiet = TRUE,
                       compression_level = 6) {

  # inputs are more thoroughly checked on gtfsio::export_gtfs()

  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_logical(as_dir, any.missing = FALSE, len = 1)
  if (as_dir) {
    checkmate::assert_path_for_output(path, overwrite = overwrite)
  } else {
    checkmate::assert_path_for_output(
      path,
      overwrite = overwrite,
      extension = "zip"
    )
  }
  checkmate::assert_character(files, null.ok = TRUE, any.missing = FALSE)
  checkmate::assert_logical(standard_only, any.missing = FALSE, len = 1)
  checkmate::assert_logical(overwrite, any.missing = FALSE, len = 1)
  checkmate::assert_logical(quiet, any.missing = FALSE, len = 1)
  checkmate::assert_int(compression_level, lower = 1, upper = 9)

  # convert relevant fields to standard types and write result using {gtfsio}

  std_gtfs <- convert_to_standard(gtfs)
  gtfsio::export_gtfs(
    std_gtfs,
    path = path,
    files = files,
    standard_only = standard_only,
    as_dir = as_dir,
    overwrite = overwrite,
    quiet = quiet,
    compression_level = as.numeric(compression_level)
  )

  # return object passed to 'gtfs' invisibly

  return(invisible(gtfs))

}
