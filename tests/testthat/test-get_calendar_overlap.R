spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)
poa_gtfs <- read_gtfs(poa_path)
ber_gtfs <- read_gtfs(ber_path)
ggl_gtfs <- read_gtfs(ggl_path)

tester <- function(gtfs = list(spo = spo_gtfs, poa = poa_gtfs),
                   output = "df") {
  get_calendar_overlap(gtfs, output)
}

weekday_cols <- c(
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday"
)

# naive version of get_service_period(), which lists the days of each service
# one by one. format(x, "%u") gives the weekday number (1 is monday)
# regardless of the locale

naive_service_period <- function(gtfs) {
  used_services <- NULL
  if (!is.null(gtfs[["trips"]])) {
    used_services <- unique(gtfs[["trips"]]$service_id)
  }
  is_used <- function(id) is.null(used_services) | id %chin% used_services

  service_days <- data.table::data.table(
    service_id = character(0),
    date = as.Date(character(0))
  )

  calendar <- NULL
  if (!is.null(gtfs[["calendar"]])) {
    calendar <- gtfs[["calendar"]][
      is_used(service_id) & !is.na(start_date) & !is.na(end_date) &
        start_date <= end_date
    ]
  }

  if (!is.null(calendar) && nrow(calendar) > 0) {
    calendar[, row := .I]
    service_days <- calendar[
      ,
      .(
        service_id,
        date = start_date + as.numeric(0:(end_date - start_date))
      ),
      by = row
    ]
    weekday <- as.integer(format(service_days$date, "%u"))
    flags <- as.matrix(calendar[, weekday_cols, with = FALSE])
    runs <- flags[cbind(service_days$row, weekday)] %in% 1L
    service_days <- service_days[runs, .(service_id, date)]
  }

  if (!is.null(gtfs[["calendar_dates"]])) {
    exceptions <- gtfs[["calendar_dates"]][is_used(service_id)]
    service_days <- service_days[
      !exceptions[exception_type == 2L],
      on = c("service_id", "date")
    ]
    service_days <- rbind(
      service_days,
      exceptions[exception_type == 1L, .(service_id, date)]
    )
  }

  return(sort(unique(service_days$date)))
}

# ggl has a weekday (WD) and a weekend (WE) service in july 2006. on july 3rd
# and 4th, WD is removed and WE is added in calendar_dates. only WE is used by
# trips

july <- seq(as.Date("2006-07-01"), as.Date("2006-07-31"), by = "day")
july_weekday <- as.integer(format(july, "%u"))
ggl_no_trips <- copy_gtfs_without_file(ggl_gtfs, "trips")

# synthetic feed for the removal tests: services A and C run on weekdays and B
# on weekends, from monday 2024-01-01 to sunday 2024-01-14. synthetic_gtfs()
# keeps the given services and removes service A on removed_date

synthetic_calendar <- data.table::data.table(
  service_id = c("A", "B", "C"),
  monday = c(1L, 0L, 1L),
  tuesday = c(1L, 0L, 1L),
  wednesday = c(1L, 0L, 1L),
  thursday = c(1L, 0L, 1L),
  friday = c(1L, 0L, 1L),
  saturday = c(0L, 1L, 0L),
  sunday = c(0L, 1L, 0L),
  start_date = as.Date("2024-01-01"),
  end_date = as.Date("2024-01-14")
)

synthetic_gtfs <- function(service_id, removed_date, calendar = NULL) {
  if (is.null(calendar)) {
    relevant_services <- service_id  # avoids clashing with the column name
    calendar <- synthetic_calendar[service_id %chin% relevant_services]
  }

  calendar_dates <- data.table::data.table(
    service_id = "A",
    date = as.Date(removed_date),
    exception_type = 2L
  )

  gtfs <- list(calendar = calendar, calendar_dates = calendar_dates)
  class(gtfs) <- c("dt_gtfs", "gtfs", "list")

  return(gtfs)
}

# tests ---

test_that("raises error due to incorrect input types", {
  expect_error(tester(1))
  expect_error(tester(character(0)))
  expect_error(tester(NA_character_))
  expect_error(tester(list()))
  expect_error(tester(list(spo_gtfs, 1)))
  expect_error(tester(spo_gtfs))
  expect_error(tester(c(spo_path, tempfile(fileext = ".zip"))))
  expect_error(tester(output = "map"))
  expect_error(tester(output = c("df", "plot")))
  expect_error(tester(output = NA_character_))
})

test_that("returns a data.table with the overlap periods", {
  overlap <- tester()
  expect_s3_class(overlap, "data.table")
  expect_named(overlap, c("start_date", "end_date", "n_days"))
  expect_s3_class(overlap$start_date, "Date")
  expect_s3_class(overlap$end_date, "Date")
  expect_type(overlap$n_days, "integer")
  expect_equal(overlap$start_date, as.Date("2019-01-18"))
  expect_equal(overlap$end_date, as.Date("2019-04-18"))
  expect_identical(overlap$n_days, 91L)

  # paths and lists give the same results, and a single feed overlaps with
  # itself (poa lies within spo, so it equals the overlap above)

  expect_identical(tester(c(spo_path, poa_path)), overlap)
  expect_identical(tester(list(poa_gtfs)), overlap)
})

test_that("returns an empty table when feeds don't overlap", {
  expect_silent(overlap <- tester(c(spo_path, poa_path, ber_path)))
  expect_identical(nrow(overlap), 0L)
  expect_named(overlap, c("start_date", "end_date", "n_days"))
  expect_s3_class(overlap$start_date, "Date")
  expect_type(overlap$n_days, "integer")
})

test_that("splits the overlap into periods of consecutive days", {
  overlap <- tester(list(ggl_gtfs, ggl_no_trips))
  expect_equal(
    overlap$start_date,
    as.Date(paste0("2006-07-", c("01", "08", "15", "22", "29")))
  )
  expect_identical(overlap$n_days, c(4L, 2L, 2L, 2L, 2L))
})

test_that("only counts services used by trips", {
  expect_equal(
    get_service_period(ggl_gtfs),
    sort(c(july[july_weekday >= 6], as.Date(c("2006-07-03", "2006-07-04"))))
  )
  expect_equal(get_service_period(ggl_no_trips), july)

  # an empty 'trips' table means that no service is used

  no_used_services <- ggl_gtfs
  no_used_services$trips <- ggl_gtfs$trips[0]
  expect_length(get_service_period(no_used_services), 0)
  expect_warning(
    tester(list(ggl_gtfs, no_used_services)),
    class = "gtfstools_no_service_days"
  )
})

test_that("raises error if trips service_id is not character", {
  bad_trips <- ggl_gtfs
  bad_trips$trips <- data.table::data.table(trip_id = "t1", service_id = 1L)
  expect_error(get_service_period(bad_trips))
})

test_that("respects the calendar weekdays", {
  wd_gtfs <- copy_gtfs_without_file(ggl_no_trips, "calendar_dates")
  wd_gtfs$calendar <- wd_gtfs$calendar[service_id == "WD"]

  service_days <- get_service_period(wd_gtfs)
  expect_length(service_days, 21)
  expect_true(all(format(service_days, "%u") %in% as.character(1:5)))
})

test_that("works when calendar or calendar_dates are missing", {
  only_calendar <- copy_gtfs_without_file(ggl_no_trips, "calendar_dates")
  expect_equal(get_service_period(only_calendar), july)

  only_calendar_dates <- copy_gtfs_without_file(ggl_gtfs, "calendar")
  expect_equal(
    get_service_period(only_calendar_dates),
    as.Date(c("2006-07-03", "2006-07-04"))
  )

  no_calendars <- copy_gtfs_without_file(only_calendar, "calendar")
  service_days <- get_service_period(no_calendars)
  expect_s3_class(service_days, "Date")
  expect_length(service_days, 0)

  expect_warning(
    overlap <- tester(list(ggl = ggl_gtfs, empty = no_calendars)),
    class = "gtfstools_no_service_days"
  )
  expect_identical(nrow(overlap), 0L)
})

test_that("ignores calendar entries with invalid dates", {
  invalid_dates <- copy_gtfs_without_file(ggl_no_trips, "calendar_dates")
  invalid_dates$calendar <- data.table::copy(invalid_dates$calendar)
  invalid_dates$calendar[service_id == "WD", start_date := NA]
  invalid_dates$calendar[service_id == "WE", end_date := start_date - 1]

  expect_length(get_service_period(invalid_dates), 0)
})

test_that("gives the same results as listing the days of each service", {
  feeds <- list(spo_gtfs, poa_gtfs, ber_gtfs, ggl_gtfs)

  for (gtfs in feeds) {
    expect_equal(get_service_period(gtfs), naive_service_period(gtfs))

    gtfs_no_trips <- copy_gtfs_without_file(gtfs, "trips")
    expect_equal(
      get_service_period(gtfs_no_trips),
      naive_service_period(gtfs_no_trips)
    )
  }
})

test_that("applies removals by service", {
  first_days <- seq(as.Date("2024-01-01"), as.Date("2024-01-14"), by = "day")
  weekdays_only <- first_days[format(first_days, "%u") %in% as.character(1:5)]

  # a removal on a day its service doesn't run doesn't affect other services

  gtfs <- synthetic_gtfs(c("A", "B"), "2024-01-06")
  expect_equal(get_service_period(gtfs), first_days)

  # a duplicated removal doesn't remove another service from the day

  gtfs <- synthetic_gtfs(c("A", "C"), c("2024-01-02", "2024-01-02"))
  expect_equal(get_service_period(gtfs), weekdays_only)

  # a duplicated calendar entry is removed as a whole

  gtfs <- synthetic_gtfs(
    "A",
    "2024-01-02",
    calendar = rbind(synthetic_calendar[1], synthetic_calendar[1])
  )
  expect_equal(
    get_service_period(gtfs),
    weekdays_only[weekdays_only != as.Date("2024-01-02")]
  )

  # a service with two calendar entries is removed from both

  a2 <- synthetic_calendar[1]
  a2[, `:=`(saturday = 1L, end_date = as.Date("2024-01-06"))]
  two_entries <- rbind(synthetic_calendar[1], a2)

  gtfs <- synthetic_gtfs("A", "2024-01-03", calendar = two_entries)
  expect_equal(
    get_service_period(gtfs),
    sort(c(weekdays_only[-3], as.Date("2024-01-06")))
  )

  gtfs <- synthetic_gtfs("A", "2024-01-06", calendar = two_entries)
  expect_equal(get_service_period(gtfs), weekdays_only)
})

test_that("names feeds after their files or list names", {
  skip_if_not_installed("ggplot2")

  feed_labels <- function(gtfs) {
    timeline_plot <- tester(gtfs, output = "plot")
    return(rev(ggplot2::layer_scales(timeline_plot)$y$get_limits()))
  }

  expect_identical(
    feed_labels(c(spo_path, poa_path)),
    c("spo_gtfs", "poa_gtfs")
  )
  expect_identical(
    feed_labels(list(spo_gtfs, poa_gtfs)),
    c("feed_1", "feed_2")
  )
  expect_identical(
    feed_labels(list(a = spo_gtfs, poa_gtfs, a = poa_gtfs)),
    c("a", "feed_2", "a_1")
  )
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(ggl_path)
  gtfs <- read_gtfs(ggl_path)
  expect_identical(original_gtfs, gtfs)

  result <- tester(list(gtfs, ggl_no_trips))
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  skip_if_not_installed("ggplot2")
  result <- tester(list(gtfs, ggl_no_trips), output = "plot")
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})

test_that("returns a timeline plot", {
  skip_if_not_installed("ggplot2")

  timeline_plot <- tester(output = "plot")
  expect_true(inherits(timeline_plot, "ggplot"))
  expect_error(ggplot2::ggplot_build(timeline_plot), NA)

  # one tile per period of each feed, and one shaded window per overlap period

  timeline_plot <- tester(list(ggl_gtfs, ggl_no_trips), output = "plot")
  expect_identical(nrow(ggplot2::layer_data(timeline_plot, 1)), 5L)
  expect_identical(nrow(ggplot2::layer_data(timeline_plot, 2)), 6L)

  # builds without overlap and with feeds without service days

  timeline_plot <- tester(list(spo_gtfs, ber_gtfs), output = "plot")
  expect_error(ggplot2::ggplot_build(timeline_plot), NA)

  no_calendars <- copy_gtfs_without_file(ggl_gtfs, "calendar")
  no_calendars <- copy_gtfs_without_file(no_calendars, "calendar_dates")
  timeline_plot <- suppressWarnings(
    tester(list(ggl_gtfs, no_calendars), output = "plot")
  )
  expect_error(ggplot2::ggplot_build(timeline_plot), NA)
})
