#' Coerce lists and GTFS objects from other packages into gtfstools-compatible
#' GTFS objects
#'
#' @description
#' Coerces an existing object, such as a `list` or a GTFS object created from
#' other packages (`{tidytransit}` and `{gtfsio}`, for example) into a
#' gtfstools-compatible GTFS object - i.e. one whose internal tables are
#' represented with `data.table`s and whose fields are formatted like the fields
#' of a feed read with [read_gtfs()].
#'
#' `as_dt_gtfs()` is an S3 generic, with methods for:
#'
#' - `tidygtfs`: the class of GTFS objects read with [tidytransit::read_gtfs()].
#' This method converts all `tibble`s to `data.table`s and convert time columns,
#' represented as `hms` objects in a `tidygtfs`, to strings in the `"HH:MM:SS"`
#' format.
#'
#' - `gtfs`: the class of GTFS objects read with [gtfsio::import_gtfs()]. This
#' method convert all date fields, represented as `integer`s in `{gtfsio}`'s
#' representation, to `Date` objects.
#'
#' - `list`: this method tries to convert the elements of a list into
#' `data.table`s. Please note that all list elements must inherit from
#' `data.frame` and must be named. Like the `gtfs` method, it converts date
#' fields represented as `integer`s (`YYYYMMDD`) to `Date` objects; other fields
#' are kept as they are.
#'
#' @param gtfs The object that should be coerced to a `dt_gtfs`.
#' @param ... Ignored.
#'
#' @return A `dt_gtfs` GTFS object.
#'
#' @examples
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#'
#' gtfsio_gtfs <- gtfsio::import_gtfs(data_path)
#' class(gtfsio_gtfs)
#'
#' gtfstools_gtfs <- as_dt_gtfs(gtfsio_gtfs)
#' class(gtfstools_gtfs)
#'
#' gtfs_like_list <- unclass(gtfsio_gtfs)
#' class(gtfs_like_list)
#'
#' gtfstools_gtfs <- as_dt_gtfs(gtfs_like_list)
#' class(gtfstools_gtfs)
#'
#' @export
as_dt_gtfs <- function(gtfs, ...) {
  UseMethod("as_dt_gtfs")
}



#' @param calculate_distance A logical. Passed to [convert_sf_to_shapes()],
#'   which only affects the output when the object to be converted includes a
#'   `shapes` element. Controls whether this function, used to convert a
#'   `LINESTRING sf` into a GTFS `shapes` table, should calculate and populate
#'   the `shape_dist_traveled` column. This column is used to describe the
#'   distance along the shape from each one of its points to its first point.
#'   Defaults to `TRUE`.
#'
#' @rdname as_dt_gtfs
#' @export
as_dt_gtfs.tidygtfs <- function(gtfs, calculate_distance = TRUE, ...) {
  checkmate::assert_logical(calculate_distance, any.missing = FALSE, len = 1)

  obj_names <- names(gtfs)
  no_dot_names <- setdiff(obj_names, ".")

  # the shapes element of a tidygtfs object may be a sf. if that's the case,
  # convert it into a data.table

  if (
    gtfsio::check_file_exists(gtfs, "shapes") && inherits(gtfs$shapes, "sf")
  ) {
    gtfs$shapes <- convert_sf_to_shapes(
      gtfs$shapes,
      calculate_distance = calculate_distance
    )
  }

  # convert all other tables to data.table as well - tidygtfs generally use them
  # as tibbles

  gtfs[no_dot_names] <- lapply(gtfs[no_dot_names], data.table::as.data.table)
  if (!is.null(gtfs$.)) gtfs$. <- lapply(gtfs$., data.table::as.data.table)

  # tidytransit converts time columns to hms

  if (gtfsio::check_field_exists(gtfs, "stop_times", "arrival_time")) {
    gtfs$stop_times[
      ,
      arrival_time := seconds_to_string(as.integer(arrival_time))
    ]
  }

  if (gtfsio::check_field_exists(gtfs, "stop_times", "departure_time")) {
    gtfs$stop_times[
      ,
      departure_time := seconds_to_string(as.integer(departure_time))
    ]
  }

  if (gtfsio::check_field_exists(gtfs, "frequencies", "start_time")) {
    gtfs$frequencies[
      ,
      start_time := seconds_to_string(as.integer(start_time))
    ]
  }

  if (gtfsio::check_field_exists(gtfs, "frequencies", "end_time")) {
    gtfs$frequencies[
      ,
      end_time := seconds_to_string(as.integer(end_time))
    ]
  }

  gtfs <- unclass(gtfs)
  gtfs <- gtfsio::new_gtfs(gtfs, "dt_gtfs")

  return(gtfs)
}



#' @rdname as_dt_gtfs
#' @export
as_dt_gtfs.gtfs <- function(gtfs, ...) {
  if (!inherits(gtfs, "dt_gtfs")) gtfs <- convert_from_standard(gtfs)

  return(gtfs)
}



#' @rdname as_dt_gtfs
#' @export
as_dt_gtfs.list <- function(gtfs, ...) {
  gtfsio::assert_gtfs(gtfs)

  # convert elements to data.table to data.table to make sure our functions work
  # with it

  obj_names <- names(gtfs)
  no_dot_names <- setdiff(obj_names, ".")

  gtfs[no_dot_names] <- lapply(gtfs[no_dot_names], data.table::as.data.table)
  if (!is.null(gtfs$.)) gtfs$. <- lapply(gtfs$., data.table::as.data.table)

  gtfs <- convert_from_standard(gtfsio::new_gtfs(gtfs))

  return(gtfs)
}
