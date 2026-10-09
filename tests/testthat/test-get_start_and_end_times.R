spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)
ggl_gtfs <- read_gtfs(ggl_path)
ber_gtfs <- read_gtfs(ber_path)

# the fixtures can't show the effect of the filters (ggl's two trips in
# stop_times have the same times), so a small feed is built: trip "A" runs on
# weekdays, trip "B" on weekends, and trip "C" is listed in stop_times but not
# in trips. 2024-01-01 is a monday and 2024-01-06 a saturday

small_gtfs <- gtfsio::new_gtfs(
  list(
    calendar = data.table::data.table(
      service_id = c("WD", "WE"),
      monday = c(1L, 0L),
      tuesday = c(1L, 0L),
      wednesday = c(1L, 0L),
      thursday = c(1L, 0L),
      friday = c(1L, 0L),
      saturday = c(0L, 1L),
      sunday = c(0L, 1L),
      start_date = data.table::as.IDate(c("2024-01-01", "2024-01-01")),
      end_date = data.table::as.IDate(c("2024-01-31", "2024-01-31"))
    ),
    trips = data.table::data.table(
      route_id = c("r1", "r1"),
      service_id = c("WD", "WE"),
      trip_id = c("A", "B")
    ),
    stop_times = data.table::data.table(
      trip_id = c("A", "A", "B", "B", "C", "C"),
      arrival_time = c(
        "06:00:00", "06:30:00", "22:00:00", "25:10:00", "04:00:00", "26:00:00"
      ),
      departure_time = c(
        "06:00:00", "06:30:00", "22:00:00", "25:10:00", "04:00:00", "26:00:00"
      ),
      stop_id = c("s1", "s2", "s1", "s2", "s1", "s2"),
      stop_sequence = rep(1:2, 3)
    )
  ),
  "dt_gtfs"
)

na_result <- c(start_time = NA_character_, end_time = NA_character_)

tester <- function(gtfs = small_gtfs, trip_id = NULL, date = NULL) {
  get_start_and_end_times(gtfs, trip_id, date)
}


# tests -------------------------------------------------------------------


test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(small_gtfs)))
  expect_error(tester(trip_id = 1))
  expect_error(tester(trip_id = NA_character_))
  expect_error(tester(date = "20241301"), class = "gtfstools_bad_date_error")

  # trips are needed to restrict by date

  no_trips_gtfs <- copy_gtfs_without_file(small_gtfs, "trips")
  expect_error(tester(no_trips_gtfs, date = "20240101"))
  expect_error(tester(copy_gtfs_without_file(small_gtfs, "stop_times")))
})

test_that("returns a named character vector", {
  result <- tester(spo_gtfs)
  expect_type(result, "character")
  expect_named(result, c("start_time", "end_time"))

  # spo's trips are frequency-based, and the earliest template starts at
  # midnight

  expect_identical(result, c(start_time = "00:00:00", end_time = "19:02:00"))
  expect_identical(
    tester(ber_gtfs),
    c(start_time = "04:50:00", end_time = "23:18:30")
  )
})

test_that("restricts to the given trips and dates", {
  expect_identical(
    tester(),
    c(start_time = "04:00:00", end_time = "26:00:00")
  )
  expect_identical(
    tester(trip_id = "B"),
    c(start_time = "22:00:00", end_time = "25:10:00")
  )

  # trip "C" is not in trips, so it's never active

  expect_identical(
    tester(date = "20240101"),
    c(start_time = "06:00:00", end_time = "06:30:00")
  )
  expect_identical(
    tester(date = data.table::as.IDate("2024-01-01")),
    c(start_time = "06:00:00", end_time = "06:30:00")
  )
  expect_identical(
    tester(date = as.Date(c("2024-01-01", "2024-01-06"))),
    c(start_time = "06:00:00", end_time = "25:10:00")
  )

  # in ggl, only trip "AWE1" is both in stop_times and in trips

  expect_identical(
    tester(ggl_gtfs, date = "20060701"),
    c(start_time = "00:06:10", end_time = "00:06:45")
  )
  expect_identical(
    tester(trip_id = "B", date = "2024-01-06"),
    c(start_time = "22:00:00", end_time = "25:10:00")
  )

  # empty results are NA, without a warning

  expect_no_warning(result <- tester(trip_id = "B", date = "20240101"))
  expect_identical(result, na_result)
  expect_identical(tester(date = "20250101"), na_result)
  expect_identical(tester(trip_id = character(0)), na_result)

  no_calendar_gtfs <- copy_gtfs_without_file(small_gtfs, "calendar")
  expect_no_warning(result <- tester(no_calendar_gtfs, date = "20240101"))
  expect_identical(result, na_result)
})

test_that("compares times as seconds and ignores empty times", {
  gtfs <- small_gtfs
  gtfs$stop_times <- data.table::copy(gtfs$stop_times)[1:3]
  gtfs$stop_times[, departure_time := c("5:00:00", "", NA)]
  gtfs$stop_times[, arrival_time := c("", NA, "24:30:00")]
  expect_identical(
    tester(gtfs),
    c(start_time = "05:00:00", end_time = "24:30:00")
  )

  # malformed times are ignored with a warning

  gtfs$stop_times[, departure_time := c("bad", "07:00:00", "08:00:00")]
  expect_warning(
    result <- tester(gtfs),
    class = "gtfstools_malformed_time"
  )
  expect_identical(result, c(start_time = "07:00:00", end_time = "24:30:00"))

  gtfs$stop_times[, departure_time := NA_character_]
  gtfs$stop_times[, arrival_time := ""]
  expect_identical(tester(gtfs), na_result)
})

test_that("raises warning if a given trip_id doesn't exist", {
  expect_warning(
    result <- tester(trip_id = c("B", "unknown")),
    "doesn't contain the following trip_id"
  )
  expect_identical(result, c(start_time = "22:00:00", end_time = "25:10:00"))
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(ber_path)
  gtfs <- read_gtfs(ber_path)
  expect_identical(original_gtfs, gtfs)

  result <- tester(gtfs, trip_id = "146389748", date = "20210101")
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})
