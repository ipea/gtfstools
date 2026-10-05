#' Convert time fields to seconds after midnight
#'
#' Converts `stop_times`' and `frequencies`' fields in the "HH:MM:SS" format to
#' seconds after midnight. Instead of overwritting the existing fields, creates
#' new fields with the `_secs` suffix.
#'
#' @template gtfs
#' @param file A character vector, specifying the file whose fields should be
#' converted. If `NULL` (the default), the function attempts to convert the
#' times from both files, but only raises an error if none of them exist.
#' @param by_reference Whether to update the tables by reference. Defaults to
#' `FALSE`.
#'
#' @return If `by_reference` is `FALSE`, returns a GTFS object with additional
#' time in seconds columns (identified by a `_secs` suffix). Else, returns a
#' GTFS object invisibly (please note that in such case the original GTFS object
#' is altered).
#'
#' @details
#' Other gtfstools functions use existing `_secs` columns as-is. Only the
#' functions that edit times ([set_trip_speed()] and [filter_by_time_of_day()])
#' keep them in sync, so re-run `convert_time_to_seconds()` after other edits.
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#'
#' gtfs <- read_gtfs(data_path)
#'
#' # by default converts both 'stop_times' and 'frequencies' times
#' converted_gtfs <- convert_time_to_seconds(gtfs)
#' head(converted_gtfs$stop_times)
#' head(converted_gtfs$frequencies)
#'
#' # choose which table to convert with 'file'
#' converted_gtfs <- convert_time_to_seconds(gtfs, file = "frequencies")
#' head(converted_gtfs$stop_times)
#' head(converted_gtfs$frequencies)
#'
#' # original gtfs remained unchanged, as seen with the frequencies table above
#' # change original object without creating a copy with 'by_reference = TRUE'
#' convert_time_to_seconds(gtfs, by_reference = TRUE)
#' head(gtfs$stop_times)
#' head(gtfs$frequencies)
#'
#' @export
convert_time_to_seconds <- function(gtfs, file = NULL, by_reference = FALSE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_logical(by_reference, len = 1, any.missing = FALSE)
  checkmate::assert_character(file, null.ok = TRUE)
  if (!is.null(file)) {
    checkmate::assert_names(file, subset.of = c("frequencies", "stop_times"))
  }

  if (is.null(file)) {
    file <- names(gtfs)
    file <- file[file %chin% c("frequencies", "stop_times")]

    if (identical(file, character(0))) {
      stop(
        "The GTFS object must have either a 'frequencies' ",
        "or a 'stop_times' table."
      )
    }
  }

  if ("frequencies" %chin% file) {
    if (gtfsio::check_field_exists(gtfs, "frequencies", "start_time")) {
      gtfsio::assert_field_class(gtfs, "frequencies", "start_time", "character")
    }
    if (gtfsio::check_field_exists(gtfs, "frequencies", "end_time")) {
      gtfsio::assert_field_class(gtfs, "frequencies", "end_time", "character")
    }
  }

  if ("stop_times" %chin% file) {
    if (gtfsio::check_field_exists(gtfs, "stop_times", "departure_time")) {
      gtfsio::assert_field_class(
        gtfs,
        "stop_times",
        "departure_time",
        "character"
      )
    }
    if (gtfsio::check_field_exists(gtfs, "stop_times", "arrival_time")) {
      gtfsio::assert_field_class(
        gtfs,
        "stop_times",
        "arrival_time",
        "character"
      )
    }
  }

  # we checked before without making any conversions because it might be useful
  # to raise errors before proceeding with potentially time consuming operations

  if ("frequencies" %chin% file) {
    if (!by_reference) gtfs$frequencies <- data.table::copy(gtfs$frequencies)

    if (gtfsio::check_field_exists(gtfs, "frequencies", "start_time")) {
      gtfs$frequencies[, start_time_secs := string_to_seconds(start_time)]
    }
    if (gtfsio::check_field_exists(gtfs, "frequencies", "start_time")) {
      gtfs$frequencies[, end_time_secs := string_to_seconds(end_time)]
    }
  }

  if ("stop_times" %chin% file) {
    if (!by_reference) gtfs$stop_times <- data.table::copy(gtfs$stop_times)

    if (gtfsio::check_field_exists(gtfs, "stop_times", "departure_time")) {
      gtfs$stop_times[
        ,
        departure_time_secs := string_to_seconds(departure_time)
      ]
    }
    if (gtfsio::check_field_exists(gtfs, "stop_times", "departure_time")) {
      gtfs$stop_times[, arrival_time_secs := string_to_seconds(arrival_time)]
    }
  }

  if (by_reference) return(invisible(gtfs))
  return(gtfs)
}
