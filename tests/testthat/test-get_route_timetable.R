ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
ber_gtfs <- read_gtfs(ber_path)

# a small feed is built, so that the order of the trips can be checked. service
# "WD" runs on weekdays (and is also added on tuesday 2024-01-02 by
# calendar_dates, which must not duplicate rows) and "WE" on weekends.
# 2024-01-01 is a monday and 2024-01-06 a saturday. trip "C" has no times,
# trip "D" is not in trips, and "7:05:00" sorts before "10:00:00" only as a
# time

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
    calendar_dates = data.table::data.table(
      service_id = "WD",
      date = data.table::as.IDate("2024-01-02"),
      exception_type = 1L
    ),
    trips = data.table::data.table(
      route_id = c("r1", "r1", "r2", "r2", "r2"),
      service_id = c("WD", "WE", "WD", "WD", "WD"),
      trip_id = c("A", "B", "C", "E", "F")
    ),
    stop_times = data.table::data.table(
      trip_id = rep(c("A", "B", "C", "D", "E", "F"), each = 2),
      arrival_time = c(
        "7:05:00", "07:20:00", "25:10:00", "25:30:00", "", "",
        "06:00:00", "06:10:00", "10:00:00", "10:15:00", "09:30:00", "09:45:00"
      ),
      departure_time = c(
        "7:05:00", "07:20:00", "25:10:00", "25:30:00", "", "",
        "06:00:00", "06:10:00", "10:00:00", "10:15:00", "09:30:00", "09:45:00"
      ),
      stop_id = rep(c("s1", "s2"), 6),
      stop_sequence = rep(1:2, 6)
    )
  ),
  "dt_gtfs"
)

tester <- function(gtfs = small_gtfs, route_id = NULL, date = "20240101") {
  get_route_timetable(gtfs, route_id, date)
}

key_cols <- function(timetable) {
  timetable[
    ,
    .(date = format(date, "%Y%m%d"), route_id, trip_id, stop_sequence)
  ]
}


# tests -------------------------------------------------------------------


test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(small_gtfs)))
  expect_error(tester(route_id = 1))
  expect_error(tester(route_id = NA_character_))
  expect_error(tester(date = "20241301"), class = "gtfstools_bad_date_error")
  expect_error(tester(copy_gtfs_without_file(small_gtfs, "trips")))
  expect_error(tester(copy_gtfs_without_file(small_gtfs, "stop_times")))
  expect_error(
    tester(copy_gtfs_without_field(small_gtfs, "trips", "route_id"))
  )
  expect_error(
    tester(copy_gtfs_without_field(small_gtfs, "stop_times", "stop_sequence"))
  )

  # a date column would be confused with the new one

  date_gtfs <- small_gtfs
  date_gtfs$stop_times <- data.table::copy(date_gtfs$stop_times)[, date := "x"]
  expect_error(
    tester(date_gtfs),
    class = "gtfstools_timetable_date_column_error"
  )
})

test_that("returns a data.table with date, trips and stop_times columns", {
  result <- tester()
  expect_s3_class(result, "data.table")
  expect_identical(
    names(result),
    c(
      "date",
      names(small_gtfs$trips),
      setdiff(names(small_gtfs$stop_times), "trip_id")
    )
  )
  expect_s3_class(result$date, "Date")

  result <- tester(ber_gtfs, "1922_3", "20210104")
  expect_identical(
    names(result),
    c(
      "date",
      names(ber_gtfs$trips),
      setdiff(names(ber_gtfs$stop_times), "trip_id")
    )
  )
})

test_that("builds the timetable of the given routes and dates", {

  # all service dates are used by default

  result <- tester(route_id = "r1", date = NULL)
  expect_identical(
    result,
    tester(route_id = "r1", date = get_dates(small_gtfs))
  )
  expect_identical(nrow(result), 23L * 2L + 8L * 2L)

  # trips sorted by their first departure as times, with untimed trips last
  # and each trip's stop times together; trip "D" is not in trips. a
  # duplicated date doesn't duplicate rows

  result <- tester(
    date = data.table::as.IDate(c("2024-01-06", "2024-01-01", "2024-01-06"))
  )
  expect_identical(
    key_cols(result),
    data.table::data.table(
      date = rep(c("20240101", "20240106"), c(8, 2)),
      route_id = rep(c("r1", "r2", "r1"), c(2, 6, 2)),
      trip_id = rep(c("A", "F", "E", "C", "B"), each = 2),
      stop_sequence = rep(1:2, 5)
    )
  )

  # the input order of stop_times doesn't matter

  reversed_gtfs <- small_gtfs
  reversed_gtfs$stop_times <- small_gtfs$stop_times[
    rev(seq_len(nrow(small_gtfs$stop_times)))
  ]
  expect_identical(
    tester(reversed_gtfs, date = c("20240101", "20240106")),
    result
  )

  # service "WD" is listed twice on 2024-01-02, but its trips appear once

  result <- tester(route_id = "r2", date = "20240102")
  expect_identical(
    key_cols(result),
    data.table::data.table(
      date = "20240102",
      route_id = "r2",
      trip_id = rep(c("F", "E", "C"), each = 2),
      stop_sequence = rep(1:2, 3)
    )
  )
})

test_that("returns an empty table if there is no activity", {
  empty_result <- tester()[0]

  expect_identical(tester(date = "20250101"), empty_result)
  expect_identical(tester(route_id = "r2", date = "20240106"), empty_result)
  expect_warning(
    result <- tester(route_id = "unknown"),
    "doesn't contain the following route_id"
  )
  expect_identical(result, empty_result)

  no_calendar_gtfs <- copy_gtfs_without_file(small_gtfs, "calendar")
  no_calendar_gtfs <- copy_gtfs_without_file(no_calendar_gtfs, "calendar_dates")
  expect_identical(tester(no_calendar_gtfs), empty_result)
  expect_identical(tester(no_calendar_gtfs, date = NULL), empty_result)
})

test_that("works with only one of calendar and calendar_dates", {
  no_dates_gtfs <- copy_gtfs_without_file(small_gtfs, "calendar_dates")
  expect_identical(
    tester(no_dates_gtfs, date = "20240102"),
    tester(date = "20240102")
  )

  # without calendar, "WD" runs only on the date added by calendar_dates

  only_dates_gtfs <- copy_gtfs_without_file(small_gtfs, "calendar")
  expect_identical(
    tester(only_dates_gtfs, date = c("20240101", "20240102")),
    tester(date = "20240102")
  )
})

test_that("keeps duplicated trips", {
  tripled_gtfs <- ber_gtfs
  tripled_gtfs$trips <- rbind(ber_gtfs$trips, ber_gtfs$trips, ber_gtfs$trips)

  result <- tester(ber_gtfs, date = "20210104")
  tripled_result <- tester(tripled_gtfs, date = "20210104")
  expect_identical(nrow(tripled_result), 3L * nrow(result))
})

test_that("matches the active trips' stop times in a real feed", {
  route_id <- "1922_3"
  active_services <- get_active_services(ber_gtfs, "20210104")$service_id
  active_trips <- ber_gtfs$trips[
    service_id %chin% active_services & route_id == "1922_3"
  ]$trip_id
  expected_n <- sum(ber_gtfs$stop_times$trip_id %chin% active_trips)

  result <- tester(ber_gtfs, route_id, "20210104")
  expect_identical(nrow(result), expected_n)
  expect_true(expected_n > 0)
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(ber_path)
  gtfs <- read_gtfs(ber_path)
  expect_identical(original_gtfs, gtfs)

  result <- tester(gtfs, date = "20210104")
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})
