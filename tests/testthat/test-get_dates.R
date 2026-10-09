ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
ggl_gtfs <- read_gtfs(ggl_path)
spo_gtfs <- read_gtfs(spo_path)

# the service days logic is tested through get_service_period(), in
# test-get_calendar_overlap.R. the tests below cover get_dates() itself


# tests -------------------------------------------------------------------


test_that("raises error due to incorrect input types", {
  expect_error(get_dates(unclass(ggl_gtfs)))
  expect_error(get_dates(ggl_gtfs, as_date = NA))
  expect_error(get_dates(ggl_gtfs, as_date = "TRUE"))
  expect_error(get_dates(ggl_gtfs, as_date = c(TRUE, FALSE)))
})

test_that("returns the service days as dates or strings", {
  expect_identical(get_dates(ggl_gtfs), get_service_period(ggl_gtfs))
  expect_identical(get_dates(spo_gtfs), get_service_period(spo_gtfs))
  expect_s3_class(get_dates(spo_gtfs), "Date")

  date_strings <- get_dates(ggl_gtfs, as_date = FALSE)
  expect_identical(date_strings, format(get_dates(ggl_gtfs), "%Y%m%d"))

  # the weekday service WD is not used by any trip, so 2006-07-05 (a
  # wednesday) is not a service day, unlike 2006-07-03 (added to WE)

  expect_identical(date_strings[1:3], c("20060701", "20060702", "20060703"))
  expect_false("20060705" %chin% date_strings)
})

test_that("returns empty vectors without warnings", {
  no_calendars <- copy_gtfs_without_file(ggl_gtfs, "calendar")
  no_calendars <- copy_gtfs_without_file(no_calendars, "calendar_dates")

  expect_silent(dates <- get_dates(no_calendars))
  expect_identical(dates, as.Date(character(0)))

  expect_silent(date_strings <- get_dates(no_calendars, as_date = FALSE))
  expect_identical(date_strings, character(0))
})

test_that("returned dates keep trips in filter_by_date()", {
  dates <- get_dates(ggl_gtfs)
  expect_gt(length(dates), 0)

  for (date in as.list(dates)) {
    kept <- filter_by_date(ggl_gtfs, date)
    expect_gt(nrow(kept$trips), 0)
  }

  not_kept <- filter_by_date(ggl_gtfs, "2006-07-05")
  expect_identical(nrow(not_kept$trips), 0L)
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(ggl_path)
  gtfs <- read_gtfs(ggl_path)
  invisible(get_dates(gtfs))
  expect_identical(original_gtfs, gtfs)
})
