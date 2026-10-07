spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)
poa_gtfs <- read_gtfs(poa_path)

tester <- function(gtfs = poa_gtfs, trip_id = NULL, method = "shapes") {
  interpolate_stop_times(gtfs, trip_id, method)
}

# creates a feed with a single trip that serves stops on the equator, where
# great-circle distances are proportional to the difference in longitude.
# the trip's shape is a straight line from the first to the last stop

synthetic_feed <- function(stop_lon, arrival_time, departure_time = NULL) {
  if (is.null(departure_time)) departure_time <- arrival_time
  stop_ids <- paste0("s", seq_along(stop_lon))

  feed <- list(
    trips = data.table::data.table(trip_id = "t1", shape_id = "sh1"),
    shapes = data.table::data.table(
      shape_id = "sh1",
      shape_pt_lat = c(0, 0),
      shape_pt_lon = range(stop_lon),
      shape_pt_sequence = 1:2
    ),
    stops = data.table::data.table(
      stop_id = stop_ids,
      stop_lat = 0,
      stop_lon = stop_lon
    ),
    stop_times = data.table::data.table(
      trip_id = "t1",
      arrival_time = arrival_time,
      departure_time = departure_time,
      stop_id = stop_ids,
      stop_sequence = seq_along(stop_ids)
    )
  )

  return(gtfsio::new_gtfs(feed, "dt_gtfs"))
}

basic_feed <- synthetic_feed(
  c(0, 0.01, 0.02, 0.04, 0.05),
  c("08:00:00", "", "", "", "08:10:00")
)

# tests ---

test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(basic_feed)))
  expect_error(tester(basic_feed, trip_id = NA_character_))
  expect_error(tester(basic_feed, trip_id = 1))
  expect_error(tester(basic_feed, method = "shape"))
  expect_error(tester(basic_feed, method = c("shapes", "euclidean")))
  expect_error(tester(basic_feed, method = 1))

  no_sequence <- copy_gtfs_without_field(
    basic_feed,
    "stop_times",
    "stop_sequence"
  )
  expect_error(tester(no_sequence))
  character_sequence <- copy_gtfs_diff_field_class(
    basic_feed,
    "stop_times",
    "stop_sequence",
    "character"
  )
  expect_error(tester(character_sequence))
})

test_that("results in a dt_gtfs object", {
  result <- tester(basic_feed)
  expect_s3_class(result, c("dt_gtfs", "gtfs", "list"))
  expect_s3_class(result$stop_times, "data.table")
  expect_identical(names(result$stop_times), names(basic_feed$stop_times))
})

test_that("interpolates times proportionally to distances", {
  expected <- c("08:00:00", "08:02:00", "08:04:00", "08:08:00", "08:10:00")

  for (method in c("shapes", "euclidean")) {
    result <- tester(basic_feed, method = method)
    expect_identical(result$stop_times$arrival_time, expected)
    expect_identical(result$stop_times$departure_time, expected)
  }
})

test_that("interpolates from the departure to the next arrival", {
  feed <- synthetic_feed(
    c(0, 0.01, 0.02, 0.04, 0.05),
    arrival_time = c("08:00:00", "", "08:04:00", "", "08:10:00"),
    departure_time = c("08:00:00", "", "08:06:00", "", "08:10:00")
  )
  result <- tester(feed, method = "euclidean")
  expect_identical(
    result$stop_times$arrival_time,
    c("08:00:00", "08:02:00", "08:04:00", "08:08:40", "08:10:00")
  )
  expect_identical(
    result$stop_times$departure_time,
    c("08:00:00", "08:02:00", "08:06:00", "08:08:40", "08:10:00")
  )
})

test_that("rounds to the nearest second", {
  feed <- synthetic_feed(
    c(0, 0.01, 0.02, 0.03),
    c("08:00:00", NA, "NA", "08:00:10")
  )
  result <- tester(feed, method = "euclidean")
  expect_identical(
    result$stop_times$arrival_time,
    c("08:00:00", "08:00:03", "08:00:07", "08:00:10")
  )
})

test_that("handles times past midnight", {
  feed <- synthetic_feed(c(0, 0.01, 0.02), c("25:59:00", "", "26:01:00"))
  result <- tester(feed, method = "euclidean")
  expect_identical(result$stop_times$arrival_time[2], "26:00:00")
})

test_that("spreads times evenly if the distance between timepoints is 0", {
  feed <- synthetic_feed(c(0, 0, 0), c("08:00:00", "", "08:02:00"))
  result <- tester(feed, method = "euclidean")
  expect_identical(result$stop_times$arrival_time[2], "08:01:00")
})

test_that("handles trips that visit the same place twice", {
  feed <- synthetic_feed(
    c(0, 0.01, 0.02, 0.01, 0),
    c("08:00:00", "", "", "", "08:08:00")
  )
  result <- tester(feed, method = "euclidean")
  expect_identical(
    result$stop_times$arrival_time,
    c("08:00:00", "08:02:00", "08:04:00", "08:06:00", "08:08:00")
  )
})

test_that("fills a timepoint's blank time with its other time", {
  feed <- synthetic_feed(
    c(0, 0.01, 0.02),
    arrival_time = c("", "", "08:02:00"),
    departure_time = c("08:00:00", "", "")
  )
  result <- tester(feed, method = "euclidean")
  expect_identical(
    result$stop_times$arrival_time,
    c("08:00:00", "08:01:00", "08:02:00")
  )
  expect_identical(
    result$stop_times$departure_time,
    c("08:00:00", "08:01:00", "08:02:00")
  )

  # half blank timepoints don't require distances
  feed <- synthetic_feed(
    c(0, 0.01),
    arrival_time = c("", "08:02:00"),
    departure_time = c("08:00:00", "")
  )
  feed$stops <- NULL
  expect_silent(result <- tester(feed))
  expect_identical(result$stop_times$arrival_time, c("08:00:00", "08:02:00"))
})

test_that("leaves stops outside two timepoints blank, with a warning", {
  feed <- synthetic_feed(
    c(0, 0.01, 0.02, 0.03, 0.04),
    c("", "08:00:00", NA, "08:10:00", NA)
  )
  expect_warning(
    result <- tester(feed, method = "euclidean"),
    class = "gtfstools_times_not_interpolated"
  )
  expect_identical(
    result$stop_times$arrival_time,
    c("", "08:00:00", "08:05:00", "08:10:00", NA)
  )

  # trips with fewer than two timepoints don't need distances, so no shape
  # warning is raised
  one_timepoint <- synthetic_feed(c(0, 0.01, 0.02), c("08:00:00", "", ""))
  one_timepoint$shapes <- NULL
  expect_warning(
    result <- tester(one_timepoint),
    class = "gtfstools_times_not_interpolated"
  )
  expect_identical(result$stop_times, one_timepoint$stop_times)

  no_timepoint <- synthetic_feed(c(0, 0.01), c("", ""))
  expect_warning(
    result <- tester(no_timepoint),
    class = "gtfstools_times_not_interpolated"
  )
  expect_identical(result$stop_times, no_timepoint$stop_times)
})

test_that("leaves spans with unknown distances blank, with a warning", {
  feed <- data.table::copy(basic_feed)
  feed$stops[stop_id == "s2", stop_lon := NA]
  expect_warning(
    result <- tester(feed, method = "euclidean"),
    class = "gtfstools_times_not_interpolated"
  )
  expect_identical(
    result$stop_times$arrival_time,
    c("08:00:00", "", "", "", "08:10:00")
  )

  # trips not linked to a shape
  feed <- data.table::copy(basic_feed)
  feed$trips[, shape_id := NA_character_]
  expect_warning(
    expect_warning(
      result <- tester(feed),
      class = "gtfstools_trips_without_shape"
    ),
    class = "gtfstools_times_not_interpolated"
  )
  expect_identical(result$stop_times, feed$stop_times)
})

test_that("falls back to euclidean distances without shapes", {
  feed <- copy_gtfs_without_file(basic_feed, "shapes")
  expect_warning(
    result <- tester(feed),
    class = "gtfstools_shapes_unavailable"
  )
  expect_identical(
    result$stop_times$arrival_time,
    c("08:00:00", "08:02:00", "08:04:00", "08:08:00", "08:10:00")
  )
})

test_that("leaves spans whose arrival is earlier than the departure blank", {
  feed <- synthetic_feed(c(0, 0.01, 0.02), c("23:59:00", "", "00:01:00"))
  expect_warning(
    result <- tester(feed, method = "euclidean"),
    regexp = "after midnight",
    class = "gtfstools_times_not_interpolated"
  )
  expect_identical(result$stop_times, feed$stop_times)

  # a trip with a backwards span and other blanks is listed for both reasons
  feed <- synthetic_feed(
    c(0, 0.01, 0.02, 0.03),
    c("23:59:00", "", "00:01:00", "")
  )
  warning <- expect_warning(
    tester(feed, method = "euclidean"),
    class = "gtfstools_times_not_interpolated"
  )
  expect_match(conditionMessage(warning), "Affected trip")
  expect_match(conditionMessage(warning), "after midnight")
})

test_that("doesn't mix up stops of different trips", {
  feed <- synthetic_feed(c(0, 0.01, 0.02), c("08:00:00", "", "08:02:00"))
  t2 <- data.table::copy(feed$stop_times)
  t2[, `:=`(trip_id = "t2", arrival_time = c("", "09:00:00", "09:02:00"))]
  t2[, departure_time := arrival_time]
  feed$stop_times <- rbind(feed$stop_times, t2)[c(1, 4, 2, 5, 3, 6)]
  feed$trips <- data.table::data.table(
    trip_id = c("t1", "t2"),
    shape_id = "sh1"
  )

  expect_warning(
    result <- tester(feed, method = "euclidean"),
    class = "gtfstools_times_not_interpolated"
  )
  expect_identical(
    result$stop_times$arrival_time,
    c("08:00:00", "", "08:01:00", "09:00:00", "08:02:00", "09:02:00")
  )
})

test_that("interpolates only the given trip_ids", {
  feed <- synthetic_feed(c(0, 0.01, 0.02), c("08:00:00", "", "08:02:00"))
  t2 <- data.table::copy(feed$stop_times)
  t2[, trip_id := "t2"]
  feed$stop_times <- rbind(feed$stop_times, t2)
  feed$trips <- data.table::data.table(
    trip_id = c("t1", "t2"),
    shape_id = "sh1"
  )

  result <- tester(feed, trip_id = "t2", method = "euclidean")
  expect_identical(
    result$stop_times$arrival_time,
    c("08:00:00", "", "08:02:00", "08:00:00", "08:01:00", "08:02:00")
  )

  expect_warning(
    result <- tester(feed, trip_id = c("t1", "missing"), method = "euclidean"),
    "missing"
  )
  expect_identical(result$stop_times$arrival_time[2], "08:01:00")
  expect_identical(result$stop_times$arrival_time[5], "")
})

test_that("ignores blank stop times without a trip_id", {
  feed <- synthetic_feed(c(0, 0.01, 0.02), c("08:00:00", "", "08:02:00"))
  na_row <- data.table::copy(feed$stop_times[2])
  na_row[, trip_id := NA_character_]
  feed$stop_times <- rbind(na_row, feed$stop_times)

  expect_warning(
    result <- tester(feed, method = "euclidean"),
    class = "gtfstools_times_not_interpolated"
  )
  expect_identical(
    result$stop_times$arrival_time,
    c("", "08:00:00", "08:01:00", "08:02:00")
  )
})

test_that("leaves malformed times unchanged", {
  feed <- synthetic_feed(
    c(0, 0.01, 0.02, 0.03),
    c("08:00:00", "  ", "8h", "08:03:00")
  )
  # the malformed time is in both time columns, so it's warned about twice
  expect_warning(
    expect_warning(
      result <- tester(feed, method = "euclidean"),
      class = "gtfstools_malformed_time"
    ),
    class = "gtfstools_malformed_time"
  )
  expect_identical(
    result$stop_times$arrival_time,
    c("08:00:00", "08:01:00", "8h", "08:03:00")
  )
})

test_that("updates _secs and timepoint columns", {
  feed <- convert_time_to_seconds(basic_feed, "stop_times")
  feed$stop_times[, timepoint := c(1L, NA, NA, NA, 1L)]

  result <- tester(feed, method = "euclidean")
  expected_secs <- c(28800L, 28920L, 29040L, 29280L, 29400L)
  expect_identical(result$stop_times$arrival_time_secs, expected_secs)
  expect_identical(result$stop_times$departure_time_secs, expected_secs)
  expect_identical(result$stop_times$timepoint, c(1L, 0L, 0L, 0L, 1L))

  feed$stop_times[, timepoint := c("1", "", "", "", "1")]
  result <- tester(feed, method = "euclidean")
  expect_identical(result$stop_times$timepoint, c("1", "0", "0", "0", "1"))
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(poa_path)
  gtfs <- read_gtfs(poa_path)
  expect_identical(original_gtfs, gtfs)

  result <- suppressWarnings(tester(gtfs))
  expect_identical(original_gtfs, gtfs)

  # existing _secs columns are not updated by reference either
  gtfs <- convert_time_to_seconds(gtfs, "stop_times")
  original_secs <- data.table::copy(gtfs$stop_times)
  result <- suppressWarnings(tester(gtfs))
  expect_identical(original_secs, gtfs$stop_times)
})

test_that("returns feeds without blank times unchanged", {
  expect_identical(tester(spo_gtfs), spo_gtfs)

  ber_gtfs <- read_gtfs(ber_path)
  expect_identical(tester(ber_gtfs), ber_gtfs)
})

test_that("fills poa's blank times, which never decrease", {
  expect_warning(
    result <- tester(poa_gtfs),
    class = "gtfstools_times_not_interpolated"
  )
  st <- data.table::copy(result$stop_times)

  # trips that cross midnight are written with times such as "00:02:00"
  st[, is_blank := arrival_time == "" | departure_time == ""]
  blank_trips <- unique(st[is_blank == TRUE]$trip_id)
  expect_length(blank_trips, 10)

  st <- st[!trip_id %chin% blank_trips]
  st[, `:=`(
    arr = string_to_seconds(arrival_time),
    dep = string_to_seconds(departure_time)
  )]
  data.table::setorderv(st, c("trip_id", "stop_sequence"))
  st[, next_arr := data.table::shift(arr, type = "lead"), by = trip_id]
  expect_true(all(st$dep >= st$arr))
  expect_true(all(st$next_arr >= st$dep, na.rm = TRUE))

  # the original timepoints are kept
  is_timepoint <- poa_gtfs$stop_times$arrival_time != ""
  expect_identical(
    result$stop_times$arrival_time[is_timepoint],
    poa_gtfs$stop_times$arrival_time[is_timepoint]
  )
})
