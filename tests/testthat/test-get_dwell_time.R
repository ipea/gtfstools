spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(spo_path)
ggl_gtfs <- read_gtfs(ggl_path)

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   stop_id = NULL,
                   unit = "s",
                   from = NULL,
                   to = NULL) {
  get_dwell_time(gtfs, trip_id, stop_id, unit, from, to)
}

# small hand-built feed with a single trip, "t", whose rows are not ordered by
# stop_sequence. it visits A twice (a loop), C with blank times, and runs past
# midnight. its dwell times are 60 (A), 30 (B), NA (C), 0 (A) and 60 (D)

hand_gtfs <- read_gtfs(spo_path)
hand_gtfs$stop_times <- data.table::data.table(
  trip_id = "t",
  stop_id = c("C", "A", "B", "A", "D"),
  stop_sequence = c(3L, 1L, 2L, 4L, 5L),
  arrival_time = c("", "23:59:00", "24:05:00", "24:10:00", "24:20:00"),
  departure_time = c("", "24:00:00", "24:05:30", "24:10:00", "24:21:00")
)

# variant of the hand-built feed with an extra visit, to E, whose arrival time
# is blank but whose departure time is not

half_blank_gtfs <- read_gtfs(spo_path)
half_blank_gtfs$stop_times <- rbind(
  hand_gtfs$stop_times,
  data.table::data.table(
    trip_id = "t",
    stop_id = "E",
    stop_sequence = 6L,
    arrival_time = "",
    departure_time = "24:25:00"
  )
)

# tests -------------------------------------------------------------------

test_that("raises errors due to incorrect input types/value", {
  no_class_gtfs <- gtfs
  attr(no_class_gtfs, "class") <- NULL
  expect_error(tester(no_class_gtfs))
  expect_error(tester(trip_id = as.factor("CPTM L07-0")))
  expect_error(tester(trip_id = NA))
  expect_error(tester(stop_id = as.factor("18920")))
  expect_error(tester(stop_id = NA))
  expect_error(tester(unit = "mins"))
  expect_error(tester(unit = c("s", "min")))
  expect_error(tester(unit = NA))
})

test_that("raises errors if gtfs doesn't have required files/fields", {
  no_stop_times <- copy_gtfs_without_file(gtfs, "stop_times")
  expect_error(tester(no_stop_times))

  for (field in c(
    "trip_id",
    "stop_id",
    "stop_sequence",
    "arrival_time",
    "departure_time"
  )) {
    no_field <- copy_gtfs_without_field(gtfs, "stop_times", field)
    expect_error(tester(no_field))
  }

  wrong_class <- copy_gtfs_diff_field_class(
    gtfs,
    "stop_times",
    "stop_sequence",
    "character"
  )
  expect_error(tester(wrong_class))
})

test_that("raises warnings if a non_existent trip_id/stop_id is given", {
  expect_warning(
    tester(trip_id = c("CPTM L07-0", "ola")),
    class = "gtfstools_invalid_trip_id"
  )
  expect_warning(
    tester(stop_id = c("18920", "ola")),
    class = "gtfstools_invalid_stop_id"
  )

  # repeated missing ids are listed once

  warning_message <- tryCatch(
    tester(trip_id = c("ola", "ola")),
    warning = conditionMessage
  )
  expect_identical(
    lengths(regmatches(warning_message, gregexpr("ola", warning_message))),
    1L
  )
})

test_that("outputs a data.table with adequate columns' classes", {
  expected_names <- c("trip_id", "stop_id", "stop_sequence", "dwell_time")

  check_classes <- function(dwell) {
    expect_s3_class(dwell, "data.table")
    expect_identical(names(dwell), expected_names)
    expect_vector(dwell$trip_id, character(0))
    expect_vector(dwell$stop_id, character(0))
    expect_vector(dwell$stop_sequence, integer(0))
    expect_vector(dwell$dwell_time, numeric(0))
  }

  for (unit in c("s", "min", "h", "d")) check_classes(tester(unit = unit))

  # empty results keep the classes

  check_classes(tester(trip_id = character(0)))
  check_classes(suppressWarnings(tester(trip_id = "ola")))
  check_classes(tester(trip_id = "CPTM L07-0", stop_id = "18960"))
})

test_that("selects the visits of every given trip to every given stop", {
  expect_identical(nrow(tester()), nrow(gtfs$stop_times))

  dwell <- tester(stop_id = "18960")
  expect_setequal(
    dwell$trip_id,
    c("CPTM L08-0", "CPTM L08-1", "CPTM L09-0", "CPTM L09-1")
  )
  expect_true(all(dwell$stop_id == "18960"))

  dwell <- tester(
    trip_id = c("CPTM L08-0", "CPTM L09-0", "CPTM L07-0"),
    stop_id = c("18960", "18920")
  )
  expect_identical(
    dwell[, paste(trip_id, stop_id)],
    c("CPTM L07-0 18920", "CPTM L08-0 18960", "CPTM L09-0 18960")
  )

  dwell <- tester(trip_id = "CPTM L07-0")
  expect_identical(dwell$stop_sequence, sort(dwell$stop_sequence))
})

test_that("calculates dwell times correctly", {
  dwell <- tester(hand_gtfs)
  expect_identical(dwell$stop_id, c("A", "B", "C", "A", "D"))
  expect_identical(dwell$stop_sequence, 1:5)
  expect_identical(dwell$dwell_time, c(60, 30, NA, 0, 60))

  # ggl's AWE1 has a 10 seconds dwell time at S3 and blank times at S2 and S5

  dwell <- tester(ggl_gtfs, trip_id = "AWE1")
  expect_identical(dwell$stop_id, c("S1", "S2", "S3", "S5", "S6"))
  expect_identical(dwell$dwell_time, c(0, NA, 10, NA, 0))

  # negative dwell times are returned as they are

  negative_gtfs <- read_gtfs(spo_path)
  negative_gtfs$stop_times <- data.table::copy(hand_gtfs$stop_times)
  negative_gtfs$stop_times[stop_id == "B", departure_time := "24:04:00"]
  expect_identical(tester(negative_gtfs, stop_id = "B")$dwell_time, -60)
})

test_that("outputs dwell times in the correct unit", {
  dwell_s <- tester(hand_gtfs)$dwell_time
  expect_equal(tester(hand_gtfs, unit = "min")$dwell_time, dwell_s / 60)
  expect_equal(tester(hand_gtfs, unit = "h")$dwell_time, dwell_s / 3600)
  expect_equal(tester(hand_gtfs, unit = "d")$dwell_time, dwell_s / 86400)
})

test_that("ignores existing _secs columns", {
  secs_gtfs <- convert_time_to_seconds(hand_gtfs)
  secs_gtfs$stop_times[stop_id == "B", departure_time := "24:06:00"]
  expect_identical(tester(secs_gtfs, stop_id = "B")$dwell_time, 60)
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(spo_path)
  gtfs <- read_gtfs(spo_path)
  expect_identical(original_gtfs, gtfs)

  invisible(tester(gtfs))
  expect_identical(original_gtfs, gtfs)

  invisible(tester(gtfs, trip_id = "CPTM L07-0", stop_id = "18920"))
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})

test_that("only returns the visits that arrive within the time of day", {
  expect_error(tester(from = "7:00:00"))
  expect_error(
    tester(from = "09:00:00", to = "07:00:00"),
    class = "gtfstools_invalid_time_of_day"
  )

  # the time of day is inclusive. blank arrivals are never included

  dwell <- tester(half_blank_gtfs, from = "24:00:00", to = "24:30:00")
  expect_identical(dwell$stop_id, c("B", "A", "D"))
  expect_identical(dwell$stop_sequence, c(2L, 4L, 5L))
  expect_identical(dwell$dwell_time, c(30, 0, 60))

  dwell <- tester(hand_gtfs, from = "24:00:00", to = "24:10:00")
  expect_identical(dwell$stop_sequence, c(2L, 4L))

  dwell <- tester(hand_gtfs, to = "24:00:00")
  expect_identical(dwell$stop_sequence, 1L)

  # a time of day without visits returns an empty table, silently

  expect_silent(dwell <- tester(hand_gtfs, from = "12:00:00", to = "13:00:00"))
  expect_identical(
    names(dwell),
    c("trip_id", "stop_id", "stop_sequence", "dwell_time")
  )
  expect_identical(nrow(dwell), 0L)
  expect_vector(dwell$dwell_time, numeric(0))
})
