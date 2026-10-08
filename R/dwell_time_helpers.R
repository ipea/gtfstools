# seconds in each unit accepted by get_dwell_time() and set_dwell_time()

dwell_unit_factors <- c(s = 1, min = 60, h = 3600, d = 86400)



# the latest time that seconds_to_string() can write ("9999:59:59"). later
# times have their hours truncated, so set_dwell_time() doesn't create them

max_time_secs <- 9999L * 3600L + 59L * 60L + 59L



# returns the rows of 'stop_times' of the given trips at the given stops (all
# of them, if NULL), warning about ids that are not in 'stop_times'. each
# column is scanned once, and its matches are reused to find the missing ids

select_dwell_time_calls <- function(stop_times, trip_id, stop_id) {
  is_selected <- NULL

  if (!is.null(trip_id)) {
    is_selected <- stop_times$trip_id %chin% trip_id
    invalid_trip_id <- unique(
      trip_id[! trip_id %chin% stop_times$trip_id[is_selected]]
    )

    if (length(invalid_trip_id) > 0) {
      cli::cli_warn(
        paste0(
          "{.file stop_times} doesn't contain the following trip_id{?s}: ",
          "{.val {invalid_trip_id}}."
        ),
        class = "gtfstools_invalid_trip_id"
      )
    }
  }

  if (!is.null(stop_id)) {
    in_stops <- stop_times$stop_id %chin% stop_id
    invalid_stop_id <- unique(
      stop_id[! stop_id %chin% stop_times$stop_id[in_stops]]
    )

    if (length(invalid_stop_id) > 0) {
      cli::cli_warn(
        paste0(
          "{.file stop_times} doesn't contain the following stop_id{?s}: ",
          "{.val {invalid_stop_id}}."
        ),
        class = "gtfstools_invalid_stop_id"
      )
    }

    if (is.null(is_selected)) {
      is_selected <- in_stops
    } else {
      is_selected <- is_selected & in_stops
    }
  }

  if (is.null(is_selected)) return(seq_len(nrow(stop_times)))

  return(which(is_selected))
}



# validates the 'from' and 'to' arguments of get_dwell_time() and
# set_dwell_time() as in set_trip_speed(), and returns them in seconds. a NULL
# end means no limit

dwell_time_window <- function(from, to) {
  checkmate::assert_string(
    from,
    pattern = "^\\d{2}:[0-5]\\d:[0-5]\\d$",
    null.ok = TRUE
  )
  checkmate::assert_string(
    to,
    pattern = "^\\d{2}:[0-5]\\d:[0-5]\\d$",
    null.ok = TRUE
  )

  from_secs <- if (is.null(from)) -Inf else string_to_seconds(from)
  to_secs <- if (is.null(to)) Inf else string_to_seconds(to)

  if (from_secs > to_secs) {
    cli::cli_abort(
      paste0(
        "{.arg from} ({.val {from}}) must not be later than {.arg to} ",
        "({.val {to}})."
      ),
      class = "gtfstools_invalid_time_of_day",
      call = parent.frame()
    )
  }

  return(c(from_secs, to_secs))
}



# cli formats every element of a vector, even those it doesn't show, which
# takes seconds for tens of thousands of ids. so messages list only the first
# ids, followed by a note on how many were left out. without the note, cli
# adds "and" before the last listed id

abbreviate_ids <- function(ids, n = 5) {
  n_more <- length(ids) - n

  if (n_more <= 0) return(list(shown = ids, more = ""))

  shown <- cli::cli_vec(utils::head(ids, n), list("vec-last" = ", "))
  return(list(shown = shown, more = paste0(" and ", n_more, " more")))
}
