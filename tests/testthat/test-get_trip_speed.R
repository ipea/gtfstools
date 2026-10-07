data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
trip_id <- "CPTM L07-0"

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   method = "shapes",
                   by = "trip",
                   unit = "km/h",
                   sort_sequence = TRUE) {
  get_trip_speed(gtfs, trip_id, method, by, unit, sort_sequence)
}

# tests -------------------------------------------------------------------

test_that("raises errors due to incorrect input types/value", {
  expect_error(tester(unclass(gtfs)))
  expect_error(tester(trip_id = NA))
  expect_error(tester(trip_id = factor(trip_id)))
  expect_error(tester(method = "straight"))
  expect_error(tester(by = "stop"))
  expect_error(tester(unit = "km"))
  expect_error(tester(unit = c("km/h", "m/s")))
  expect_error(tester(sort_sequence = NA))

  no_time_gtfs <- copy_gtfs_without_field(gtfs, "stop_times", "arrival_time")
  expect_error(tester(no_time_gtfs), class = "missing_required_field")
})

test_that("outputs data.tables with the right columns and types", {
  trip_speeds <- tester()
  expect_s3_class(trip_speeds, "data.table")
  expect_identical(names(trip_speeds), c("trip_id", "speed"))
  expect_type(trip_speeds$speed, "double")

  segment_speeds <- tester(trip_id = trip_id, by = "segment")
  expect_identical(
    names(segment_speeds),
    c("trip_id", "segment", "from_stop_id", "to_stop_id", "speed")
  )
  expect_type(segment_speeds$segment, "integer")

  empty_speeds <- suppressWarnings(tester(trip_id = "nonexistent"))
  expect_identical(nrow(empty_speeds), 0L)
  expect_identical(names(empty_speeds), c("trip_id", "speed"))
})

test_that("speeds are lengths divided by durations", {
  for (method in c("shapes", "euclidean")) {
    lengths <- get_trip_length(gtfs, method = method)
    durations <- get_trip_duration(gtfs, unit = "h")
    expected <- lengths[durations, on = "trip_id", nomatch = NULL]
    expected[, speed := length / duration]

    speeds <- tester(method = method)
    expect_equal(
      speeds$speed,
      expected$speed[match(speeds$trip_id, expected$trip_id)]
    )

    # segment speeds

    segment_lengths <- get_trip_length(gtfs, trip_id, method, by = "segment")
    segment_durations <- get_trip_segment_duration(gtfs, trip_id, unit = "h")
    segment_speeds <- tester(trip_id = trip_id, method = method, by = "segment")
    expect_equal(
      segment_speeds$speed,
      segment_lengths$length / segment_durations$duration
    )
  }
})

test_that("speeds are NA when durations are missing or not positive", {
  times_gtfs <- read_gtfs(data_path)
  times_gtfs$stop_times <- data.table::copy(times_gtfs$stop_times)
  trip_rows <- which(times_gtfs$stop_times$trip_id == trip_id)

  # blank time at the third stop and zero duration in the fifth segment

  times_gtfs$stop_times[
    trip_rows[3],
    `:=`(arrival_time = "", departure_time = "")
  ]
  times_gtfs$stop_times[
    trip_rows[6],
    arrival_time := times_gtfs$stop_times$departure_time[trip_rows[5]]
  ]

  segment_speeds <- tester(times_gtfs, trip_id, by = "segment")
  expect_true(all(is.na(segment_speeds$speed[c(2, 3, 5)])))
  expect_false(anyNA(segment_speeds$speed[-c(2, 3, 5)]))

  # a trip whose first and last times are the same has no positive duration

  zero_gtfs <- read_gtfs(data_path)
  zero_gtfs$stop_times <- data.table::copy(zero_gtfs$stop_times)
  zero_gtfs$stop_times[
    trip_rows,
    `:=`(arrival_time = "08:00:00", departure_time = "08:00:00")
  ]
  expect_true(is.na(tester(zero_gtfs, trip_id)$speed))
})

test_that("warnings are raised only once", {
  no_shapes_gtfs <- copy_gtfs_without_file(gtfs, "shapes")

  for (by in c("trip", "segment")) {
    expect_warning(
      result <- tester(no_shapes_gtfs, trip_id, by = by),
      class = "gtfstools_shapes_unavailable"
    )
    expect_identical(
      result,
      tester(trip_id = trip_id, method = "euclidean", by = by)
    )

    warnings <- character(0)
    withCallingHandlers(
      tester(trip_id = c(trip_id, "nonexistent"), by = by),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    expect_length(warnings, 1)

    warnings <- character(0)
    withCallingHandlers(
      result <- tester(trip_id = "nonexistent", by = by),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    expect_length(warnings, 1)
    expect_identical(nrow(result), 0L)
  }

  expect_warning(
    result <- get_trip_speed(gtfs, trip_id, file = "stop_times"),
    regexp = "get_trip_speed",
    class = "deprecated_file"
  )
  expect_identical(result, tester(trip_id = trip_id, method = "euclidean"))
})

test_that("outputs speeds in the correct unit", {
  in_kmh <- tester(trip_id = trip_id)
  in_ms <- tester(trip_id = trip_id, unit = "m/s")
  expect_equal(in_ms$speed, in_kmh$speed / 3.6)
})

test_that("doesn't change the given gtfs", {
  original_gtfs <- read_gtfs(data_path)
  test_gtfs <- read_gtfs(data_path)
  expect_identical(original_gtfs, test_gtfs)

  for (by in c("trip", "segment")) {
    result <- tester(test_gtfs, by = by)
    expect_identical(original_gtfs, test_gtfs)
  }
})
