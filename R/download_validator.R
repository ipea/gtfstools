#' Download MobilityData's GTFS validator
#'
#' Downloads MobilityData's command line tool to validate GTFS feeds.
#'
#' @param path A string. The directory where the validator should be saved to.
#' @param version A string. The version of the validator that should be
#'   downloaded. Defaults to `"latest"`, but accepts version numbers as strings
#'   (i.e. to download version v6.0.0 please enter `"6.0.0"`). Please check
#'   [MobilityData/gtfs-validator
#'   releases](https://github.com/MobilityData/gtfs-validator/releases) for the
#'   full set of available versions.
#' @param force A logical. Whether to overwrite a previously downloaded
#'   validator in `path`. Defaults to `FALSE`.
#' @param quiet A logical. Whether to hide log messages and progress bars.
#'   Defaults to `TRUE`.
#'
#' @return Invisibly returns the normalized path to the downloaded validator.
#'
#' @family validation
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' path <- tempdir()
#'
#' download_validator(path)
#'
#' # specifying a specific version
#' download_validator(path, version = "6.0.0")
#'
#' @export
download_validator <- function(path,
                               version = "latest",
                               force = FALSE,
                               quiet = TRUE) {

  checkmate::assert(
    checkmate::check_string(path),
    checkmate::check_directory_exists(path),
    combine = "and"
  )
  checkmate::assert(
    checkmate::check_string(version, pattern = "\\d.\\d.\\d"),
    version == "latest",
    combine = "or"
  )
  checkmate::assert_logical(force, any.missing = FALSE, len = 1)
  checkmate::assert_logical(quiet, any.missing = FALSE, len = 1)

  validator_url <- get_validator_url(version)
  try_url <- httr2::request(validator_url) |>
    httr2::req_perform() |>
    try()
  if(inherits(try_url, "try-error")) {
    stop(
      "Assertion on 'validator_url' failed: ivalid URL. ",
      "Please make sure that the `version` is in the format 'X.Y.Z'",
      "\nTip: run `gtfstools::list_validator_versions()`")
  }

  validator_basename <- paste0("gtfs-validator-v", names(validator_url), ".jar")
  output_file <- file.path(path, validator_basename)

  if (file.exists(output_file) && (!force)) {
    if (!quiet) {
      message(
        "Using previously downloaded validator found at ",
        output_file,
        "."
      )
    }
  } else {
    if (!quiet) message("Downloading ", validator_url, " to ", output_file, ".")
    curl::curl_download(validator_url, destfile = output_file, quiet = quiet)
  }

  return(invisible(normalizePath(output_file)))
}

get_validator_url <- function(version) {
  base_url <- "https://github.com/MobilityData/gtfs-validator/releases/"

  if(version == "latest") {
    req <- httr2::request("https://github.com/MobilityData/gtfs-validator/releases/latest") |>
      httr2::req_perform()
    version <- regmatches(req$url, regexpr("([^/v])+$", req$url))
  }

  release_url <- paste0(base_url, "download/v", version, "/")
  cli_basename <- paste0("gtfs-validator-", version, "-cli.jar")

  if (numeric_version(version) < numeric_version("3.1.0")) {
    cli_basename <- sub("gtfs-validator-", "gtfs-validator-v", cli_basename)
    cli_basename <- sub("-cli", "_cli", cli_basename)
  }

  validator_url <- paste0(release_url, cli_basename)
  names(validator_url) <- version

  return(validator_url)
}



# list_validator_versions ---------------------------------------------------------------------

#' List MobilityData's GTFS validator versions
#'
#' Lists available versions of MobilityData's command line tool to validate GTFS feeds.
#'
#' @return A data.table with each CLI version, published date, and download URL.
#'
#' @family validation
#'
#' @export

list_validator_versions <- function() {
  req <- httr2::request("https://api.github.com/repos/MobilityData/gtfs-validator/releases") |>
    httr2::req_headers(`User-Agent` = "httr2") |>
    httr2::req_perform()

  data <- httr2::resp_body_json(req)

  versions <- lapply(
    data, function(x) {
      asset_nr <- x$assets |>
        lapply(\(x) grepl("jar$", x$name) & grepl("cli", x$name)) |>
        unlist() |>
        which()
      versions <- data.frame(
        version = x$tag_name,
        published_at = x$published_at,
        cli_download_url = ifelse(length(asset_nr) == 0, NA_character_,
                              x$assets[[asset_nr]]$browser_download_url)
      )
      return(versions)
    }
  ) |>
    data.table::rbindlist()

  versions <- versions[!is.na(versions$cli_download_url), ]
}
