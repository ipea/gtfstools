#' Convert a standards-compliant GTFS into a gtfstools' GTFS
#'
#' Converts a standards-compliant GTFS into a gtfstools' GTFS (i.e. one in which
#' date fields are Date objects, not integers).
#'
#' @template gtfs
#'
#' @return The GTFS object passed to the `gtfs` parameter, after converting the
#' relevant fields.
#'
#' @keywords internal
convert_from_standard <- function(gtfs) {
  checkmate::assert_class(gtfs, "gtfs")

  # create a copy of 'gtfs' to prevent the original object from being modified
  # by data.table assignments
  new_gtfs <- gtfs

  # convert date fields from integer to Date

  if (gtfsio::check_field_exists(gtfs, "calendar_dates", fields = "date")) {
    new_gtfs$calendar_dates <- data.table::copy(gtfs$calendar_dates)
    new_gtfs$calendar_dates[, date := integer_to_date(date)]
  }

  if (gtfsio::check_file_exists(gtfs, "calendar")) {
    new_gtfs$calendar <- data.table::copy(gtfs$calendar)

    if (gtfsio::check_field_exists(gtfs, "calendar", "start_date")) {
      new_gtfs$calendar[, start_date := integer_to_date(start_date)]
    }

    if (gtfsio::check_field_exists(gtfs, "calendar", "end_date")) {
      new_gtfs$calendar[, end_date := integer_to_date(end_date)]
    }
  }

  if (gtfsio::check_file_exists(gtfs, "feed_info")) {
    new_gtfs$feed_info <- data.table::copy(gtfs$feed_info)

    if (gtfsio::check_field_exists(gtfs, "feed_info", "feed_start_date")) {
      new_gtfs$feed_info[, feed_start_date := integer_to_date(feed_start_date)]
    }

    if (gtfsio::check_field_exists(gtfs, "feed_info", "feed_end_date")) {
      new_gtfs$feed_info[, feed_end_date := integer_to_date(feed_end_date)]
    }
  }

  new_gtfs <- gtfsio::new_gtfs(new_gtfs, subclass = "dt_gtfs")

  return(new_gtfs)
}


#' Convert an integer vector into a Date vector
#'
#' @keywords internal
integer_to_date <- function(field) {
  if (inherits(field, "Date")) return(field)
  as.Date(as.character(field), format = "%Y%m%d")
}


#' Convert a gtfstools' GTFS into a standards-compliant GTFS
#'
#' Converts a gtfstools' GTFS into a standards-compliant GTFS (i.e. date fields
#' are converted from Date to integer).
#'
#' @template gtfs
#'
#' @return The GTFS object passed to the `gtfs` parameter, after converting the
#' relevant fields.
#'
#' @keywords internal
convert_to_standard <- function(gtfs) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)

  # create a copy of 'gtfs' to prevent the original object from being modified
  # by data.table assignments
  new_gtfs <- gtfs

  # convert 'calendar_dates' date field from Date to integer
  if (gtfsio::check_field_exists(gtfs, "calendar_dates", fields = "date")) {
    gtfsio::assert_field_class(
      gtfs,
      "calendar_dates",
      fields = "date",
      classes = "Date"
    )

    new_gtfs$calendar_dates <- data.table::copy(gtfs$calendar_dates)
    new_gtfs$calendar_dates[, date := date_to_integer(date)]
  }

  # convert 'calendar' date fields from Date to integer
  if (gtfsio::check_file_exists(gtfs, "calendar")) {
    new_gtfs$calendar <- data.table::copy(gtfs$calendar)

    if (gtfsio::check_field_exists(gtfs, "calendar", "start_date")) {
      gtfsio::assert_field_class(
        gtfs,
        "calendar",
        fields = "start_date",
        classes = "Date"
      )
      new_gtfs$calendar[, start_date := date_to_integer(start_date)]
    }

    if (gtfsio::check_field_exists(gtfs, "calendar", "end_date")) {
      gtfsio::assert_field_class(
        gtfs,
        "calendar",
        fields = "end_date",
        classes = "Date"
      )
      new_gtfs$calendar[, end_date := date_to_integer(end_date)]
    }
  }

  # convert 'feed_info' date fields from Date to integer
  if (gtfsio::check_file_exists(gtfs, "feed_info")) {
    new_gtfs$feed_info <- data.table::copy(gtfs$feed_info)

    if (gtfsio::check_field_exists(gtfs, "feed_info", "feed_start_date")) {
      gtfsio::assert_field_class(
        gtfs,
        "feed_info",
        fields = "feed_start_date",
        classes = "Date"
      )
      new_gtfs$feed_info[, feed_start_date := date_to_integer(feed_start_date)]
    }

    if (gtfsio::check_field_exists(gtfs, "feed_info", "feed_end_date")) {
      gtfsio::assert_field_class(
        gtfs,
        "feed_info",
        fields = "feed_end_date",
        classes = "Date"
      )
      new_gtfs$feed_info[, feed_end_date := date_to_integer(feed_end_date)]
    }
  }

  class(new_gtfs) <- setdiff(class(new_gtfs), "dt_gtfs")

  return(new_gtfs[])
}


#' Convert a Date vector into an integer vector
#'
#' @keywords internal
date_to_integer <- function(field) {
  as.integer(strftime(field, format = "%Y%m%d"))
}
