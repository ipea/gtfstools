data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
trip_id <- "CPTM L07-0"

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   method = "shapes",
                   by = "trip",
                   unit = "km/h") {
  get_trip_speed(gtfs, trip_id, method, by, unit)
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

  no_time_gtfs <- copy_gtfs_without_field(gtfs, "stop_times", "arrival_time")
  expect_error(tester(no_time_gtfs), class = "missing_required_field")
})

test_that("sort_sequence is deprecated", {
  # the warning is raised only once, even with by = "segment"

  warnings <- character(0)
  withCallingHandlers(
    get_trip_speed(gtfs, trip_id, by = "segment", sort_sequence = TRUE),
    deprecated_sort_sequence = function(cnd) {
      warnings <<- c(warnings, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(warnings, 1)

  expect_error(
    get_trip_speed(gtfs, trip_id, sort_sequence = FALSE),
    class = "gtfstools_defunct_sort_sequence_error"
  )
})

test_that("outputs data.tables with the right columns and types", {
  trip_speeds <- tester()
  expect_s3_class(trip_speeds, "data.table")
  expect_identical(names(trip_speeds), c("route_id", "trip_id", "speed"))
  expect_type(trip_speeds$speed, "double")

  segment_speeds <- tester(trip_id = trip_id, by = "segment")
  expect_identical(
    names(segment_speeds),
    c("route_id", "trip_id", "segment", "from_stop_id", "to_stop_id", "speed")
  )
  expect_type(segment_speeds$segment, "integer")

  empty_speeds <- suppressWarnings(tester(trip_id = "nonexistent"))
  expect_identical(nrow(empty_speeds), 0L)
  expect_identical(names(empty_speeds), c("route_id", "trip_id", "speed"))
  expect_type(empty_speeds$route_id, "character")

  empty_segments <- suppressWarnings(
    tester(trip_id = "nonexistent", by = "segment")
  )
  expect_identical(nrow(empty_segments), 0L)
  expect_identical(
    names(empty_segments),
    c("route_id", "trip_id", "segment", "from_stop_id", "to_stop_id", "speed")
  )
  expect_type(empty_segments$route_id, "character")
})

test_that("route_id comes from trips, and is NA for trips not in trips", {
  dropped_trip <- gtfs$trips$trip_id[1]
  partial_trips_gtfs <- gtfs
  partial_trips_gtfs$trips <- gtfs$trips[trip_id != dropped_trip]

  trip_speeds <- tester(partial_trips_gtfs, method = "euclidean")
  expected_route_id <- partial_trips_gtfs$trips$route_id[
    data.table::chmatch(trip_speeds$trip_id, partial_trips_gtfs$trips$trip_id)
  ]
  expect_identical(trip_speeds$route_id, expected_route_id)
  expect_true(dropped_trip %chin% trip_speeds$trip_id)
  expect_identical(
    trip_speeds[trip_id == dropped_trip]$route_id,
    NA_character_
  )
})

test_that("raises an error if trips lacks route_id", {
  no_route_gtfs <- copy_gtfs_without_field(gtfs, "trips", "route_id")
  expect_error(tester(no_route_gtfs), class = "missing_required_field")
  expect_error(
    tester(no_route_gtfs, method = "euclidean"),
    class = "missing_required_field"
  )
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

  in_mph <- tester(trip_id = trip_id, unit = "mph")
  expect_equal(in_mph$speed, in_kmh$speed / 1.609344)

  in_kmh <- tester(trip_id = trip_id, by = "segment")
  in_mph <- tester(trip_id = trip_id, by = "segment", unit = "mph")
  expect_equal(in_mph$speed, in_kmh$speed / 1.609344)
})

test_that("doesn't change the given gtfs", {
  original_gtfs <- read_gtfs(data_path)
  test_gtfs <- read_gtfs(data_path)
  expect_identical(original_gtfs, test_gtfs)

  for (by in c("trip", "segment")) {
    result <- tester(test_gtfs, by = by)
    expect_identical(original_gtfs, test_gtfs)

    result <- get_trip_speed(test_gtfs, by = by, from = "07:00:00")
    expect_identical(original_gtfs, test_gtfs)
    expect_null(data.table::indices(test_gtfs$stop_times))
  }
})

# departure time of the first stop of each trip, and of each segment, as
# written in stop_times

first_departures <- function(gtfs) {
  st <- data.table::copy(gtfs$stop_times)
  data.table::setorderv(st, c("trip_id", "stop_sequence"))
  return(st[!duplicated(st$trip_id), .(trip_id, departure_time)])
}

test_that("from and to select the trips and segments as get_trip_length()", {
  first <- first_departures(gtfs)
  expected <- first$trip_id[
    first$departure_time >= "07:00:00" & first$departure_time <= "10:59:59"
  ]

  result <- get_trip_speed(gtfs, from = "07:00:00", to = "10:59:59")
  expect_identical(result, tester(trip_id = expected))

  # the segments of the three functions agree, also when stop_times is not
  # ordered

  unordered_gtfs <- read_gtfs(data_path)
  unordered_gtfs$stop_times <- unordered_gtfs$stop_times[
    rev(seq_len(nrow(unordered_gtfs$stop_times)))
  ]

  speeds <- get_trip_speed(
    unordered_gtfs,
    by = "segment",
    from = "04:00:00",
    to = "04:30:00"
  )
  lengths <- get_trip_length(
    unordered_gtfs,
    by = "segment",
    from = "04:00:00",
    to = "04:30:00"
  )
  durations <- get_trip_segment_duration(
    unordered_gtfs,
    from = "04:00:00",
    to = "04:30:00"
  )
  expect_true(nrow(speeds) > 0)
  expect_identical(
    speeds[, .(trip_id, segment)],
    lengths[, .(trip_id, segment)]
  )
  expect_identical(
    speeds[, .(trip_id, segment)],
    durations[, .(trip_id, segment)]
  )
  expect_identical(
    speeds,
    tester(unordered_gtfs, by = "segment")[
      speeds[, .(trip_id, segment)],
      on = c("trip_id", "segment")
    ]
  )

  empty <- get_trip_speed(gtfs, from = "99:00:00")
  expect_identical(nrow(empty), 0L)
  expect_identical(names(empty), c("route_id", "trip_id", "speed"))

  expect_error(
    get_trip_speed(gtfs, from = "09:00:00", to = "08:00:00"),
    class = "gtfstools_invalid_time_of_day"
  )
})

test_that("from and to raise the warnings only once", {
  for (by in c("trip", "segment")) {
    warnings <- character(0)
    withCallingHandlers(
      get_trip_speed(
        gtfs,
        c(trip_id, "nonexistent"),
        by = by,
        from = "00:00:00"
      ),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    expect_length(warnings, 1)
  }
})

test_that("fixes times after midnight written as early morning times", {
  poa_gtfs <- read_gtfs(
    system.file("extdata/poa_gtfs.zip", package = "gtfstools")
  )

  # this trip runs from 23:10:00 to "00:02:00" (i.e. 52 minutes)

  speed <- get_trip_speed(poa_gtfs, "T2-1@1#2310")
  trip_length <- get_trip_length(poa_gtfs, "T2-1@1#2310")
  expect_equal(speed$speed, trip_length$length / (52 / 60))
})
