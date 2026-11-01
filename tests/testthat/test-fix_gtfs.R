# creates a feed with a trip that serves 6 stops on the equator, along a
# straight shape. only the first and last stops have times, and the trip is
# faster than 30 km/h. the feed also includes a duplicated stop time, and a
# route and a stop that no trip uses

hand_feed <- function() {
  feed <- list(
    routes = data.table::data.table(route_id = c("r1", "r_unused")),
    trips = data.table::data.table(
      trip_id = "t1",
      route_id = "r1",
      shape_id = "sh1"
    ),
    shapes = data.table::data.table(
      shape_id = "sh1",
      shape_pt_lat = c(0, 0),
      shape_pt_lon = c(0, 0.05),
      shape_pt_sequence = 1:2
    ),
    stops = data.table::data.table(
      stop_id = c(paste0("s", 1:6), "s_unused"),
      stop_lat = 0,
      stop_lon = c(0, 0.01, 0.02, 0.03, 0.04, 0.05, 1)
    ),
    stop_times = data.table::data.table(
      trip_id = "t1",
      arrival_time = c("08:00:00", "08:00:00", "", "", "", "", "08:01:00"),
      departure_time = c("08:00:00", "08:00:00", "", "", "", "", "08:01:00"),
      stop_id = c("s1", "s1", paste0("s", 2:6)),
      stop_sequence = c(1L, 1L, 2:6)
    )
  )

  return(gtfsio::new_gtfs(feed, "dt_gtfs"))
}

hand_gtfs <- hand_feed()

spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")

tester <- function(gtfs = hand_gtfs,
                   max_speed = 30,
                   speed_unit = "km/h",
                   ...) {
  fix_gtfs(gtfs, max_speed, speed_unit, ...)
}

secs <- function(x) string_to_seconds(x)

# tests ---

test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(hand_gtfs)))
  expect_error(tester(max_speed = -1))
  expect_error(tester(max_speed = NA_real_))
  expect_error(tester(speed_unit = "kms/h"), regexp = "speed_unit")
  expect_error(tester(min_dwell_time = -1), regexp = "min_dwell_time")
  expect_error(
    tester(min_dwell_time = 30, dwell_time_unit = "sec"),
    regexp = "dwell_time_unit"
  )
  expect_error(
    tester(overwrite_stop_times = "TRUE"),
    regexp = "overwrite_stop_times"
  )
  expect_error(
    tester(overwrite_stop_times = NA),
    regexp = "overwrite_stop_times"
  )
})

test_that("raises errors if gtfs doesn't have required tables", {
  expect_error(
    tester(copy_gtfs_without_file(hand_gtfs, "trips")),
    regexp = "trips"
  )
  expect_error(
    tester(copy_gtfs_without_file(hand_gtfs, "stop_times")),
    regexp = "stop_times"
  )
  expect_error(
    tester(copy_gtfs_without_file(hand_gtfs, "stops")),
    regexp = "stops"
  )
})

test_that("results in a dt_gtfs object and doesn't change given gtfs", {
  original_gtfs <- hand_feed()
  gtfs <- hand_feed()
  expect_identical(original_gtfs, gtfs)

  result <- tester(gtfs)
  expect_s3_class(result, "dt_gtfs")
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  result <- tester(gtfs, overwrite_stop_times = TRUE)
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  # spo has neither duplicated stop times nor blank times, so its dwell times
  # are set in the table returned by remove_duplicates(), not in a copy made
  # by a later step

  original_spo <- read_gtfs(spo_path)
  spo <- read_gtfs(spo_path)
  result <- tester(spo, max_speed = NULL, min_dwell_time = 30)
  expect_false(
    identical(result$stop_times$departure_time, spo$stop_times$departure_time)
  )
  expect_equal(original_spo, spo, ignore_attr = TRUE)
})

test_that("removes duplicated entries and unused ids", {
  result <- tester()

  expect_identical(nrow(result$stop_times), 6L)
  expect_identical(result$routes$route_id, "r1")
  expect_identical(result$stops$stop_id, paste0("s", 1:6))
})

test_that("caps the speed before interpolating stop times", {
  result <- tester()
  times <- result$stop_times

  # capping the whole span between the two stops with times delays the last
  # stop by ceiling() of the span's minimum duration. capping each segment
  # after interpolating would round up each segment instead

  unique_gtfs <- remove_duplicates(hand_gtfs)
  segment_secs <- get_trip_length(unique_gtfs, by = "segment")$length /
    30 * 3600
  span_secs <- as.integer(ceiling(sum(segment_secs)))
  expect_false(span_secs == sum(ceiling(segment_secs)))

  start <- secs("08:00:00")
  expect_identical(secs(times$arrival_time[6]), start + span_secs)
  expect_identical(secs(times$departure_time[6]), start + span_secs)

  # blank stops are filled in proportion to the distance along the capped span

  expected_second <- as.integer(
    start + segment_secs[1] / sum(segment_secs) * span_secs + 0.5
  )
  expect_identical(secs(times$arrival_time[2]), expected_second)

  filled <- secs(times$arrival_time)
  expect_false(anyNA(filled))
  expect_true(all(diff(filled) > 0))
})

test_that("doesn't cap speeds if max_speed is NULL", {
  result <- tester(max_speed = NULL)
  times <- result$stop_times

  expect_identical(times$arrival_time[c(1, 6)], c("08:00:00", "08:01:00"))
  expect_false(anyNA(secs(times$arrival_time)))
})

test_that("overwrite_stop_times replaces the times of intermediate stops", {
  # s3 arrives at 08:00:50 and stays 5 seconds
  gtfs <- hand_feed()
  gtfs$stop_times[
    4,
    `:=`(arrival_time = "08:00:50", departure_time = "08:00:55")
  ]

  result <- tester(gtfs, max_speed = NULL)
  expect_identical(
    result$stop_times$arrival_time,
    c("08:00:00", "08:00:25", "08:00:50", "08:00:57", "08:00:58", "08:01:00")
  )

  # the 55 seconds that the trip isn't stopped are spread evenly over its 5
  # segments of equal length
  result <- tester(gtfs, max_speed = NULL, overwrite_stop_times = TRUE)
  expect_identical(
    result$stop_times$arrival_time,
    c("08:00:00", "08:00:11", "08:00:22", "08:00:38", "08:00:49", "08:01:00")
  )
  expect_identical(
    result$stop_times$departure_time,
    c("08:00:00", "08:00:11", "08:00:27", "08:00:38", "08:00:49", "08:01:00")
  )
})

test_that("sets the minimum dwell time at stops with interpolated times", {
  without_min <- tester()
  result <- tester(min_dwell_time = 10)

  expect_identical(nrow(result$stop_times), 6L)
  expect_identical(result$stop_times$stop_id, paste0("s", 1:6))
  expect_identical(
    get_dwell_time(result)$dwell_time,
    c(0, 10, 10, 10, 10, 0)
  )
  expect_identical(result$stop_times$departure_time[1], "08:00:00")
  expect_identical(
    secs(result$stop_times$arrival_time[6]),
    secs(without_min$stop_times$arrival_time[6]) + 40L
  )
})

test_that("works without shapes, with a warning", {
  no_shapes <- copy_gtfs_without_file(hand_gtfs, "shapes")
  warnings <- capture_warnings(result <- tester(no_shapes))
  expect_true(any(grepl("shapes", warnings)))
  expect_s3_class(result, "dt_gtfs")
  expect_false(anyNA(secs(result$stop_times$arrival_time)))
})

test_that("fills shape_dist_traveled, only in feeds with shapes", {
  result <- tester()

  # stops on the equator, 0.01 degrees apart, on the sphere used by {s2}

  expect_equal(
    result$stop_times$shape_dist_traveled,
    (0:5) * 0.01 * 6371010 * pi / 180
  )
  expect_equal(
    result$shapes$shape_dist_traveled,
    c(0, 0.05) * 6371010 * pi / 180
  )

  no_shapes <- copy_gtfs_without_file(hand_gtfs, "shapes")
  result <- suppressWarnings(tester(no_shapes))
  expect_false("shape_dist_traveled" %chin% names(result$stop_times))

  no_shape_id <- copy_gtfs_without_field(hand_gtfs, "trips", "shape_id")
  result <- suppressWarnings(tester(no_shape_id))
  expect_false("shape_dist_traveled" %chin% names(result$stop_times))
})

test_that(desc = "fixes the times of trips that run past midnight", code = {
  # some trips of this feed have times after midnight written as "00:xx:xx".
  # they are fixed first, so their times are then capped and interpolated

  poa_gtfs <- read_gtfs(
    system.file("extdata/poa_gtfs.zip", package = "gtfstools")
  )
  trip <- "T2-1@1#2310"

  warning_classes <- character(0)
  result <- withCallingHandlers(
    tester(poa_gtfs, max_speed = 30, min_dwell_time = 30),
    warning = function(w) {
      warning_classes <<- c(warning_classes, class(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_false(object = "gtfstools_backwards_times" %in% warning_classes)

  # the trip keeps its start time and ends after midnight. its intermediate
  # times are filled, and depend on the capped speeds, so only their order is
  # checked

  trip_times <- result$stop_times[trip_id == trip][order(stop_sequence)]
  expect_identical(object = trip_times$arrival_time[1], expected = "23:10:00")
  expect_true(object = all(trip_times$arrival_time != ""))
  expect_true(object = all(trip_times$departure_time != ""))

  secs <- as.vector(
    x = rbind(
      string_to_seconds(string = trip_times$arrival_time),
      string_to_seconds(string = trip_times$departure_time)
    )
  )
  expect_false(object = is.unsorted(x = secs))
  expect_gte(
    object = secs[length(x = secs)],
    expected = string_to_seconds(string = "24:02:00")
  )
})

test_that("unit arguments work correctly", {
  expect_identical(
    tester(max_speed = 36),
    tester(max_speed = 10, speed_unit = "m/s")
  )
  expect_identical(
    tester(min_dwell_time = 1, dwell_time_unit = "min"),
    tester(min_dwell_time = 60)
  )
  expect_identical(tester(min_dwell_time = 0), tester())
})
