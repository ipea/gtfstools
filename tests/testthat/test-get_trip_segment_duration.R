data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
trip_id <- "CPTM L07-0"

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   unit = "min") {
  get_trip_segment_duration(gtfs, trip_id, unit)
}

test_that("raises errors due to incorrect input types/value", {
  expect_error(tester(no_class_gtfs))
  expect_error(tester(trip_id = as.factor("CPTM L07-0")))
  expect_error(tester(trip_id = NA))
  expect_error(tester(unit = min))
  expect_error(tester(unit = "mins"))
  expect_error(tester(unit = c("s", "min")))
})

test_that("raises errors if gtfs doesn't have required files/fields", {
  no_stop_times_gtfs <- copy_gtfs_without_file(gtfs, "stop_times")

  no_st_tripid_gtfs <- copy_gtfs_without_field(gtfs, "stop_times", "trip_id")
  no_st_arrtime_gtfs <- copy_gtfs_without_field(
    gtfs, "stop_times", "arrival_time"
  )
  no_st_deptime_gtfs <- copy_gtfs_without_field(
    gtfs, "stop_times", "departure_time"
  )
  no_st_stopseq_gtfs <- copy_gtfs_without_field(
    gtfs, "stop_times", "stop_sequence"
  )

  expect_error(tester(no_stop_times_gtfs), class = "missing_required_file")
  expect_error(tester(no_st_tripid_gtfs), class = "missing_required_field")
  expect_error(tester(no_st_arrtime_gtfs), class = "missing_required_field")
  expect_error(tester(no_st_deptime_gtfs), class = "missing_required_field")
  expect_error(tester(no_st_stopseq_gtfs), class = "missing_required_field")
})

test_that("calculates the duration of correct 'trip_id's", {
  # if trip_id = NULL, all trips in 'stop_times' have their duration calculated

  all_trip_ids <- unique(gtfs$stop_times$trip_id)
  all_trip_ids <- all_trip_ids[order(all_trip_ids)]

  seg_duration_all_trip_ids <- tester(gtfs)
  trip_ids_from_dur <- unique(seg_duration_all_trip_ids$trip_id)
  trip_ids_from_dur <- trip_ids_from_dur[order(trip_ids_from_dur)]

  expect_identical(all_trip_ids, trip_ids_from_dur)

  # else, only the duration of (valid) trip_ids are calculated

  selected_trip_ids <- c("CPTM L07-0", "ola")
  expect_warning(
    dur_selected_trip_ids <- tester(trip_id = selected_trip_ids)
  )
  expect_equal(unique(dur_selected_trip_ids$trip_id), "CPTM L07-0")
})

test_that("raises warnings if a non_existent trip_id is given", {
  expect_warning(tester(trip_id = c("CPTM L07-0", "ola")))
  expect_warning(tester(trip_id = "ola"))
})

test_that("outputs a data.table with adequate columns' classes", {
  segments_durations <- tester(trip_id = "CPTM L07-0")
  expect_s3_class(segments_durations, "data.table")
  expect_equal(class(segments_durations$trip_id), "character")
  expect_equal(class(segments_durations$segment), "integer")
  expect_equal(class(segments_durations$duration), "numeric")

  # should work even if no given 'trip_id's are present in 'stop_times'

  expect_warning(segments_durations <- tester(trip_id = "ola"))
  expect_s3_class(segments_durations, "data.table")
  expect_equal(class(segments_durations$trip_id), "character")
  expect_equal(class(segments_durations$segment), "integer")
  expect_equal(class(segments_durations$duration), "numeric")

  # and when trip_id = character(0)

  segments_durations <- tester(trip_id = character(0))
  expect_s3_class(segments_durations, "data.table")
  expect_equal(class(segments_durations$trip_id), "character")
  expect_equal(class(segments_durations$segment), "integer")
  expect_equal(class(segments_durations$duration), "numeric")
})

test_that("outputs duration in the correct unit", {
  seconds_durations <- tester(trip_id = "CPTM L07-0", unit = "s")
  expect_type(seconds_durations$duration, "integer")
  minutes_durations <- tester(trip_id = "CPTM L07-0", unit = "min")
  hours_durations   <- tester(trip_id = "CPTM L07-0", unit = "h")
  days_durations    <- tester(trip_id = "CPTM L07-0", unit = "d")

  expect_equal(seconds_durations$duration / 60, minutes_durations$duration)
  expect_equal(seconds_durations$duration / 3600, hours_durations$duration)
  expect_equal(seconds_durations$duration / 86400, days_durations$duration)
})

test_that("outputs the correct number of segments", {
  # number of segments is equal to number of stops minus 1
  segments_durations <- tester(trip_id = "CPTM L07-0")
  expect_equal(
    nrow(segments_durations),
    nrow(gtfs$stop_times[trip_id == "CPTM L07-0"]) - 1
  )
})

test_that("segment numbers range from 1 to the total number of segments", {
  trip_ids <- c("CPTM L07-0", "CPTM L07-1")
  segments_durations <- tester(trip_id = trip_ids)

  expect_identical(
    segments_durations[trip_id == "CPTM L07-0"]$segment,
    1:17
  )
  expect_identical(
    segments_durations[trip_id == "CPTM L07-1"]$segment,
    1:17
  )
})

test_that("calculates duration correctly", {
  segments_duration <- tester(trip_id = "CPTM L07-0", unit = "min")
  expect_identical(segments_duration$duration, rep(8, 17))

  # should also work with 24+ hours times

  modified_st_gtfs <- gtfs
  modified_st_gtfs$stop_times <- data.table::copy(gtfs$stop_times)
  modified_st_gtfs$stop_times[
    trip_id == "CPTM L07-0" & stop_sequence == 18,
    arrival_time := "24:00:00"
  ]

  segments_duration <- tester(modified_st_gtfs, "CPTM L07-0")
  expect_identical(segments_duration$duration, c(rep(8, 16), 1072))
})

test_that("returns NA duration when arr/dep time are NA", {
  poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
  poa_gtfs <- read_gtfs(poa_path)
  poa_trip <- "T2-1@1#520"

  durations <- tester(poa_gtfs, poa_trip)
  expect_true(all(is.na(durations$duration)))
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(data_path)
  gtfs <- read_gtfs(data_path)
  expect_identical(original_gtfs, gtfs)

  # selecting trips doesn't add an index to the given stop_times

  durations <- tester(trip_id = "CPTM L07-0")
  expect_identical(original_gtfs, gtfs)
  expect_null(data.table::indices(gtfs$stop_times))

  # should also work with every trip
  durations <- tester()
  expect_identical(original_gtfs, gtfs)
})

test_that("stop_times are sorted by stop_sequence", {
  durations <- tester(trip_id = trip_id)

  unordered_gtfs <- gtfs
  unordered_gtfs$stop_times <- gtfs$stop_times[trip_id == "CPTM L07-0"]
  unordered_gtfs$stop_times <- unordered_gtfs$stop_times[c(10:18, 1:9)]

  expect_identical(tester(unordered_gtfs, trip_id), durations)
})

test_that("sort_sequence is deprecated", {
  expect_warning(
    get_trip_segment_duration(gtfs, trip_id, sort_sequence = TRUE),
    class = "deprecated_sort_sequence"
  )
  expect_error(
    get_trip_segment_duration(gtfs, trip_id, sort_sequence = FALSE),
    class = "gtfstools_defunct_sort_sequence_error"
  )
})

segment_departures <- function(gtfs) {
  st <- data.table::copy(gtfs$stop_times)
  data.table::setorderv(st, c("trip_id", "stop_sequence"))
  segments <- st[
    ,
    .(segment = seq_len(.N - 1L), departure_time = departure_time[-.N]),
    by = trip_id
  ]
  return(segments)
}

test_that("from and to select the segments by their departure", {
  segments <- segment_departures(gtfs)
  expected <- segments[
    segments$departure_time >= "04:00:00" &
      segments$departure_time <= "04:30:00",
    .(trip_id, segment)
  ]
  expect_true(nrow(expected) > 0 && nrow(expected) < nrow(segments))

  result <- get_trip_segment_duration(
    gtfs,
    from = "04:00:00",
    to = "04:30:00"
  )
  expect_identical(result[, .(trip_id, segment)], expected)
  expect_identical(
    result,
    tester()[expected, on = c("trip_id", "segment")]
  )

  empty <- get_trip_segment_duration(gtfs, from = "99:00:00")
  expect_identical(nrow(empty), 0L)
  expect_type(empty$segment, "integer")

  expect_error(
    get_trip_segment_duration(gtfs, from = "09:00:00", to = "08:00:00"),
    class = "gtfstools_invalid_time_of_day"
  )
})

test_that("from and to don't change the given gtfs", {
  original_gtfs <- read_gtfs(data_path)
  given_gtfs <- read_gtfs(data_path)

  result <- get_trip_segment_duration(given_gtfs, from = "04:00:00")
  expect_identical(original_gtfs, given_gtfs)
})

test_that("from and to handle stop_times entries without trip_id", {
  na_gtfs <- read_gtfs(data_path)
  na_gtfs$stop_times[1:2, trip_id := NA_character_]
  stop_times_names <- names(na_gtfs$stop_times)

  result <- get_trip_segment_duration(na_gtfs, from = "04:00:00")
  expected <- get_trip_segment_duration(na_gtfs)[
    segment_departures(na_gtfs)$departure_time >= "04:00:00"
  ]
  expect_identical(result, expected)
  expect_identical(names(na_gtfs$stop_times), stop_times_names)
})

test_that("returns a typed empty table when stop_times is empty", {
  empty_gtfs <- read_gtfs(data_path)
  empty_gtfs$stop_times <- empty_gtfs$stop_times[0]

  result <- get_trip_segment_duration(empty_gtfs, unit = "s")
  expect_identical(nrow(result), 0L)
  expect_type(result$trip_id, "character")
  expect_type(result$segment, "integer")
  expect_type(result$duration, "integer")

  expect_type(tester(empty_gtfs)$duration, "double")
})

test_that("fixes times after midnight written as early morning times", {
  # a trip whose times after midnight are written as early morning times,
  # including the departure from its second stop

  overnight_gtfs <- gtfsio::new_gtfs(
    list(
      stop_times = data.table::data.table(
        trip_id = "t1",
        stop_id = c("s1", "s2", "s3"),
        stop_sequence = 1:3,
        arrival_time = c("23:50:00", "23:58:00", "00:05:00"),
        departure_time = c("23:50:00", "00:01:00", "00:05:00")
      )
    ),
    "dt_gtfs"
  )

  original_gtfs <- gtfsio::new_gtfs(
    lapply(overnight_gtfs, data.table::copy),
    "dt_gtfs"
  )

  expect_no_warning(
    durations <- tester(overnight_gtfs),
    class = "gtfstools_backwards_times"
  )
  expect_equal(durations$duration, c(8, 4))
  expect_equal(overnight_gtfs, original_gtfs, ignore_attr = TRUE)
})
