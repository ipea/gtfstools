spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)
poa_gtfs <- read_gtfs(poa_path)
ber_gtfs <- read_gtfs(ber_path)
ggl_gtfs <- read_gtfs(ggl_path)

tester <- function(gtfs = list(spo = spo_gtfs, poa = poa_gtfs),
                   resolution = "periods",
                   plot = FALSE) {
  get_calendar_overlap(gtfs, resolution, plot)
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

# naive version of get_service_days(), which lists the days of each service
# one by one and adds up the trips of the services that run on each day. the
# departures of each frequencies entry are listed with seq(). format(x, "%u")
# gives the weekday number (1 is monday) regardless of the locale

naive_service_weights <- function(gtfs) {
  trips <- unique(gtfs[["trips"]][!is.na(service_id), .(trip_id, service_id)])
  trips[, weight := 1]

  if (!is.null(gtfs[["frequencies"]])) {
    frequencies <- unique(
      gtfs[["frequencies"]][
        !is.na(trip_id) & trip_id %chin% trips$trip_id,
        .(trip_id, start_time, end_time, headway_secs)
      ]
    )

    for (trip in unique(frequencies$trip_id)) {
      entries <- frequencies[trip_id == trip]
      start <- suppressWarnings(string_to_seconds(entries$start_time))
      end <- suppressWarnings(string_to_seconds(entries$end_time))
      headway <- entries$headway_secs

      n_departures <- vapply(
        seq_len(nrow(entries)),
        function(i) {
          if (anyNA(c(start[i], end[i], headway[i])) || end[i] < start[i]) {
            return(NA_real_)
          }
          if (start[i] == end[i]) return(1)
          if (headway[i] <= 0) return(NA_real_)
          length(seq(start[i], end[i] - 1, by = headway[i]))
        },
        numeric(1)
      )

      trip_weight <- if (anyNA(n_departures)) 1 else sum(n_departures)
      trips[trip_id == trip, weight := trip_weight]
    }
  }

  return(trips[, .(weight = sum(weight)), by = service_id])
}

naive_service_period <- function(gtfs) {
  counts_trips <- !is.null(gtfs[["trips"]])

  if (counts_trips) {
    weights <- naive_service_weights(gtfs)
  } else {
    service_ids <- unique(
      c(gtfs[["calendar"]]$service_id, gtfs[["calendar_dates"]]$service_id)
    )
    weights <- data.table::data.table(
      service_id = service_ids[!is.na(service_ids)],
      weight = 1
    )
  }

  service_days <- data.table::data.table(
    service_id = character(0),
    date = as.Date(character(0))
  )

  calendar <- NULL
  if (!is.null(gtfs[["calendar"]])) {
    calendar <- gtfs[["calendar"]][
      service_id %chin% weights$service_id & !is.na(start_date) &
        !is.na(end_date) & start_date <= end_date
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
    service_days <- unique(service_days[runs, .(service_id, date)])
  }

  if (!is.null(gtfs[["calendar_dates"]])) {
    exceptions <- gtfs[["calendar_dates"]][
      service_id %chin% weights$service_id & !is.na(date)
    ]
    service_days <- service_days[
      !exceptions[exception_type == 2L],
      on = c("service_id", "date")
    ]
    service_days <- unique(
      rbind(
        service_days,
        exceptions[exception_type == 1L, .(service_id, date)]
      )
    )
  }

  service_days <- weights[service_days, on = "service_id"]
  service_days <- service_days[, .(n_trips = sum(weight)), keyby = date]
  service_days[
    ,
    n_trips := if (counts_trips) as.integer(n_trips) else NA_integer_
  ]
  data.table::setkey(service_days, NULL)

  return(service_days)
}

# ggl has a weekday (WD) and a weekend (WE) service in july 2006. on july 3rd
# and 4th, WD is removed and WE is added in calendar_dates. only WE is used by
# trips: AWE1, which departs 12 + 280 + 65 times listed in frequencies, and
# AWE2

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

# feed for the trip counts: service S1 runs on weekdays from 2024-01-01 to
# 2024-01-19 (through two overlapping calendar entries). its trips run
# 6 (06:00 to 07:00, every 10 minutes, listed twice) + 1 (07:00 to 07:00)
# times, plus 2 scheduled trips, so 9 trips per day. S1 is removed on
# 2024-01-03, added on 2024-01-02 (when it already runs) and added on
# saturday 2024-01-06

trips_gtfs <- list(
  calendar = data.table::data.table(
    service_id = "S1",
    monday = 1L,
    tuesday = 1L,
    wednesday = 1L,
    thursday = 1L,
    friday = 1L,
    saturday = 0L,
    sunday = 0L,
    start_date = as.Date(c("2024-01-01", "2024-01-08")),
    end_date = as.Date(c("2024-01-14", "2024-01-19"))
  ),
  calendar_dates = data.table::data.table(
    service_id = "S1",
    date = as.Date(c("2024-01-03", "2024-01-02", "2024-01-06")),
    exception_type = c(2L, 1L, 1L)
  ),
  trips = data.table::data.table(
    trip_id = c("t1", "t2", "t3"),
    service_id = "S1"
  ),
  frequencies = data.table::data.table(
    trip_id = c("t1", "t1", "t1", "absent_trip"),
    start_time = c("06:00:00", "06:00:00", "07:00:00", "06:00:00"),
    end_time = c("07:00:00", "07:00:00", "07:00:00", "07:00:00"),
    headway_secs = c(600L, 600L, 0L, 60L)
  )
)
class(trips_gtfs) <- c("dt_gtfs", "gtfs", "list")

trips_days <- seq(as.Date("2024-01-01"), as.Date("2024-01-19"), by = "day")
trips_days <- trips_days[format(trips_days, "%u") %in% as.character(1:5)]
trips_days <- sort(
  c(trips_days[trips_days != as.Date("2024-01-03")], as.Date("2024-01-06"))
)

# tests ---

test_that("raises error due to incorrect input types", {
  expect_error(tester(1))
  expect_error(tester(character(0)))
  expect_error(tester(NA_character_))
  expect_error(tester(list()))
  expect_error(tester(list(spo_gtfs, 1)))
  expect_error(tester(spo_gtfs))
  expect_error(tester(c(spo_path, tempfile(fileext = ".zip"))))
  expect_error(tester(resolution = "weekly"))
  expect_error(tester(resolution = c("periods", "daily")))
  expect_error(tester(resolution = NA_character_))
  expect_error(tester(plot = "TRUE"))
  expect_error(tester(plot = NA))
  expect_error(tester(plot = c(TRUE, FALSE)))
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

test_that("returns the number of trips per day by default", {
  daily_trips <- tester(resolution = "daily")
  expect_identical(
    get_calendar_overlap(list(spo = spo_gtfs, poa = poa_gtfs)),
    daily_trips
  )
  expect_s3_class(daily_trips, "data.table")
  expect_named(daily_trips, c("feed", "date", "n_trips", "overlap"))
  expect_type(daily_trips$feed, "character")
  expect_s3_class(daily_trips$date, "Date")
  expect_type(daily_trips$n_trips, "integer")
  expect_type(daily_trips$overlap, "logical")

  expect_identical(unique(daily_trips$feed), c("spo", "poa"))
  expect_identical(
    daily_trips[overlap == TRUE, range(date)],
    as.Date(c("2019-01-18", "2019-04-18"))
  )
  expect_identical(
    daily_trips[feed == "poa"]$n_trips,
    get_service_days(poa_gtfs)$n_trips
  )
})

test_that("returns an empty table when feeds don't overlap", {
  expect_silent(overlap <- tester(c(spo_path, poa_path, ber_path)))
  expect_identical(nrow(overlap), 0L)
  expect_named(overlap, c("start_date", "end_date", "n_days"))
  expect_s3_class(overlap$start_date, "Date")
  expect_type(overlap$n_days, "integer")

  daily_trips <- tester(c(spo_path, poa_path, ber_path), resolution = "daily")
  expect_false(any(daily_trips$overlap))
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
  ggl_days <- sort(
    c(july[july_weekday >= 6], as.Date(c("2006-07-03", "2006-07-04")))
  )
  expect_equal(get_service_days(ggl_gtfs)$date, ggl_days)
  expect_equal(get_service_days(ggl_no_trips)$date, july)

  # an empty 'trips' table means that no service is used

  no_used_services <- ggl_gtfs
  no_used_services$trips <- ggl_gtfs$trips[0]
  expect_identical(nrow(get_service_days(no_used_services)), 0L)
  expect_warning(
    tester(list(ggl_gtfs, no_used_services)),
    class = "gtfstools_no_service_days"
  )
})

test_that("counts trips, including the departures listed in frequencies", {
  service_days <- get_service_days(trips_gtfs)
  expect_identical(service_days$date, trips_days)
  expect_identical(service_days$n_trips, rep(9L, length(trips_days)))

  # AWE1 departs 357 times and AWE2 once

  expect_identical(unique(get_service_days(ggl_gtfs)$n_trips), 358L)
})

test_that("counts the departures of a trip listed under several services", {
  shared_trip <- trips_gtfs
  shared_trip$calendar <- rbind(
    trips_gtfs$calendar[1],
    data.table::copy(trips_gtfs$calendar[1])[, service_id := "S2"]
  )
  shared_trip$calendar_dates <- trips_gtfs$calendar_dates[0]
  shared_trip$trips <- data.table::data.table(
    trip_id = c("t1", "t1"),
    service_id = c("S1", "S2")
  )

  # t1 departs 7 times under each service, so 14 times on each day

  service_days <- get_service_days(shared_trip)
  expect_identical(unique(service_days$n_trips), 14L)
  expect_equal(service_days, naive_service_period(shared_trip))
})

test_that("ignores frequencies entries without a trip_id", {
  na_trip <- trips_gtfs
  na_trip$trips <- data.table::data.table(
    trip_id = c("t2", NA),
    service_id = "S1"
  )
  na_trip$frequencies <- data.table::data.table(
    trip_id = NA_character_,
    start_time = "06:00:00",
    end_time = "07:00:00",
    headway_secs = 600L
  )

  expect_identical(unique(get_service_days(na_trip)$n_trips), 2L)
})

test_that("counts trips with invalid frequencies entries once", {
  invalid_frequencies <- trips_gtfs
  invalid_frequencies$frequencies <- data.table::data.table(
    trip_id = c("t1", "t2", "t2"),
    start_time = c("06:00:00", "06:00:00", "aa:bb:cc"),
    end_time = c("07:00:00", "07:00:00", "07:00:00"),
    headway_secs = c(NA, 600L, 600L)
  )

  warnings <- testthat::capture_warnings(
    service_days <- get_service_days(invalid_frequencies)
  )
  expect_length(warnings, 1)
  expect_warning(
    get_service_days(invalid_frequencies),
    class = "gtfstools_invalid_frequencies_warning"
  )
  expect_identical(unique(service_days$n_trips), 3L)
})

test_that("returns NA trips when the feed has no trips table", {
  service_days <- get_service_days(ggl_no_trips)
  expect_identical(service_days$n_trips, rep(NA_integer_, 31))

  daily_trips <- tester(list(ggl_gtfs, ggl_no_trips), resolution = "daily")
  expect_type(daily_trips$n_trips, "integer")
  expect_true(all(is.na(daily_trips[feed == "feed_2"]$n_trips)))
})

test_that("get_service_period() returns the service days as dates", {
  for (gtfs in list(spo_gtfs, ggl_gtfs, ggl_no_trips)) {
    service_days <- get_service_period(gtfs)
    expect_s3_class(service_days, "Date")
    expect_identical(service_days, get_service_days(gtfs)$date)
  }
})

test_that("raises error if trips service_id is not character", {
  bad_trips <- ggl_gtfs
  bad_trips$trips <- data.table::data.table(trip_id = "t1", service_id = 1L)
  expect_error(get_service_days(bad_trips))
})

test_that("respects the calendar weekdays", {
  wd_gtfs <- copy_gtfs_without_file(ggl_no_trips, "calendar_dates")
  wd_gtfs$calendar <- wd_gtfs$calendar[service_id == "WD"]

  service_days <- get_service_days(wd_gtfs)$date
  expect_length(service_days, 21)
  expect_true(all(format(service_days, "%u") %in% as.character(1:5)))
})

test_that("works when calendar or calendar_dates are missing", {
  only_calendar <- copy_gtfs_without_file(ggl_no_trips, "calendar_dates")
  expect_equal(get_service_days(only_calendar)$date, july)

  only_calendar_dates <- copy_gtfs_without_file(ggl_gtfs, "calendar")
  expect_equal(
    get_service_days(only_calendar_dates)$date,
    as.Date(c("2006-07-03", "2006-07-04"))
  )

  no_calendars <- copy_gtfs_without_file(only_calendar, "calendar")
  service_days <- get_service_days(no_calendars)
  expect_s3_class(service_days$date, "Date")
  expect_identical(nrow(service_days), 0L)

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

  expect_identical(nrow(get_service_days(invalid_dates)), 0L)
})

test_that("gives the same results as listing the days of each service", {
  feeds <- list(spo_gtfs, poa_gtfs, ber_gtfs, ggl_gtfs, trips_gtfs)

  for (gtfs in feeds) {
    expect_equal(get_service_days(gtfs), naive_service_period(gtfs))

    gtfs_no_trips <- copy_gtfs_without_file(gtfs, "trips")
    expect_equal(
      get_service_days(gtfs_no_trips),
      naive_service_period(gtfs_no_trips)
    )
  }
})

test_that("applies removals by service", {
  first_days <- seq(as.Date("2024-01-01"), as.Date("2024-01-14"), by = "day")
  weekdays_only <- first_days[format(first_days, "%u") %in% as.character(1:5)]

  # a removal on a day its service doesn't run doesn't affect other services

  gtfs <- synthetic_gtfs(c("A", "B"), "2024-01-06")
  expect_equal(get_service_days(gtfs)$date, first_days)

  # a duplicated removal doesn't remove another service from the day

  gtfs <- synthetic_gtfs(c("A", "C"), c("2024-01-02", "2024-01-02"))
  expect_equal(get_service_days(gtfs)$date, weekdays_only)

  # a duplicated calendar entry is removed as a whole

  gtfs <- synthetic_gtfs(
    "A",
    "2024-01-02",
    calendar = rbind(synthetic_calendar[1], synthetic_calendar[1])
  )
  expect_equal(
    get_service_days(gtfs)$date,
    weekdays_only[weekdays_only != as.Date("2024-01-02")]
  )

  # a service with two calendar entries is removed from both

  a2 <- synthetic_calendar[1]
  a2[, `:=`(saturday = 1L, end_date = as.Date("2024-01-06"))]
  two_entries <- rbind(synthetic_calendar[1], a2)

  gtfs <- synthetic_gtfs("A", "2024-01-03", calendar = two_entries)
  expect_equal(
    get_service_days(gtfs)$date,
    sort(c(weekdays_only[-3], as.Date("2024-01-06")))
  )

  gtfs <- synthetic_gtfs("A", "2024-01-06", calendar = two_entries)
  expect_equal(get_service_days(gtfs)$date, weekdays_only)
})

test_that("names feeds after their files or list names", {
  feed_names <- function(gtfs) {
    unique(tester(gtfs, resolution = "daily")$feed)
  }

  expect_identical(
    feed_names(c(spo_path, poa_path)),
    c("spo_gtfs", "poa_gtfs")
  )
  expect_identical(
    feed_names(list(spo_gtfs, poa_gtfs)),
    c("feed_1", "feed_2")
  )
  expect_identical(
    feed_names(list(a = spo_gtfs, poa_gtfs, a = poa_gtfs)),
    c("a", "feed_2", "a_1")
  )
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(ggl_path)
  gtfs <- read_gtfs(ggl_path)
  expect_identical(original_gtfs, gtfs)

  result <- tester(list(gtfs, ggl_no_trips))
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  result <- tester(list(gtfs, ggl_no_trips), resolution = "daily")
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  skip_if_not_installed("ggplot2")
  result <- tester(list(gtfs, ggl_no_trips), resolution = "daily", plot = TRUE)
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  # no index is added to the given tables

  expect_null(data.table::indices(gtfs$frequencies))
  expect_null(data.table::indices(gtfs$trips))
})

test_that("returns a timeline plot", {
  skip_if_not_installed("ggplot2")

  timeline_plot <- tester(plot = TRUE)
  expect_true(inherits(timeline_plot, "ggplot"))
  expect_error(ggplot2::ggplot_build(timeline_plot), NA)

  # one tile per period of each feed, and one shaded window per overlap
  # period. the first feed is plotted at the top

  timeline_plot <- tester(list(ggl_gtfs, ggl_no_trips), plot = TRUE)
  expect_identical(nrow(ggplot2::layer_data(timeline_plot, 1)), 5L)
  expect_identical(nrow(ggplot2::layer_data(timeline_plot, 2)), 6L)
  expect_identical(
    ggplot2::layer_scales(timeline_plot)$y$get_limits(),
    c("feed_2", "feed_1")
  )

  # builds without overlap and with feeds without service days

  timeline_plot <- tester(list(spo_gtfs, ber_gtfs), plot = TRUE)
  expect_error(ggplot2::ggplot_build(timeline_plot), NA)

  no_calendars <- copy_gtfs_without_file(ggl_gtfs, "calendar")
  no_calendars <- copy_gtfs_without_file(no_calendars, "calendar_dates")
  timeline_plot <- suppressWarnings(
    tester(list(ggl_gtfs, no_calendars), plot = TRUE)
  )
  expect_error(ggplot2::ggplot_build(timeline_plot), NA)
})

test_that("returns a plot of the trips per day", {
  skip_if_not_installed("ggplot2")

  # feeds without trip counts are drawn as a rug, without warnings

  daily_plot <- tester(
    list(ggl_gtfs, ggl_no_trips),
    resolution = "daily",
    plot = TRUE
  )
  expect_true(inherits(daily_plot, "ggplot"))
  expect_length(
    testthat::capture_warnings(ggplot2::ggplot_build(daily_plot)),
    0
  )
  expect_identical(nrow(ggplot2::layer_data(daily_plot, 1)), 10L)
  expect_identical(nrow(ggplot2::layer_data(daily_plot, 2)), 12L)
  expect_identical(nrow(ggplot2::layer_data(daily_plot, 3)), 31L)

  # builds without overlap

  daily_plot <- tester(
    list(spo_gtfs, ber_gtfs),
    resolution = "daily",
    plot = TRUE
  )
  expect_error(ggplot2::ggplot_build(daily_plot), NA)
})
