#' Validate GTFS feed
#'
#' Uses MobilityData's [GTFS
#' validator](https://github.com/MobilityData/gtfs-validator) to perform a GTFS
#' business rule validation. The results are available as an HTML report (if
#' validator v3.1.0 or higher is used) and in JSON format. Please check the
#' complete set of rules used in the validation
#' [here](https://github.com/MobilityData/gtfs-validator/blob/master/RULES.md).
#' Please note that this function requires a working installation of Java 11 or
#' higher to work.
#'
#' @param gtfs The GTFS to be validated. Can be in the format of a GTFS object,
#'   of a path to a GTFS file, of a path to a directory or an URL to a feed.
#' @param output_path A string. The path to the directory that the validator
#'   will create and in which the results will be saved to.
#' @param validator_path A string. The path to the GTFS validator, previously
#'   downloaded with [download_validator()].
#' @param overwrite A logical. Whether to overwrite existing validation results
#'   in `output_path`. Defaults to `TRUE`.
#' @param html_preview A logical. Whether to show HTML report in a viewer, such
#'   as RStudio or a browser. Defaults to `TRUE` (only works on interactive
#'   sessions).
#' @param pretty_json A logical. Whether JSON results should be printed in a
#'   readable way, that allows it to be inspected without manually formatting.
#'   Defaults to `FALSE`.
#' @param quiet A logical. Whether to hide informative messages. Defaults to
#'   `TRUE`.
#' @param n_threads An integer between 1 and the number of cores in the running
#'   machine. Control how many threads are used during the validation. Defaults
#'   to using all but one of the available cores.
#'
#' @return Invisibly returns the normalized path to the directory where the
#'   validation results were saved to.
#'
#' @family validation
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' output_path <- tempfile("validation_result")
#' validator_path <- download_validator(tempdir())
#' gtfs <- read_gtfs(data_path)
#'
#' validate_gtfs(gtfs, output_path, validator_path)
#' list.files(output_path)
#'
#' # works with feeds saved to disk
#' new_output_path <- tempfile("new_validation_result")
#' validate_gtfs(data_path, new_output_path, validator_path)
#' list.files(new_output_path)
#'
#' # and with feeds pointed by an url
#' newer_output_path <- tempfile("newer_validation_result")
#' gtfs_url <- "https://github.com/ipea/gtfstools/raw/main/inst/extdata/spo_gtfs.zip"
#' validate_gtfs(gtfs_url, newer_output_path, validator_path)
#' list.files(newer_output_path)
#'
#' @export
validate_gtfs <- function(gtfs,
                          output_path,
                          validator_path,
                          overwrite = TRUE,
                          html_preview = TRUE,
                          pretty_json = FALSE,
                          quiet = TRUE,
                          n_threads = 1) {
  assert_java_version()
  checkmate::assert(
    checkmate::check_string(output_path),
    checkmate::check_path_for_output(output_path, overwrite = TRUE),
    combine = "and"
  )
  checkmate::assert(
    checkmate::check_string(validator_path),
    checkmate::check_file_exists(validator_path),
    combine = "and"
  )
  checkmate::assert_logical(overwrite, any.missing = FALSE, len = 1)
  checkmate::assert_logical(html_preview, any.missing = FALSE, len = 1)
  checkmate::assert_logical(pretty_json, any.missing = FALSE, len = 1)
  checkmate::assert_logical(quiet, any.missing = FALSE, len = 1)
  assert_overwritten_files(output_path, overwrite)

  gtfs <- assert_and_assign_gtfs_input(gtfs, quiet)
  validator_version <- parse_validator_version(validator_path)
  n_threads <- assert_and_assign_n_threads(n_threads)

  pretty_json_flag <- ""
  if (pretty_json) pretty_json_flag <- "-p"

  command_flags <- c(
    "-jar", validator_path,
    "-i", gtfs,
    "-o", output_path,
    "-t", n_threads,
    pretty_json_flag
  )
  if (!quiet) {
    message(
      "Validator invoked with call:\njava ",
      paste(command_flags, collapse = " ")
    )
  }
  call_output <- processx::run("java", command_flags)

  if (call_output$stdout != "") {
    writeLines(
      call_output$stdout,
      con = file.path(output_path, "validation_stdout.txt")
    )
  }

  if (call_output$stderr != "") {
    writeLines(
      call_output$stderr,
      con = file.path(output_path, "validation_stderr.txt")
    )
  }

  if (
    interactive() &&
      html_preview &&
      validator_version >= numeric_version("3.1.0")
  ) {
    html_path <- file.path(output_path, "report.html")
    utils::browseURL(html_path)
  }

  return(invisible(normalizePath(output_path)))
}

parse_validator_version <- function(validator_path) {
  version_region <- regexpr("\\d+\\.\\d+\\.\\d+\\.jar$", validator_path)

  if (version_region == -1) {
    stop(
      "Assertion on 'validator_path' failed: Could not parse validator ",
      "version. Please make sure that the path is in the format ",
      "gtfs-validator-vX.Y.Z.jar"
    )
  }

  version <- substring(
    validator_path,
    version_region,
    nchar(validator_path) - 4
  )
  version <- numeric_version(version)

  return(version)
}

assert_and_assign_gtfs_input <- function(gtfs, quiet) {
  if (inherits(gtfs, "gtfs")) {
    gtfs_path <- tempfile("gtfs", fileext = ".zip")
    write_gtfs(gtfs, gtfs_path, quiet = quiet)
    gtfs <- gtfs_path
  } else {
    if (!checkmate::test_string(gtfs)) {
      stop(
        "Assertion on 'gtfs' failed: Must either be a GTFS object, ",
        "a path to a local GTFS file, a path to a local ",
        "directory or an URL to a feed."
      )
    }

    is_url <- grepl("^http[s]?\\:\\/\\/\\.*", gtfs)
    if (is_url) {
      tmpfile <- tempfile("gtfs", fileext = ".zip")
      if (!quiet) message("Downloading ", gtfs, " to ", tmpfile, ".")
      curl::curl_download(gtfs, tmpfile, quiet = quiet)
      gtfs <- tmpfile
    }

    if (file.exists(gtfs)) {
      if (!dir.exists(gtfs)) {
        ziplist <- tryCatch(zip::zip_list(gtfs), error = function(cnd) cnd)
        is_zip <- !inherits(ziplist, "error")

        if (!is_zip) {
          element <- ifelse(is_url, " URL ", " path ")
          stop(
            "Assertion on 'gtfs' failed: The provided",
            element,
            "doesn't seem to point to a GTFS file."
          )
        }
      }
    } else {
      stop("Assertion on 'gtfs' failed: File does not exist.")
    }
  }

  return(gtfs)
}

assert_java_version <- function() {
  informative_message <- paste0(
    "Please install Java version 11 or higher to run the validator.\n",
    "You can download Java 11 from https://jdk.java.net/java-se-ri/11."
  )
  java_version_output <- tryCatch(
    processx::run("java", "-version"),
    error = function(cnd) cnd
  )

  if (inherits(java_version_output, "error")) {
    stop("Could not find Java on the system path. ", informative_message)
  }

  full_java_version <- strsplit(java_version_output$stderr, "\"")[[1]][2]
  java_version <- strsplit(full_java_version, "_")[[1]][1]
  java_version <- numeric_version(java_version)

  if (java_version < numeric_version("11.0.0")) {
    stop(
      "You seem to have Java version ", full_java_version, " installed. ",
      informative_message
    )
  }

  return(invisible(TRUE))
}

assert_overwritten_files <- function(output_path, overwrite) {
  if (dir.exists(output_path)) {
    checkmate::assert_path_for_output(
      file.path(output_path, "report.html"),
      overwrite = overwrite
    )
    checkmate::assert_path_for_output(
      file.path(output_path, "report.json"),
      overwrite = overwrite
    )
    checkmate::assert_path_for_output(
      file.path(output_path, "system_errors.json"),
      overwrite = overwrite
    )
    checkmate::assert_path_for_output(
      file.path(output_path, "validation_stdout.txt"),
      overwrite = overwrite
    )
    checkmate::assert_path_for_output(
      file.path(output_path, "validation_stderr.txt"),
      overwrite = overwrite
    )
  }
}

assert_and_assign_n_threads <- function(n_threads) {
  checkmate::assert_number(n_threads, lower = 1, finite = TRUE)

  n_threads <- min(
    n_threads,
    parallelly::availableCores(),
    parallelly::freeConnections()
  )

  return(n_threads)
}
