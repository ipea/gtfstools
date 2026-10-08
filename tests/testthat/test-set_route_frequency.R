spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(spo_path)

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   route_id = "CPTM L07",
                   headway = 10,
                   from = "07:00:00",
                   to = "09:00:00") {
  set_route_frequency(gtfs, route_id, headway, from, to)
}

# builds a small feed with route "r1", whose trips of pattern "abc" (stops a, b
# and c) take 5 minutes between consecutive stops and whose trip "S0715"
# follows the short-turn pattern "ab". in direction 0:
# - "F0" is frequency-based, every 20 minutes from 06:00 to 09:00, with exact
#   times. it straddles both ends of the time of day used in the tests
#   (07:00-08:00) and is the template of the direction
# - "P0" and "P1" are frequency-based, with single-departure entries at 07:00
#   and 08:00
# - "S0650", "S0705", "S0715", "S0800" and "S2440" are scheduled
# the trips of direction NA ("N0710" and "N0740") are scheduled. route "r2" has
# a single frequency-based trip, "G0", that is not listed in 'stop_times'

make_feed <- function() {
  abc_trips <- c(
    F0 = "06:00:00",
    P0 = "07:00:00",
    P1 = "08:00:00",
    S0650 = "06:50:00",
    S0705 = "07:05:00",
    S0800 = "08:00:00",
    S2440 = "24:40:00",
    N0710 = "07:10:00",
    N0740 = "07:40:00"
  )
  departure_secs <- string_to_seconds(abc_trips)

  abc_stop_times <- data.table::data.table(
    trip_id = rep(names(abc_trips), each = 3),
    stop_id = rep(c("a", "b", "c"), length(abc_trips)),
    stop_sequence = rep(1:3, length(abc_trips)),
    departure_time = seconds_to_string(
      rep(departure_secs, each = 3) + rep(c(0L, 300L, 600L), length(abc_trips))
    )
  )

  ab_stop_times <- data.table::data.table(
    trip_id = "S0715",
    stop_id = c("a", "b"),
    stop_sequence = 1:2,
    departure_time = c("07:15:00", "07:20:00")
  )

  stop_times <- rbind(abc_stop_times, ab_stop_times)
  stop_times[, arrival_time := departure_time]

  trip_ids <- c(names(abc_trips), "S0715", "G0")

  feed <- list(
    trips = data.table::data.table(
      route_id = c(rep("r1", length(trip_ids) - 1), "r2"),
      service_id = "s1",
      trip_id = trip_ids,
      direction_id = ifelse(grepl("^N", trip_ids), NA_integer_, 0L)
    ),
    stop_times = stop_times,
    frequencies = data.table::data.table(
      trip_id = c("F0", "P0", "P1", "G0"),
      start_time = c("06:00:00", "07:00:00", "08:00:00", "07:00:00"),
      end_time = c("09:00:00", "07:00:00", "08:00:00", "08:00:00"),
      headway_secs = c(1200L, 600L, 600L, 600L),
      exact_times = c(1L, 1L, 1L, 0L)
    ),
    transfers = data.table::data.table(
      from_stop_id = "c",
      to_stop_id = "a",
      transfer_type = 1L,
      from_trip_id = c("S0705", "F0"),
      to_trip_id = c("S0650", "S0650")
    )
  )

  return(gtfsio::new_gtfs(feed, "dt_gtfs"))
}

# departures outside the time of day, by route, direction and service

outside_departures <- function(gtfs, from, to) {
  group_cols <- intersect(
    c("route_id", "direction_id", "service_id"),
    names(gtfs$trips)
  )
  departures <- get_trip_departures(gtfs, gtfs$trips$trip_id)
  departures <- departures[
    departure_secs < string_to_seconds(from) |
      departure_secs >= string_to_seconds(to)
  ]
  departures <- gtfs$trips[departures, on = "trip_id"]
  departures <- departures[, c(group_cols, "departure_secs"), with = FALSE]
  data.table::setorderv(departures, names(departures))

  return(departures[])
}

# tests -------------------------------------------------------------------

test_that("raises errors and warnings due to incorrect input", {
  expect_error(tester(unclass(gtfs)))
  expect_error(tester(route_id = 1))
  expect_error(tester(route_id = NA_character_))
  expect_error(tester(headway = "10"))
  expect_error(tester(headway = c(10, 20)))
  expect_error(tester(headway = 0))
  expect_error(tester(headway = 0.01))
  expect_error(tester(headway = Inf))
  expect_error(tester(headway = 4e7))
  expect_error(tester(from = "7:00:00"))
  expect_error(tester(to = c("08:00:00", "09:00:00")))
  expect_error(
    tester(from = "09:00:00", to = "09:00:00"),
    class = "gtfstools_invalid_time_of_day"
  )
  expect_error(
    tester(from = "10:00:00", to = "09:00:00"),
    class = "gtfstools_invalid_time_of_day"
  )

  # required files and fields

  expect_error(tester(copy_gtfs_without_file(gtfs, "stop_times")))
  expect_error(tester(copy_gtfs_without_field(gtfs, "stop_times", "stop_id")))
  expect_error(
    tester(copy_gtfs_without_field(gtfs, "stop_times", "stop_sequence"))
  )
  expect_error(
    tester(copy_gtfs_diff_field_class(gtfs, "trips", "service_id", "factor"))
  )

  expect_warning(
    tester(route_id = c("CPTM L07", "ola")),
    class = "gtfstools_invalid_route_id"
  )
  expect_warning(
    result <- tester(route_id = "ola"),
    class = "gtfstools_invalid_route_id"
  )
  expect_identical(result, gtfs)

  # headways are rounded to whole seconds

  feed <- make_feed()
  result <- set_route_frequency(feed, "r1", 7.51, "07:00:00", "08:00:00")
  new_entries <- result$frequencies[start_time == "07:00:00" & trip_id != "G0"]
  expect_identical(new_entries$headway_secs, c(451L, 451L))
})

test_that("results in a dt_gtfs and doesn't change given gtfs", {
  original_gtfs <- convert_time_to_seconds(read_gtfs(spo_path))
  gtfs <- convert_time_to_seconds(read_gtfs(spo_path))
  expect_identical(original_gtfs, gtfs)

  result <- tester(gtfs)
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
  expect_s3_class(result, "dt_gtfs")
  expect_s3_class(result$frequencies, "data.table")

  # '_secs' columns are updated

  expect_identical(
    result$frequencies$start_time_secs,
    string_to_seconds(result$frequencies$start_time)
  )
  expect_identical(
    result$frequencies$end_time_secs,
    string_to_seconds(result$frequencies$end_time)
  )
})

test_that("sets the frequency of a handmade feed correctly", {
  feed <- make_feed()
  original_feed <- make_feed()
  result <- set_route_frequency(feed, "r1", 10, "07:00:00", "08:00:00")
  expect_equal(original_feed, feed, ignore_attr = TRUE)

  # "F0" is clipped around the new entry, keeping the exact times of its
  # departures outside the time of day. "N0710", a scheduled trip, becomes the
  # template of direction NA. the single-departure entry of "P0" within the
  # time of day is dropped, while the one of "P1" at 'to' is kept

  expected_frequencies <- data.table::data.table(
    trip_id = c("F0", "F0", "F0", "G0", "N0710", "P1"),
    start_time = c(
      "06:00:00", "07:00:00", "08:00:00", "07:00:00", "07:00:00", "08:00:00"
    ),
    end_time = c(
      "07:00:00", "08:00:00", "09:00:00", "08:00:00", "08:00:00", "08:00:00"
    ),
    headway_secs = c(1200L, 600L, 1200L, 600L, 600L, 600L),
    exact_times = c(1L, 0L, 1L, 0L, 0L, 1L)
  )
  data.table::setorderv(result$frequencies, c("trip_id", "start_time"))
  expect_equal(result$frequencies, expected_frequencies, ignore_attr = TRUE)

  # "S0705" and "N0740" departed within the time of day, "S0715" follows the
  # short-turn pattern and "P0" has no 'frequencies' entries left

  expected_trips <- c("F0", "P1", "S0650", "S0800", "S2440", "N0710", "G0")
  expect_identical(result$trips$trip_id, expected_trips)
  expect_setequal(
    unique(result$stop_times$trip_id),
    setdiff(expected_trips, "G0")
  )
  expect_identical(result$transfers$from_trip_id, "F0")

  # the departures outside the time of day are kept, and get_route_frequency()
  # reports the new headway

  expect_identical(
    outside_departures(result, "07:00:00", "08:00:00"),
    outside_departures(feed, "07:00:00", "08:00:00")
  )

  frequency <- get_route_frequency(result, "r1", "07:00:00", "08:00:00")
  expect_identical(frequency$departures, c(6L, 6L))
  expect_equal(frequency$mean_headway, c(10, 10))

  # times of day past midnight

  result <- set_route_frequency(feed, "r1", 30, "24:30:00", "25:30:00")
  expect_identical(
    result$frequencies[trip_id == "S2440"]$start_time,
    "24:30:00"
  )
  expect_identical(
    result$frequencies[trip_id == "S2440"]$end_time,
    "25:30:00"
  )
  expect_identical(nrow(result$trips), nrow(feed$trips))
})

test_that("leaves groups without a template unchanged, with a warning", {
  feed <- make_feed()

  # "G0" is not listed in 'stop_times', so it can't be a template

  expect_warning(
    result <- set_route_frequency(feed, "r2", 10, "07:00:00", "08:00:00"),
    class = "gtfstools_no_template"
  )
  expect_identical(result, feed)

  # neither can a trip whose departure times in 'stop_times' are blank

  blank_stop_times <- data.table::data.table(
    trip_id = "G0",
    stop_id = c("a", "b"),
    stop_sequence = 1:2,
    departure_time = "",
    arrival_time = ""
  )
  blank_feed <- make_feed()
  blank_feed$stop_times <- rbind(blank_feed$stop_times, blank_stop_times)

  expect_warning(
    result <- set_route_frequency(
      blank_feed,
      "r2",
      10,
      "07:00:00",
      "08:00:00"
    ),
    class = "gtfstools_no_template"
  )
  expect_identical(result, blank_feed)

  # other routes are still changed

  expect_warning(
    result <- set_route_frequency(
      feed,
      c("r1", "r2"),
      10,
      "07:00:00",
      "08:00:00"
    ),
    class = "gtfstools_no_template"
  )
  expect_identical(
    result$frequencies[trip_id == "G0"],
    feed$frequencies[trip_id == "G0"]
  )
  expect_false("S0705" %chin% result$trips$trip_id)
})

test_that("sets the headway of every group of real feeds", {
  for (path in c(spo_path, poa_path, ber_path)) {
    path_gtfs <- read_gtfs(path)
    routes <- unique(path_gtfs$trips$route_id)
    original_frequency <- get_route_frequency(
      path_gtfs,
      routes,
      "07:00:00",
      "09:00:00"
    )

    result <- expect_silent(
      set_route_frequency(path_gtfs, routes, 10, "07:00:00", "09:00:00")
    )

    frequency <- get_route_frequency(result, routes, "07:00:00", "09:00:00")
    expect_identical(
      frequency[, -c("departures", "mean_headway")],
      original_frequency[, -c("departures", "mean_headway")]
    )
    expect_true(all(frequency$departures == 12L))
    expect_equal(frequency$mean_headway, rep(10, nrow(frequency)))

    expect_identical(
      outside_departures(result, "07:00:00", "09:00:00"),
      outside_departures(path_gtfs, "07:00:00", "09:00:00")
    )

    expect_s3_class(frequencies_to_stop_times(result), "dt_gtfs")
  }

  # spo's 'frequencies' doesn't have 'exact_times', which is therefore not
  # added. a 'frequencies' table is created for poa

  expect_false("exact_times" %chin% names(tester(gtfs)$frequencies))

  poa_gtfs <- read_gtfs(poa_path)
  expect_null(poa_gtfs$frequencies)
  result <- set_route_frequency(
    poa_gtfs,
    poa_gtfs$trips$route_id[1],
    10,
    "07:00:00",
    "09:00:00"
  )
  expect_identical(unique(result$frequencies$exact_times), 0L)
})

test_that("works without direction_id", {
  no_direction_gtfs <- copy_gtfs_without_field(gtfs, "trips", "direction_id")
  routes <- unique(gtfs$trips$route_id)

  result <- set_route_frequency(
    no_direction_gtfs,
    routes,
    10,
    "07:00:00",
    "09:00:00"
  )
  frequency <- get_route_frequency(result, routes, "07:00:00", "09:00:00")
  expect_false("direction_id" %chin% names(frequency))
  expect_true(all(frequency$departures == 12L))
})
