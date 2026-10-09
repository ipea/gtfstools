ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
ggl_gtfs <- read_gtfs(ggl_path)
ber_gtfs <- read_gtfs(ber_path)

# in ggl, the weekday service "WD" is not used by any trip, and the weekend
# service "WE" also runs on 2006-07-03 and 2006-07-04, added by calendar_dates

tester <- function(gtfs = ggl_gtfs, date = "20060703") {
  get_active_services(gtfs, date)
}


# tests -------------------------------------------------------------------


test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(ggl_gtfs)))
  expect_error(tester(date = 20060703))
  expect_error(tester(date = NA))
  expect_error(tester(date = character(0)))

  # the dates parser is shared with filter_by_date(), whose tests cover the
  # "YYYY-MM-DD" format and other date classes

  expect_error(tester(date = "20061301"), class = "gtfstools_bad_date_error")
  expect_error(tester(date = "2006073"), class = "gtfstools_bad_date_error")

  # errors are reported in the called function, not in the internal parser

  catch_error <- function(expr) tryCatch(expr, error = function(cnd) cnd)

  error <- catch_error(get_active_services(ggl_gtfs, "20061301"))
  expect_identical(conditionCall(error)[[1]], quote(get_active_services))

  error <- catch_error(filter_by_date(ggl_gtfs, "20061301"))
  expect_identical(conditionCall(error)[[1]], quote(filter_by_date))

  # formats may be mixed
  expect_identical(
    tester(date = c("20060703", "2006-07-04")),
    tester(date = as.Date(c("2006-07-03", "2006-07-04")))
  )
})

test_that("returns the services active on the given dates", {
  active <- tester()
  expect_s3_class(active, "data.table")
  expect_identical(names(active), c("date", "service_id"))
  expect_identical(active$date, as.Date("2006-07-03"))
  expect_identical(active$service_id, "WE")

  expect_identical(tester(date = "2006-07-03"), active)
  expect_identical(tester(date = as.Date("2006-07-03")), active)

  # WD runs on 2006-07-05, but it's not used by any trip

  expect_identical(nrow(tester(date = "20060705")), 0L)

  # several dates, given in any order and duplicated, give one row per date
  # and service, sorted

  several_dates <- tester(date = c("20060708", "20060701", "20060708"))
  expect_identical(
    several_dates$date,
    as.Date(c("2006-07-01", "2006-07-08"))
  )
  expect_identical(several_dates$service_id, c("WE", "WE"))
})

test_that("returns unused services if trips has no service_id", {
  no_service_id <- copy_gtfs_without_field(ggl_gtfs, "trips", "service_id")
  expect_identical(tester(no_service_id, "20060705")$service_id, "WD")
})

test_that("agrees with get_dates() on a feed with many exceptions", {
  expect_true(any(ber_gtfs$calendar_dates$exception_type == 2L))

  dates <- get_dates(ber_gtfs)
  active <- tester(ber_gtfs, dates)
  expect_identical(unique(active$date), dates)
  expect_true(all(active$service_id %chin% ber_gtfs$trips$service_id))
})

test_that("lists each active service once per date", {
  # in a hand-built feed, B runs on mondays and tuesdays (and is also added on
  # a monday by calendar_dates), and a on tuesdays. a service without
  # service_id is added on the same monday

  gtfs <- gtfsio::new_gtfs(
    list(
      calendar = data.table::data.table(
        service_id = c("B", "a"),
        monday = c(1L, 0L),
        tuesday = c(1L, 1L),
        wednesday = 0L,
        thursday = 0L,
        friday = 0L,
        saturday = 0L,
        sunday = 0L,
        start_date = as.Date("2024-01-01"),
        end_date = as.Date("2024-01-31")
      ),
      calendar_dates = data.table::data.table(
        service_id = c("B", NA_character_),
        date = as.Date(c("2024-01-01", "2024-01-01")),
        exception_type = c(1L, 1L)
      )
    ),
    "dt_gtfs"
  )

  # 2024-01-01 was a monday, and 2024-01-02 a tuesday. "B" is sorted before
  # "a", as in the C locale

  active <- tester(gtfs, c("20240102", "20240101", "20240103"))
  expect_identical(
    active$date,
    as.Date(c("2024-01-01", "2024-01-02", "2024-01-02"))
  )
  expect_identical(active$service_id, c("B", "B", "a"))
})

test_that("works with only one of the calendar tables", {
  no_calendar_dates <- copy_gtfs_without_file(ggl_gtfs, "calendar_dates")
  expect_identical(tester(no_calendar_dates, "20060701")$service_id, "WE")

  # without calendar, only the dates added by calendar_dates count
  no_calendar <- copy_gtfs_without_file(ggl_gtfs, "calendar")
  expect_identical(tester(no_calendar, "20060703")$service_id, "WE")
  expect_identical(nrow(tester(no_calendar, "20060701")), 0L)
})

test_that("returns an empty table without warnings", {
  no_calendars <- copy_gtfs_without_file(ggl_gtfs, "calendar")
  no_calendars <- copy_gtfs_without_file(no_calendars, "calendar_dates")

  expect_silent(active <- tester(no_calendars))
  expect_identical(nrow(active), 0L)
  expect_s3_class(active$date, "Date")
  expect_type(active$service_id, "character")
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(ggl_path)
  gtfs <- read_gtfs(ggl_path)
  invisible(get_active_services(gtfs, c("20060703", "20060705")))
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})
