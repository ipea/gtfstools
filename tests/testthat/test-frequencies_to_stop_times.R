data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
trip_id <- "CPTM L07-0"

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   force = FALSE) {
  frequencies_to_stop_times(gtfs, trip_id, force)
}


# tests -------------------------------------------------------------------


test_that("raises errors due to incorrect input types/value", {
  no_class_gtfs <- structure(gtfs, class = NULL)
  expect_error(tester(no_class_gtfs))
  expect_error(tester(trip_id = as.factor(trip_id)))
  expect_error(tester(trip_id = NA))
  expect_error(tester(force = 1))
  expect_error(tester(force = NA))
})

test_that("raises warning if a non-existent trip_id is specified", {
  expect_warning(tester(trip_id = "a"))
  expect_warning(tester(trip_id = c("a", trip_id)))
})

test_that("specifying trip_id = character(0) results in the same gtfs", {
  same_gtfs <- tester(trip_id = character(0))

  # should be identical to 'gtfs', some tables' indices aside
  data.table::setindex(gtfs$stop_times, NULL)
  data.table::setindex(gtfs$trips, NULL)
  expect_identical(gtfs, same_gtfs)
})

test_that("calculates first departure times and new trip_ids correctly", {
  env <- environment()
  departures <- gtfs$frequencies[trip_id == get("trip_id", envir = env)]
  departures[
    ,
    `:=`(
      start_time_secs = string_to_seconds(start_time),
      end_time_secs = string_to_seconds(end_time)
    )
  ]
  departures[
    ,
    departures := mapply(
      seq,
      start_time_secs,
      end_time_secs - 1L,
      headway_secs
    )
  ]
  expected_first_departures <- unlist(departures$departures)
  expected_first_departures <- unique(expected_first_departures)

  converted_gtfs <- tester(trip_id = trip_id)
  first_departures <- converted_gtfs$stop_times[
    grepl(get("trip_id", envir = env), trip_id)
  ]
  first_departures <- first_departures[
    first_departures[, .I[1], by = trip_id]$V1
  ]

  # first departure times are correct
  actual_first_departures <- first_departures$departure_time
  actual_first_departures <- string_to_seconds(actual_first_departures)
  expect_identical(expected_first_departures, actual_first_departures)

  # trip names are correct
  n_trips <- length(actual_first_departures)
  new_trips_names <- paste0(trip_id, "_", 1:n_trips)
  expect_identical(new_trips_names, first_departures$trip_id)

  # old trip is not listed in none of frequencies, stop_times and trips
  expect_false(any(converted_gtfs$stop_times$trip_id == trip_id))
  expect_false(any(converted_gtfs$frequencies$trip_id == trip_id))
  expect_false(any(converted_gtfs$trips$trip_id == trip_id))

  # new trips are also listed in trips
  expect_true(sum(grepl(trip_id, converted_gtfs$trips$trip_id)) == 161)
})

test_that("calculates other stop_times departure and arrival times correctly", {
  env <- environment()
  converted_gtfs <- tester(trip_id = trip_id)

  create_template <- function(stop_times) {
    template <- data.table::copy(stop_times)[
      ,
      `:=`(
        departure_time_secs = string_to_seconds(departure_time),
        arrival_time_secs = string_to_seconds(arrival_time)
      )
    ]
    first_departure <- min(template$departure_time_secs)
    template[
      ,
      `:=`(
        departure_time_secs = departure_time_secs - first_departure,
        arrival_time_secs = arrival_time_secs - first_departure
      )
    ]
    template[, .(departure_time_secs, arrival_time_secs)]
  }

  original_template <- create_template(
    gtfs$stop_times[trip_id == get("trip_id", envir = env)]
  )

  new_templates <- converted_gtfs$stop_times[
    grepl(get("trip_id", envir = env), trip_id)
  ]
  new_templates <- new_templates[, .(data = list(.SD)), by = trip_id]
  new_templates[, templates := lapply(data, create_template)]
  new_templates[
    ,
    is_identical := lapply(
      templates,
      function(t) identical(t, original_template)
    )
  ]
  expect_true(all(unlist(new_templates$is_identical)))
})

test_that("frequencies table is removed when all trips are converted", {
  converted_gtfs <- tester()
  expect_null(converted_gtfs$frequencies)
})

test_that("doesn't change original gtfs", {
  gtfs <- read_gtfs(data_path)
  original_gtfs <- read_gtfs(data_path)

  converted_gtfs <- tester()

  expect_false(identical(gtfs, original_gtfs))
  data.table::setindex(gtfs$frequencies, NULL)
  data.table::setindex(gtfs$stop_times, NULL)
  data.table::setindex(gtfs$trips, NULL)
  expect_identical(gtfs, original_gtfs)

  # should also work if gtfs contain time-in-seconds columns
  add_time_cols <- function(gtfs) {
    gtfs$stop_times[
      ,
      `:=`(
        departure_time_secs = string_to_seconds(departure_time),
        arrival_time_secs = string_to_seconds(arrival_time)
      )
    ]
    gtfs$frequencies[
      ,
      `:=`(
        start_time_secs = string_to_seconds(start_time),
        end_time_secs = string_to_seconds(end_time)
      )
    ]
    return(gtfs)
  }
  gtfs <- add_time_cols(gtfs)
  original_gtfs <- add_time_cols(original_gtfs)
  expect_identical(gtfs, original_gtfs)

  converted_gtfs <- tester()
  expect_false(identical(gtfs, original_gtfs))
  data.table::setindex(gtfs$frequencies, NULL)
  data.table::setindex(gtfs$stop_times, NULL)
  data.table::setindex(gtfs$trips, NULL)
  expect_identical(gtfs, original_gtfs)
})

test_that("converted gtfs keep time-in-seconds cols if present", {
  gtfs <- read_gtfs(data_path)
  gtfs$stop_times[
    ,
    `:=`(
      departure_time_secs = string_to_seconds(departure_time),
      arrival_time_secs = string_to_seconds(arrival_time)
    )
  ]
  gtfs$frequencies[
    ,
    `:=`(
      start_time_secs = string_to_seconds(start_time),
      end_time_secs = string_to_seconds(end_time)
    )
  ]

  converted_gtfs <- tester(trip_id = trip_id)
  expect_true(
    gtfsio::check_field_exists(
      converted_gtfs,
      "stop_times",
      "departure_time_secs"
    )
  )
  expect_true(
    gtfsio::check_field_exists(
      converted_gtfs,
      "stop_times",
      "arrival_time_secs"
    )
  )
  expect_true(
    gtfsio::check_field_exists(converted_gtfs, "frequencies", "start_time_secs")
  )
  expect_true(
    gtfsio::check_field_exists(converted_gtfs, "frequencies", "end_time_secs")
  )
})

test_that("outputs a dt_gtfs", {
  dt_gtfs_class <- c("dt_gtfs", "gtfs", "list")
  converted_gtfs <- tester(trip_id = trip_id)
  expect_s3_class(converted_gtfs, dt_gtfs_class)
  expect_type(converted_gtfs, "list")
  invisible(lapply(converted_gtfs, expect_s3_class, "data.table"))
})

env <- environment()
gtfs$stop_times <- gtfs$stop_times[trip_id != get("trip_id", envir = env)]

test_that("raises warning if a trip is listed in freq but no in stop_times", {
  expect_warning(converted_gtfs <- tester(trip_id = trip_id))
})

test_that("force argument works correctly", {
  # by default leaves trips not described in stop_times untouched
  suppressWarnings(converted_gtfs <- tester(trip_id = trip_id))
  expect_true(trip_id %chin% converted_gtfs$frequencies$trip_id)
  expect_true(trip_id %chin% converted_gtfs$trips$trip_id)

  # not true when force = TRUE
  suppressWarnings(converted_gtfs <- tester(trip_id = trip_id, force = TRUE))
  expect_false(trip_id %chin% converted_gtfs$frequencies$trip_id)
  expect_false(trip_id %chin% converted_gtfs$trips$trip_id)
  expect_true(sum(grepl(trip_id, converted_gtfs$trips$trip_id)) == 161)
})

test_that("works ok if trip is not in frequencies but is in stop_times", {
  trip <- "CPTM L07-1"
  gtfs$frequencies <- gtfs$frequencies[trip_id != trip]

  # expected result is not to do anything to that trip
  expect_warning(converted_gtfs <- tester(trip_id = trip))
  expect_identical(converted_gtfs, tester(trip_id = character(0)))
})

test_that("raises informative errors if frequencies has invalid entries", {
  # end_time before start_time

  bad_gtfs <- read_gtfs(data_path)
  bad_gtfs$frequencies[1, end_time := "00:00:00"]
  bad_trip <- bad_gtfs$frequencies$trip_id[1]
  expect_error(
    tester(bad_gtfs),
    class = "gtfstools_invalid_frequencies",
    regexp = bad_trip,
    fixed = TRUE
  )

  # no headway between different start_time and end_time

  bad_gtfs <- read_gtfs(data_path)
  bad_gtfs$frequencies[1, headway_secs := 0L]
  expect_error(tester(bad_gtfs), class = "gtfstools_invalid_frequencies")

  # blank start_time

  bad_gtfs <- read_gtfs(data_path)
  bad_gtfs$frequencies[1, start_time := ""]
  expect_error(tester(bad_gtfs), class = "gtfstools_invalid_frequencies")

  # the given gtfs is not changed when the error is raised

  original_gtfs <- read_gtfs(data_path)
  original_gtfs$frequencies[1, start_time := ""]
  expect_identical(bad_gtfs, original_gtfs)
})

test_that("an entry with equal start_time and end_time creates one trip", {
  one_trip_gtfs <- read_gtfs(data_path)
  one_trip_gtfs$frequencies <- one_trip_gtfs$frequencies[1]
  one_trip_gtfs$frequencies[, `:=`(end_time = start_time, headway_secs = 0L)]
  converted_trip <- one_trip_gtfs$frequencies$trip_id

  converted_gtfs <- tester(one_trip_gtfs)
  new_trips <- converted_gtfs$trips$trip_id
  expect_identical(
    new_trips[startsWith(new_trips, paste0(converted_trip, "_"))],
    paste0(converted_trip, "_1")
  )
})

test_that("no trip departs at an entry's end_time", {
  # 06:00:00 to 07:00:00 every 30 minutes yields departures at 06:00:00 and
  # 06:30:00 only, as end_time is exclusive in the GTFS specification

  exclusive_gtfs <- read_gtfs(data_path)
  exclusive_gtfs$frequencies <- data.table::data.table(
    trip_id = "CPTM L07-0",
    start_time = "06:00:00",
    end_time = "07:00:00",
    headway_secs = 1800L
  )

  converted_gtfs <- tester(exclusive_gtfs)
  new_trips <- converted_gtfs$stop_times[startsWith(trip_id, "CPTM L07-0_")]
  first_departures <- new_trips[, .(first = min(departure_time)), by = trip_id]
  expect_identical(first_departures$first, c("06:00:00", "06:30:00"))
})

test_that("raises informative error if a trip has no departure times", {
  bad_gtfs <- read_gtfs(data_path)
  bad_gtfs$stop_times[trip_id == "CPTM L07-0", departure_time := ""]
  expect_error(
    tester(bad_gtfs),
    class = "gtfstools_empty_template",
    regexp = "CPTM L07-0",
    fixed = TRUE
  )

  # the given gtfs is not changed when the error is raised

  original_gtfs <- read_gtfs(data_path)
  original_gtfs$stop_times[trip_id == "CPTM L07-0", departure_time := ""]
  expect_identical(bad_gtfs, original_gtfs)
})

test_that("duplicated trip_ids are converted only once", {
  full_gtfs <- read_gtfs(data_path)
  expect_identical(
    tester(full_gtfs, trip_id = c(trip_id, trip_id)),
    tester(full_gtfs, trip_id = trip_id)
  )
})
