#' Filter a GTFS object using a `simple features` object (defunct)
#'
#' @description
#' This function was deprecated in gtfstools 1.3.0 and is now defunct: calling
#' it raises an error. Please use [filter_by_spatial_extent()] instead, which
#' takes the same arguments.
#'
#' @param ... Ignored.
#'
#' @return Doesn't return: always raises an error.
#'
#' @seealso [filter_by_spatial_extent()], which replaces this function.
#'
#' @export
filter_by_sf <- function(...) {
  cli::cli_abort(
    class = "gtfstools_defunct_filter_by_sf_error",
    message = c(
      paste0(
        "{.fn filter_by_sf} was deprecated in gtfstools 1.3.0 and is now ",
        "defunct."
      ),
      "i" = paste0(
        "Please use {.fn filter_by_spatial_extent} instead, which takes the ",
        "same arguments."
      )
    )
  )
}
