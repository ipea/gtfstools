spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)

# creates a feed with three trips whose intermediate stops have dwell times
# below and above 30 seconds. trip A runs past midnight, with its later times
# written as "00:01:00" and "00:10:00" (fixed to "24:01:00" and "24:10:00" by
# the function), and trip C visits stop Y twice

dwell_feed <- function() {
  feed <- list(
    routes = data.table::data.table(route_id = "r1"),
    trips = data.table::data.table(
      trip_id = c("A", "B", "C"),
      route_id = "r1"
    ),
    stops = data.table::data.table(
      stop_id = c("s0", "X", "Y", "Z", "s9"),
      stop_lat = 0,
      stop_lon = c(0, 0.01, 0.02, 0.03, 0.04)
    ),
    stop_times = data.table::data.table(
      trip_id = rep(c("A", "B", "C"), c(5, 3, 4)),
      arrival_time = c(
        "08:00:00", "08:05:00", "08:10:00", "23:59:00", "00:10:00",
        "09:00:00", "09:05:00", "09:10:00",
        "10:00:00", "10:05:00", "10:10:00", "10:20:00"
      ),
      departure_time = c(
        "08:00:00", "08:05:00", "08:12:00", "00:01:00", "00:10:00",
        "09:00:00", "09:05:00", "09:10:00",
        "10:00:00", "10:05:00", "10:12:00", "10:20:00"
      ),
      stop_id = c(
        "s0", "X", "Y", "Z", "s9",
        "s0", "Y", "s9",
        "s0", "Y", "Y", "s9"
      ),
      stop_sequence = c(1:5, 1:3, 1:4)
    )
  )

  return(gtfsio::new_gtfs(feed, "dt_gtfs"))
}

dwell_gtfs <- dwell_feed()

tester <- function(gtfs = dwell_gtfs, min_dwell_time = 30, ...) {
  set_min_dwell_time(gtfs, min_dwell_time = min_dwell_time, ...)
}

# tests -------------------------------------------------------------------

test_that("raises errors due to incorrect input types/value", {
  expect_error(tester(unclass(dwell_gtfs)))
  expect_error(tester(min_dwell_time = -1))
  expect_error(tester(min_dwell_time = NA))
  expect_error(tester(min_dwell_time = "30"))
  expect_error(tester(min_dwell_time = c(1, 2)))
  expect_error(tester(min_dwell_time = 500, unit = "d"))
  expect_error(tester(unit = "mins"))
  expect_error(tester(trip_id = NA))
  expect_error(tester(by_reference = NA))
  expect_error(set_min_dwell_time(dwell_gtfs))

  # min_dwell_time is the second argument, so it can be given by position

  expect_identical(set_min_dwell_time(dwell_gtfs, 30), tester())
})

test_that("results in a dt_gtfs object and doesn't change given gtfs", {
  original_gtfs <- dwell_feed()
  given_gtfs <- dwell_feed()

  result <- tester(given_gtfs)
  expect_s3_class(result, "dt_gtfs")
  expect_equal(original_gtfs, given_gtfs, ignore_attr = TRUE)
  expect_false(
    identical(
      result$stop_times$departure_time,
      given_gtfs$stop_times$departure_time
    )
  )

  # when doing by reference, the given gtfs is changed

  expect_invisible(tester(given_gtfs, by_reference = TRUE))
  expect_equal(given_gtfs$stop_times, result$stop_times, ignore_attr = TRUE)
})

test_that("raises only shorter dwell times at intermediate stops", {
  result <- tester()
  times <- result$stop_times

  # dwell times below 30 seconds are raised and the later times shifted.
  # longer dwell times are kept, and so are the first and last stops of each
  # trip. A's times after midnight are fixed first, so Z's dwell time is 120
  # seconds and is kept

  expect_identical(
    times$arrival_time,
    c(
      "08:00:00", "08:05:00", "08:10:30", "23:59:30", "24:10:30",
      "09:00:00", "09:05:00", "09:10:30",
      "10:00:00", "10:05:00", "10:10:30", "10:20:30"
    )
  )
  expect_identical(
    times$departure_time,
    c(
      "08:00:00", "08:05:30", "08:12:30", "24:01:30", "24:10:30",
      "09:00:00", "09:05:30", "09:10:30",
      "10:00:00", "10:05:30", "10:12:30", "10:20:30"
    )
  )

  # nothing is below the minimum anymore, so setting it again changes nothing

  expect_silent(set_again <- tester(result))
  expect_equal(set_again, result)

  # a minimum of 0 raises only negative dwell times. this feed has none once
  # A's times are fixed, so only these change

  zero_min <- tester(min_dwell_time = 0)
  expect_equal(
    object = zero_min,
    expected = fix_overnight_times(gtfs = dwell_gtfs),
    ignore_attr = TRUE
  )

  # B departs from Y a minute before arriving there

  negative_gtfs <- dwell_feed()
  negative_gtfs$stop_times[7, departure_time := "09:04:00"]
  zero_min <- tester(gtfs = negative_gtfs, min_dwell_time = 0)$stop_times
  expect_identical(
    object = zero_min$departure_time[7:8],
    expected = c("09:05:00", "09:11:00")
  )
  expect_identical(object = zero_min$arrival_time[8], expected = "09:11:00")
  expect_identical(
    object = zero_min$departure_time[-(4:8)],
    expected = dwell_gtfs$stop_times$departure_time[-(4:8)]
  )
})

test_that("never shortens dwell times, whatever the trips and stops given", {
  # A and C stay 120 seconds at one of their visits to Y, and B stays none

  result <- tester(trip_id = c("A", "B"), stop_id = "Y")
  expect_identical(
    get_dwell_time(result, stop_id = "Y")$dwell_time,
    c(120, 30, 0, 120)
  )

  # the first stops of the trips are never changed

  expect_silent(first_stops <- tester(stop_id = "s0"))
  expect_equal(
    object = first_stops,
    expected = fix_overnight_times(gtfs = dwell_gtfs),
    ignore_attr = TRUE
  )

  # B's last stop has no departure time, so Y is B's last stop with both times
  # and keeps its dwell time

  no_last_departure <- dwell_feed()
  no_last_departure$stop_times[8, departure_time := ""]
  result <- tester(no_last_departure, trip_id = "B")
  expect_identical(
    get_dwell_time(result, trip_id = "B")$dwell_time,
    c(0, 0, NA)
  )
})

test_that("keeps the first stop with times when earlier stops are blank", {
  # the trip's first and last stops are blank, so the first and last stops
  # with times (X and Z) keep their dwell times

  feed <- dwell_feed()
  feed$stop_times <- data.table::data.table(
    trip_id = "A",
    arrival_time = c("", "08:00:00", "08:05:00", "08:10:00", ""),
    departure_time = c("", "08:00:00", "08:05:00", "08:10:00", ""),
    stop_id = c("s0", "X", "Y", "Z", "s9"),
    stop_sequence = 1:5
  )
  expect_silent(result <- tester(feed))

  expect_identical(
    result$stop_times$arrival_time,
    c("", "08:00:00", "08:05:00", "08:10:30", "")
  )
  expect_identical(
    result$stop_times$departure_time,
    c("", "08:00:00", "08:05:30", "08:10:30", "")
  )
})

test_that("warns about blank visits only when stop_id is given", {
  feed <- dwell_feed()
  feed$stop_times[2, `:=`(arrival_time = "", departure_time = "")]

  expect_warning(
    tester(feed, stop_id = "X"),
    class = "gtfstools_blank_dwell_time"
  )
  expect_silent(tester(feed))
})

test_that("from, to, route_type and unit work as in set_dwell_time()", {
  # only B's visits arrive between 09:00 and 09:30

  expect_equal(
    tester(from = "09:00:00", to = "09:30:00"),
    tester(trip_id = "B")
  )

  rail_routes <- spo_gtfs$routes$route_id[spo_gtfs$routes$route_type == 2L]
  rail_trips <- spo_gtfs$trips$trip_id[
    spo_gtfs$trips$route_id %chin% rail_routes
  ]
  expect_equal(
    tester(spo_gtfs, route_type = 2L),
    tester(spo_gtfs, trip_id = rail_trips)
  )

  expect_equal(
    tester(min_dwell_time = 0.5, unit = "min"),
    tester(min_dwell_time = 30)
  )
  expect_equal(tester(min_dwell_time = 29.6), tester())

  # trip A's first stop arrives before 08:05 but is still its first stop, so
  # X is raised as without a time of day

  expect_equal(tester(from = "08:05:00"), tester())
})

test_that("rows with a NA stop_sequence are never raised", {
  feed <- dwell_feed()
  feed$stop_times[1, stop_sequence := NA_integer_]
  result <- tester(feed, trip_id = "A")

  # X is A's first stop with a stop_sequence, so it keeps its departure, and
  # so does Y, which stays 120 seconds

  expect_identical(
    result$stop_times$departure_time[1:3],
    c("08:00:00", "08:05:00", "08:12:00")
  )
})

test_that("raises an error if times would be later than 9999:59:59", {
  feed <- dwell_feed()
  feed$stop_times <- data.table::data.table(
    trip_id = "A",
    arrival_time = c("9999:58:00", "9999:59:00", "9999:59:50"),
    departure_time = c("9999:58:00", "9999:59:00", "9999:59:50"),
    stop_id = c("s0", "X", "s9"),
    stop_sequence = 1:3
  )

  err <- expect_error(tester(feed), class = "gtfstools_time_out_of_range")
  expect_identical(err$call[[1]], quote(set_min_dwell_time))
})
