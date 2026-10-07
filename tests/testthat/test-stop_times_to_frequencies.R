data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL) {
  stop_times_to_frequencies(gtfs, trip_id)
}

# builds a small feed in which each trip of pattern "abc" (stops a, b and c)
# takes 5 minutes between consecutive stops. trip "B0705" follows pattern "ac"
# and trip "NA" has no departure times

make_feed <- function() {
  departures <- c(
    T0700 = "07:00:00",
    T0710 = "07:10:00",
    T0725 = "07:25:00",
    T0750 = "07:50:00",
    T0805 = "08:05:00",
    T2430 = "24:30:00",
    T2445 = "24:45:00"
  )
  departure_secs <- string_to_seconds(departures)

  abc_stop_times <- data.table::data.table(
    trip_id = rep(names(departures), each = 3),
    stop_id = rep(c("a", "b", "c"), length(departures)),
    stop_sequence = rep(1:3, length(departures)),
    departure_time = seconds_to_string(
      rep(departure_secs, each = 3) + rep(c(0L, 300L, 600L), length(departures))
    )
  )
  abc_stop_times[, arrival_time := departure_time]

  other_stop_times <- data.table::data.table(
    trip_id = c("B0705", "B0705", "NA", "NA"),
    stop_id = c("a", "c", "a", "b"),
    stop_sequence = c(1L, 2L, 1L, 2L),
    departure_time = c("07:05:00", "07:20:00", "", ""),
    arrival_time = c("07:05:00", "07:20:00", "", "")
  )

  trip_ids <- c(names(departures), "B0705", "NA")

  feed <- list(
    trips = data.table::data.table(
      route_id = "r1",
      service_id = "s1",
      trip_id = trip_ids,
      direction_id = 0L,
      shape_id = "sh1"
    ),
    stop_times = rbind(abc_stop_times, other_stop_times)
  )

  return(gtfsio::new_gtfs(feed, "dt_gtfs"))
}

# number of departures recreated by frequencies_to_stop_times() from a
# one-hour entry with the headway set by stop_times_to_frequencies()

n_recreated_departures <- function(n) {
  freqs <- data.table::data.table(
    trip_id = "a",
    start_time_secs = 0L,
    end_time_secs = 3600L,
    headway_secs = as.integer(ceiling(3600 / n))
  )
  nrow(get_frequencies_departures(freqs))
}


# tests -------------------------------------------------------------------


test_that("raises errors due to incorrect input types/value", {
  no_class_gtfs <- structure(gtfs, class = NULL)
  expect_error(tester(no_class_gtfs))
  expect_error(tester(trip_id = as.factor("143765658")))
  expect_error(tester(trip_id = NA_character_))
  expect_error(tester(trip_id = 1))
})

test_that("raises errors due to missing required files/fields", {
  no_trips <- copy_gtfs_without_file(gtfs, "trips")
  no_stop_times <- copy_gtfs_without_file(gtfs, "stop_times")
  no_route_id <- copy_gtfs_without_field(gtfs, "trips", "route_id")
  no_departure <- copy_gtfs_without_field(gtfs, "stop_times", "departure_time")
  expect_error(tester(no_trips))
  expect_error(tester(no_stop_times))
  expect_error(tester(no_route_id))
  expect_error(tester(no_departure))
})

test_that("raises warnings for non-existent and frequency-based trip_ids", {
  expect_warning(tester(trip_id = "foo"))

  spo_gtfs <- read_gtfs(
    system.file("extdata/spo_gtfs.zip", package = "gtfstools")
  )
  expect_warning(
    result <- tester(spo_gtfs, trip_id = "CPTM L07-0"),
    class = "gtfstools_frequency_based_trips"
  )
  expect_identical(result$frequencies, spo_gtfs$frequencies)
  expect_identical(result$trips, spo_gtfs$trips)

  # no warning when all trips are converted
  expect_silent(tester(spo_gtfs))
})

test_that("results in a dt_gtfs object", {
  result <- tester()
  expect_s3_class(result, "dt_gtfs")
  expect_s3_class(result$frequencies, "data.table")
  expect_type(result$frequencies$headway_secs, "integer")
  expect_type(result$frequencies$exact_times, "integer")
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(data_path)
  gtfs <- read_gtfs(data_path)
  expect_identical(original_gtfs, gtfs)

  result <- tester(gtfs)
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  # including when _secs columns are present
  secs_gtfs <- convert_time_to_seconds(gtfs)
  original_secs_gtfs <- data.table::copy(secs_gtfs)
  result <- tester(secs_gtfs)
  expect_equal(original_secs_gtfs, secs_gtfs, ignore_attr = TRUE)
})

test_that("converts trips to the expected frequencies entries", {
  feed <- make_feed()
  result <- tester(feed)

  expected_frequencies <- data.table::data.table(
    trip_id = c("T0700", "B0705", "T0805", "T2430"),
    start_time = c("07:00:00", "07:00:00", "08:00:00", "24:00:00"),
    end_time = c("08:00:00", "08:00:00", "09:00:00", "25:00:00"),
    headway_secs = c(900L, 3600L, 3600L, 1800L),
    exact_times = 0L
  )
  data.table::setorder(expected_frequencies, trip_id)
  actual_frequencies <- data.table::setorder(
    data.table::copy(result$frequencies),
    trip_id
  )
  expect_identical(actual_frequencies, expected_frequencies)

  # templates keep their trips and stop_times entries, the trip without
  # departures is left unchanged and the other trips are removed

  kept_trips <- c("T0700", "B0705", "T0805", "T2430", "NA")
  expect_setequal(result$trips$trip_id, kept_trips)
  expect_setequal(unique(result$stop_times$trip_id), kept_trips)
  expect_identical(
    result$stop_times,
    feed$stop_times[trip_id %chin% kept_trips]
  )
})

test_that("headways recreate the same number of trips (up to 60 per hour)", {
  n <- 1:60
  expect_identical(vapply(n, n_recreated_departures, integer(1)), n)
})

test_that("trips in different groups are not merged", {
  feed <- make_feed()

  # T0710 now has a different shape, and T0725 a different service

  feed$trips[trip_id == "T0710", shape_id := "sh2"]
  feed$trips[trip_id == "T0725", service_id := "s2"]
  result <- tester(feed)

  freqs <- result$frequencies[start_time == "07:00:00"]
  expect_setequal(freqs$trip_id, c("T0700", "T0710", "T0725", "B0705"))
  expect_identical(freqs[trip_id == "T0700"]$headway_secs, 1800L)
  expect_identical(freqs[trip_id == "T0710"]$headway_secs, 3600L)
})

test_that("works without the optional direction_id and shape_id fields", {
  feed <- make_feed()
  feed$trips[trip_id == "T0710", shape_id := "sh2"]
  no_optional <- copy_gtfs_without_field(feed, "trips", "direction_id")
  no_optional <- copy_gtfs_without_field(no_optional, "trips", "shape_id")

  # without shape_id, T0710 is grouped with the other trips of the same pattern
  result <- tester(no_optional)
  expect_identical(
    result$frequencies[trip_id == "T0700"]$headway_secs,
    900L
  )

  result <- tester(copy_gtfs_without_field(gtfs, "trips", "shape_id"))
  expect_s3_class(result, "dt_gtfs")
})

test_that("only converts the specified trips", {
  feed <- make_feed()
  result <- tester(feed, trip_id = c("T0710", "T0725", "T0750"))

  expect_identical(result$frequencies$trip_id, "T0710")
  expect_identical(result$frequencies$headway_secs, 1200L)
  expect_setequal(
    result$trips$trip_id,
    setdiff(feed$trips$trip_id, c("T0725", "T0750"))
  )
})

test_that("returns the same gtfs when there is nothing to convert", {
  feed <- make_feed()
  result <- tester(feed, trip_id = "NA")
  expect_null(result$frequencies)
  expect_identical(result, feed)

  result <- tester(feed, trip_id = character(0))
  expect_identical(result, feed)
})

test_that("round trip keeps the number of trips of each group and hour", {
  poa_gtfs <- read_gtfs(
    system.file("extdata/poa_gtfs.zip", package = "gtfstools")
  )
  converted_gtfs <- tester(poa_gtfs)
  back_gtfs <- frequencies_to_stop_times(converted_gtfs)
  expect_identical(nrow(back_gtfs$trips), nrow(poa_gtfs$trips))

  count_by_route_hour <- function(g) {
    first_departures <- g$stop_times[
      ,
      .(first = min(string_to_seconds(departure_time), na.rm = TRUE)),
      by = trip_id
    ]
    first_departures[
      g$trips,
      on = "trip_id",
      `:=`(route_id = i.route_id, service_id = i.service_id)
    ]
    first_departures[
      ,
      .N,
      keyby = .(route_id, service_id, hour = first %/% 3600L)
    ]
  }

  original_counts <- count_by_route_hour(poa_gtfs)

  # non-vacuity: the conversion merged some trips, and no slot has more than
  # 60 trips (route-service-hour counts are an upper bound of slot counts)
  expect_lt(nrow(converted_gtfs$trips), nrow(poa_gtfs$trips))
  expect_lte(max(original_counts$N), 60L)

  expect_identical(count_by_route_hour(back_gtfs), original_counts)
})

test_that("handles existing frequencies, _secs columns and transfers", {
  ggl_gtfs <- read_gtfs(
    system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
  )
  original_frequencies <- ggl_gtfs$frequencies
  result <- tester(ggl_gtfs)
  original_cols <- names(original_frequencies)
  expect_identical(
    result$frequencies[seq_len(nrow(original_frequencies)), ..original_cols],
    original_frequencies
  )

  # transfers referring to removed trips are dropped

  feed <- make_feed()
  feed$transfers <- data.table::data.table(
    from_stop_id = "c",
    to_stop_id = "a",
    from_trip_id = c("T0700", "T0710", ""),
    to_trip_id = c("B0705", "B0705", ""),
    transfer_type = 0L
  )
  result <- tester(feed)
  expect_identical(result$transfers, feed$transfers[c(1, 3)])

  # _secs columns of frequencies are filled in for the new entries

  spo_gtfs <- read_gtfs(
    system.file("extdata/spo_gtfs.zip", package = "gtfstools")
  )
  spo_gtfs$trips <- rbind(spo_gtfs$trips, feed$trips[1:2], fill = TRUE)
  spo_gtfs$stop_times <- rbind(
    spo_gtfs$stop_times,
    feed$stop_times[trip_id %chin% c("T0700", "T0710")],
    fill = TRUE
  )
  spo_gtfs <- convert_time_to_seconds(spo_gtfs)
  result <- tester(spo_gtfs)

  new_entry <- result$frequencies[trip_id == "T0700"]
  expect_identical(new_entry$start_time_secs, 25200L)
  expect_identical(new_entry$end_time_secs, 28800L)
  expect_false(anyNA(result$frequencies$start_time_secs))
  expect_no_error(frequencies_to_stop_times(result))
})
