spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)
ggl_gtfs <- read_gtfs(ggl_path)
ber_gtfs <- read_gtfs(ber_path)

# in ggl, the weekday service "WD" is replaced by the weekend service "WE" on
# 2006-07-03 and 2006-07-04, according to calendar_dates

tester <- function(gtfs = ggl_gtfs, date = "2006-07-03", keep = TRUE) {
  filter_by_date(gtfs, date, keep)
}


# tests -------------------------------------------------------------------


test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(ggl_gtfs)))
  expect_error(tester(date = 20060703))
  expect_error(tester(date = Sys.time()))
  expect_error(tester(date = NA))
  expect_error(tester(date = as.Date(NA)))
  expect_error(tester(date = character(0)))
  expect_error(tester(keep = "TRUE"))
  expect_error(tester(keep = NA))

  expect_error(tester(date = "2006-13-01"), class = "gtfstools_bad_date_error")
  expect_error(tester(date = "2006-07-03x"), class = "gtfstools_bad_date_error")
  expect_error(
    tester(date = c("2006-07-03", "03/07/2006")),
    class = "gtfstools_bad_date_error"
  )

  # dates may also be given in the "YYYYMMDD" format
  expect_identical(tester(date = "20060703"), tester(date = "2006-07-03"))

  # IDate objects are dates too
  expect_identical(
    tester(date = data.table::as.IDate("2006-07-03")),
    tester(date = "2006-07-03")
  )
})

test_that("results in a dt_gtfs object", {
  # a dt_gtfs object is a list with "dt_gtfs" and "gtfs" classes
  dt_gtfs_class <- c("dt_gtfs", "gtfs", "list")
  smaller_gtfs <- tester()
  expect_s3_class(smaller_gtfs, dt_gtfs_class)
  expect_type(smaller_gtfs, "list")

  # all objects inside a dt_gtfs are data.tables
  invisible(lapply(smaller_gtfs, expect_s3_class, "data.table"))
})

test_that("doesn't change given gtfs", {
  # (except for some tables' indices)

  # dates within each feed's calendar, so that both feeds are filtered

  paths_and_dates <- list(c(spo_path, "2019-01-02"), c(ggl_path, "2006-07-03"))

  for (path_and_date in paths_and_dates) {
    original_gtfs <- read_gtfs(path_and_date[1])
    gtfs <- read_gtfs(path_and_date[1])
    expect_identical(original_gtfs, gtfs)

    invisible(filter_by_date(gtfs, path_and_date[2]))
    invisible(filter_by_date(gtfs, path_and_date[2], keep = FALSE))
    expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
  }
})

test_that("keeps and drops the services that run on the given dates", {
  # on 2006-07-03 WD is removed and WE is added by calendar_dates. on
  # 2006-07-05 (a wednesday) only WD runs

  expect_identical(tester()$calendar$service_id, "WE")
  expect_identical(tester(keep = FALSE)$calendar$service_id, "WD")
  expect_identical(tester(date = "2006-07-05")$calendar$service_id, "WD")
  expect_identical(
    tester(date = "2006-07-05", keep = FALSE)$calendar$service_id,
    "WE"
  )
  expect_identical(
    sort(unique(tester()$calendar_dates$service_id)),
    "WE"
  )

  # the services are kept as a whole, not trimmed to the given dates

  expect_identical(
    tester()$calendar,
    ggl_gtfs$calendar[service_id == "WE"],
    ignore_attr = TRUE
  )

  # equivalent to filtering by the services that run on the dates

  expect_identical(tester(), filter_by_service_id(ggl_gtfs, "WE"))
  expect_identical(
    tester(keep = FALSE),
    filter_by_service_id(ggl_gtfs, "WE", keep = FALSE)
  )

  # character and Date inputs give the same result

  expect_identical(tester(), tester(date = as.Date("2006-07-03")))
})

test_that("several dates keep the services that run on any of them", {
  both_dates <- tester(date = c("2006-07-03", "2006-07-05"))
  expect_identical(sort(both_dates$calendar$service_id), c("WD", "WE"))

  both_dates_dropped <- tester(
    date = c("2006-07-03", "2006-07-05"),
    keep = FALSE
  )
  expect_identical(nrow(both_dates_dropped$calendar), 0L)

  # duplicated dates don't change the result
  expect_identical(
    tester(date = c("2006-07-03", "2006-07-03")),
    tester(date = "2006-07-03")
  )
})

test_that("dates without service keep nothing or drop nothing", {
  outside_kept <- tester(date = "2020-01-01")
  expect_identical(nrow(outside_kept$trips), 0L)
  expect_identical(nrow(outside_kept$calendar), 0L)

  # dropping no service still drops the entries that no trip uses, as
  # filter_by_service_id() does (ggl has unused stops, shapes, etc)

  outside_dropped <- tester(date = "2020-01-01", keep = FALSE)
  expect_identical(
    outside_dropped,
    filter_by_service_id(ggl_gtfs, character(0), keep = FALSE)
  )
  expect_identical(outside_dropped$calendar, ggl_gtfs$calendar)
})

test_that("an addition wins over a removal on the same date", {
  gtfs <- read_gtfs(ggl_path)
  gtfs$calendar_dates <- rbind(
    gtfs$calendar_dates,
    data.table::data.table(
      service_id = "WD",
      date = as.Date("2006-07-03"),
      exception_type = 1L
    )
  )

  expect_identical(
    sort(filter_by_date(gtfs, "2006-07-03")$calendar$service_id),
    c("WD", "WE")
  )
})

test_that("considers every calendar entry of a service", {
  # a second calendar entry of WE, in 2030, is the only one spanning 2030-01-07

  gtfs <- read_gtfs(ggl_path)
  extra_entry <- gtfs$calendar[service_id == "WE"]
  extra_entry[, c("monday", "start_date", "end_date") := list(
    1L,
    as.Date("2030-01-01"),
    as.Date("2030-01-31")
  )]
  gtfs$calendar <- rbind(gtfs$calendar, extra_entry)

  expect_identical(
    unique(filter_by_date(gtfs, "2030-01-07")$calendar$service_id),
    "WE"
  )
})

test_that("works with missing service_ids", {
  gtfs <- read_gtfs(ggl_path)
  gtfs$calendar <- rbind(
    gtfs$calendar,
    data.table::data.table(
      service_id = NA_character_,
      monday = 1L,
      tuesday = 1L,
      wednesday = 1L,
      thursday = 1L,
      friday = 1L,
      saturday = 1L,
      sunday = 1L,
      start_date = as.Date("2006-07-01"),
      end_date = as.Date("2006-07-31")
    )
  )

  expect_identical(filter_by_date(gtfs, "2006-07-03")$calendar$service_id, "WE")
})

test_that("works with missing calendar files and fields", {
  # without calendar_dates, WD runs on 2006-07-03 according to calendar

  no_calendar_dates <- copy_gtfs_without_file(ggl_gtfs, "calendar_dates")
  expect_identical(
    filter_by_date(no_calendar_dates, "2006-07-03")$calendar$service_id,
    "WD"
  )

  # without calendar, only the days added in calendar_dates count

  no_calendar <- copy_gtfs_without_file(ggl_gtfs, "calendar")
  expect_identical(
    unique(filter_by_date(no_calendar, "2006-07-03")$calendar_dates$service_id),
    "WE"
  )
  expect_identical(
    nrow(filter_by_date(no_calendar, "2006-07-05")$trips),
    0L
  )

  # an empty calendar behaves like a missing one

  empty_calendar <- read_gtfs(ggl_path)
  empty_calendar$calendar <- empty_calendar$calendar[0]
  expect_identical(
    unique(
      filter_by_date(empty_calendar, "2006-07-03")$calendar_dates$service_id
    ),
    "WE"
  )

  # without both, the gtfs is returned unchanged with a warning

  no_calendars <- copy_gtfs_without_file(no_calendar, "calendar_dates")
  expect_warning(
    unchanged_gtfs <- filter_by_date(no_calendars, "2006-07-03"),
    class = "gtfstools_no_calendar_warning"
  )
  expect_identical(unchanged_gtfs, no_calendars)

  # calendar tables without the fields needed to interpret them raise errors

  no_monday <- copy_gtfs_without_field(ggl_gtfs, "calendar", "monday")
  expect_error(filter_by_date(no_monday, "2006-07-03"))

  bad_class <- copy_gtfs_diff_field_class(
    ggl_gtfs,
    "calendar",
    "start_date",
    "character"
  )
  expect_error(filter_by_date(bad_class, "2006-07-03"))

  no_type <- copy_gtfs_without_field(
    ggl_gtfs,
    "calendar_dates",
    "exception_type"
  )
  expect_error(filter_by_date(no_type, "2006-07-03"))
})

test_that("agrees with get_service_period() on a feed with many exceptions", {
  # most ber services are not used by any trip, and get_service_period()
  # ignores those. so the checks below use a feed with only the calendar
  # tables, in which every service counts

  calendar_gtfs <- function(service_ids = NULL) {
    calendar <- ber_gtfs$calendar
    calendar_dates <- ber_gtfs$calendar_dates

    if (!is.null(service_ids)) {
      calendar <- calendar[service_id %chin% service_ids]
      calendar_dates <- calendar_dates[service_id %chin% service_ids]
    }

    gtfsio::new_gtfs(
      list(calendar = calendar, calendar_dates = calendar_dates),
      "dt_gtfs"
    )
  }

  ber_calendars <- calendar_gtfs()

  # an ordinary wednesday and christmas eve, on which many services are
  # removed and added by calendar_dates

  for (day in c("2021-03-10", "2020-12-24")) {
    day_date <- as.Date(day)

    # no service left after dropping runs on the day

    dropped <- filter_by_date(ber_calendars, day, keep = FALSE)
    expect_false(day_date %in% get_service_period(dropped))

    dropped <- filter_by_date(ber_gtfs, day, keep = FALSE)
    expect_false(day_date %in% get_service_period(dropped))

    # every kept service runs on the day. checked on a sample of the kept
    # services, including one added by calendar_dates, because checking all of
    # them takes too long

    kept_services <- sort(
      unique(filter_by_date(ber_calendars, day)$calendar$service_id)
    )
    expect_gt(length(kept_services), 0)

    added_services <- ber_gtfs$calendar_dates[
      date == day_date & exception_type == 1L
    ]$service_id
    sample_services <- unique(c(head(kept_services, 25), added_services[1]))
    sample_services <- sample_services[!is.na(sample_services)]
    expect_true(all(added_services %chin% kept_services))

    for (service in sample_services) {
      expect_true(
        day_date %in% get_service_period(calendar_gtfs(service)),
        label = paste0("service ", service, " running on ", day)
      )
    }
  }
})
