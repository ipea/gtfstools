spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)

tester <- function(gtfs = hand_gtfs,
                   min_speed = 30,
                   route_id = NULL,
                   trip_id = NULL,
                   unit = "km/h",
                   ...) {
  set_min_speed(gtfs, min_speed, unit, route_id, trip_id, ...)
}

# creates a feed whose trips serve the same stops on the equator, along a
# straight shape. 'times' is a list with the arrival and departure times of
# each trip

synthetic_feed <- function(times, route_id, stop_id = paste0("s", 1:5)) {
  trip_ids <- paste0("t", seq_along(times))

  feed <- list(
    trips = data.table::data.table(
      trip_id = trip_ids,
      route_id = route_id,
      shape_id = "sh1"
    ),
    shapes = data.table::data.table(
      shape_id = "sh1",
      shape_pt_lat = c(0, 0),
      shape_pt_lon = c(0, 0.04),
      shape_pt_sequence = 1:2
    ),
    stops = data.table::data.table(
      stop_id = paste0("s", 1:5),
      stop_lat = 0,
      stop_lon = c(0, 0.01, 0.02, 0.03, 0.04)
    ),
    stop_times = data.table::rbindlist(
      lapply(
        seq_along(times),
        function(i) {
          data.table::data.table(
            trip_id = trip_ids[i],
            arrival_time = times[[i]]$arr,
            departure_time = times[[i]]$dep,
            stop_id = stop_id,
            stop_sequence = seq_along(stop_id)
          )
        }
      )
    )
  )

  return(gtfsio::new_gtfs(feed, "dt_gtfs"))
}

secs <- function(x) string_to_seconds(x)
times_of <- function(gtfs, trip) {
  gtfs$stop_times[trip_id == trip, .(arrival_time, departure_time)]
}
same_times <- function(x) list(arr = x, dep = x)

slow <- same_times(
  c("08:00:00", "08:10:00", "08:20:00", "08:30:00", "08:40:00")
)

# maximum duration, in seconds, of spans with one and two segments at 30 km/h

segment_km <- get_trip_length(
  synthetic_feed(list(slow), "r1"),
  by = "segment"
)$length[1]
max_one <- as.integer(floor(segment_km / 30 * 3600))
max_two <- as.integer(floor(2 * segment_km / 30 * 3600))

# a span just faster than 30 km/h, one with zero duration, one just slower and
# a fast one

boundary_secs <- cumsum(c(8 * 3600, max_one, 0L, max_one + 1L, 60L))

hand_gtfs <- synthetic_feed(
  list(
    # slow first span, a blank stop inside a slow span and a fast last span
    list(
      arr = c("08:00:00", "08:10:00", "", "08:30:00", "08:31:00"),
      dep = c("08:00:00", "08:11:00", "", "08:30:30", "08:31:00")
    ),
    same_times(seconds_to_string(as.integer(boundary_secs))),
    slow
  ),
  route_id = c("r1", "r1", "r2")
)

# tests ---

test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(hand_gtfs)))
  expect_error(tester(min_speed = "30"))
  expect_error(tester(min_speed = 0))
  expect_error(tester(min_speed = -1))
  expect_error(tester(min_speed = NA_real_))
  expect_error(tester(min_speed = Inf))
  expect_error(tester(min_speed = c(30, 40)))
  expect_error(tester(unit = "kms/h"))
  expect_error(tester(unit = c("km/h", "m/s")))
  expect_error(tester(trip_id = NA_character_))
  expect_error(tester(trip_id = 1))
  expect_error(tester(route_id = NA_character_))
  expect_error(tester(route_id = 1))
  expect_error(tester(first_stop = ""))
  expect_error(tester(last_stop = c("s1", "s2")))
  expect_error(tester(from = "8:00:00"))
  expect_error(tester(to = "8:00"))
  expect_error(tester(route_type = "3"))

  e <- tryCatch(
    tester(from = "09:00:00", to = "08:00:00"),
    error = function(e) e
  )
  expect_s3_class(e, "gtfstools_invalid_time_of_day")
  expect_identical(conditionCall(e)[[1]], quote(set_min_speed))
})

test_that("raises warnings if non-existent ids are given", {
  w <- tryCatch(tester(trip_id = c("t1", "ola")), warning = function(w) w)
  expect_match(conditionMessage(w), "ola")
  expect_identical(conditionCall(w)[[1]], quote(set_min_speed))

  # an unknown trip_id doesn't result in all trips being changed

  expect_warning(result <- tester(trip_id = "ola"))
  expect_identical(result, hand_gtfs)
})

test_that("results in a dt_gtfs object", {
  result <- tester()
  expect_s3_class(result, "dt_gtfs")
  expect_s3_class(result, "gtfs")
  expect_type(result, "list")
  expect_s3_class(result$stop_times, "data.table")
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(spo_path)
  gtfs <- read_gtfs(spo_path)
  expect_identical(original_gtfs, gtfs)

  result <- tester(gtfs, min_speed = 20, trip_id = "CPTM L07-0")
  expect_false(identical(result$stop_times, gtfs$stop_times))
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  original_hand <- data.table::copy(hand_gtfs$stop_times)
  result <- tester()
  expect_identical(hand_gtfs$stop_times, original_hand)
})

test_that("raises the speed of every trip by default", {
  result <- tester(spo_gtfs, min_speed = 15)

  # segments of length 0 keep their speed of 0

  speeds <- get_trip_speed(result, by = "segment")
  expect_true(all(speeds[speed > 0]$speed >= 15 - 1e-8, na.rm = TRUE))

  original_speeds <- get_trip_speed(spo_gtfs, by = "segment")
  expect_true(any(original_speeds[speed > 0]$speed < 15, na.rm = TRUE))
})

test_that("speeds up slow spans and shifts the later times earlier", {
  result <- tester(trip_id = "t1")
  times <- times_of(result, "t1")

  # the saved times of the first two spans accumulate. the dwell times are
  # kept and the blank stop inside the slow span stays blank

  saved_first <- 600L - max_one
  saved_second <- 1140L - max_two

  expect_identical(
    secs(times$arrival_time),
    secs(times_of(hand_gtfs, "t1")$arrival_time) -
      c(0L, saved_first, NA, rep(saved_first + saved_second, 2))
  )
  expect_identical(
    secs(times$departure_time),
    secs(times_of(hand_gtfs, "t1")$departure_time) -
      c(0L, saved_first, NA, rep(saved_first + saved_second, 2))
  )
  expect_identical(times$arrival_time[3], "")

  # the other trips don't change

  expect_identical(
    result$stop_times[trip_id != "t1"],
    hand_gtfs$stop_times[trip_id != "t1"]
  )
})

test_that("changes only the spans slower than min_speed", {
  result <- tester(trip_id = "t2")

  # only the span just slower than 30 km/h is shortened, by a second

  expect_identical(
    secs(times_of(result, "t2")$arrival_time),
    as.integer(boundary_secs) - c(0L, 0L, 0L, 1L, 1L)
  )
})

test_that("raises only the spans between first_stop and last_stop", {
  # the times before first_stop don't change, and the times at and after
  # last_stop are shifted earlier

  result <- tester(trip_id = "t3", first_stop = "s2", last_stop = "s4")
  saved <- 600L - max_one

  expect_identical(
    secs(times_of(result, "t3")$arrival_time),
    secs(slow$arr) - c(0L, 0L, saved, 2L * saved, 2L * saved)
  )
})

test_that("unit argument works correctly", {
  expect_identical(
    tester(min_speed = 10, unit = "m/s"),
    tester(min_speed = 36)
  )
})

test_that("leaves spans of length 0 unchanged", {
  feed <- synthetic_feed(
    list(slow),
    route_id = "r1",
    stop_id = c("s1", "s2", "s2", "s3", "s4")
  )
  result <- tester(feed)
  arr <- secs(result$stop_times$arrival_time)

  expect_identical(diff(arr), c(max_one, 600L, max_one, max_one))
})

test_that("may result in spans with zero duration", {
  result <- tester(trip_id = "t3", min_speed = 1e6)
  expect_identical(
    times_of(result, "t3")$arrival_time,
    rep("08:00:00", 5)
  )
})

test_that("leaves spans that end before they start unchanged, with a warning", {
  feed <- synthetic_feed(
    list(
      same_times(c("08:00:00", "08:10:00", "07:00:00", "07:10:00", "07:20:00"))
    ),
    route_id = "r1"
  )

  w <- tryCatch(tester(feed), warning = function(w) w)
  expect_s3_class(w, "gtfstools_backwards_times")
  expect_match(conditionMessage(w), "not raised")

  result <- suppressWarnings(tester(feed))
  saved <- 600L - max_one

  expect_identical(
    secs(result$stop_times$arrival_time),
    secs(feed$stop_times$arrival_time) -
      c(0L, saved, saved, 2L * saved, 3L * saved)
  )
})

test_that("raises an error if times would be earlier than 00:00:00", {
  # the span after last_stop ends before it starts, so it's not reported, but
  # it's shifted

  feed <- synthetic_feed(
    list(
      same_times(c("08:00:00", "08:10:00", "08:20:00", "00:05:00", "00:15:00"))
    ),
    route_id = "r1"
  )

  expect_no_warning(
    e <- tryCatch(tester(feed, last_stop = "s3"), error = function(e) e)
  )
  expect_s3_class(e, "gtfstools_time_out_of_range")
  expect_identical(conditionCall(e)[[1]], quote(set_min_speed))
})
