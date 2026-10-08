spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(spo_path)
ggl_gtfs <- read_gtfs(ggl_path)

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   stop_id = NULL,
                   dwell_time = 30,
                   unit = "s",
                   from = NULL,
                   to = NULL,
                   by_reference = FALSE) {
  set_dwell_time(
    gtfs,
    trip_id = trip_id,
    stop_id = stop_id,
    dwell_time = dwell_time,
    unit = unit,
    from = from,
    to = to,
    by_reference = by_reference
  )
}

# small hand-built feed with a single trip, "t", whose rows are not ordered by
# stop_sequence. it visits A twice (a loop), C with blank times, and runs past
# midnight. its dwell times are 60 (A), 30 (B), NA (C), 0 (A) and 60 (D)

hand_gtfs <- read_gtfs(spo_path)
hand_gtfs$stop_times <- data.table::data.table(
  trip_id = "t",
  stop_id = c("C", "A", "B", "A", "D"),
  stop_sequence = c(3L, 1L, 2L, 4L, 5L),
  arrival_time = c("", "23:59:00", "24:05:00", "24:10:00", "24:20:00"),
  departure_time = c("", "24:00:00", "24:05:30", "24:10:00", "24:21:00")
)

# variant of the hand-built feed with an extra visit, to E, whose arrival time
# is blank but whose departure time is not

half_blank_gtfs <- read_gtfs(spo_path)
half_blank_gtfs$stop_times <- rbind(
  hand_gtfs$stop_times,
  data.table::data.table(
    trip_id = "t",
    stop_id = "E",
    stop_sequence = 6L,
    arrival_time = "",
    departure_time = "24:25:00"
  )
)

# returns the times of the given trip, ordered by stop_sequence

trip_times <- function(gtfs, trip) {
  st <- gtfs$stop_times[trip_id == trip]
  st <- st[order(stop_sequence)]
  return(st[, .(stop_id, arrival_time, departure_time)])
}

# tests -------------------------------------------------------------------

test_that("raises errors due to incorrect input types/value", {
  no_class_gtfs <- gtfs
  attr(no_class_gtfs, "class") <- NULL
  expect_error(tester(no_class_gtfs))
  expect_error(tester(trip_id = as.factor("CPTM L07-0")))
  expect_error(tester(trip_id = NA))
  expect_error(tester(stop_id = as.factor("18920")))
  expect_error(tester(stop_id = NA))
  expect_error(tester(dwell_time = "30"))
  expect_error(tester(dwell_time = -1))
  expect_error(tester(dwell_time = NA))
  expect_error(tester(dwell_time = Inf))
  expect_error(tester(dwell_time = numeric(0)))
  expect_error(tester(dwell_time = c(1, 2)))
  expect_error(tester(dwell_time = 1e6, unit = "d"))
  expect_error(tester(dwell_time = 500, unit = "d"))
  expect_error(tester(unit = "mins"))
  expect_error(tester(unit = c("s", "min")))
  expect_error(tester(by_reference = "TRUE"))
  expect_error(tester(by_reference = NA))
  expect_error(tester(by_reference = c(TRUE, TRUE)))

  # dwell_time comes after the ids, so it can't be given by position

  expect_error(set_dwell_time(gtfs, 30))
  expect_error(set_dwell_time(gtfs))
})

test_that("raises errors if gtfs doesn't have required files/fields", {
  no_stop_times <- copy_gtfs_without_file(gtfs, "stop_times")
  expect_error(tester(no_stop_times))

  for (field in c(
    "trip_id",
    "stop_id",
    "stop_sequence",
    "arrival_time",
    "departure_time"
  )) {
    no_field <- copy_gtfs_without_field(gtfs, "stop_times", field)
    expect_error(tester(no_field))
  }

  wrong_class <- copy_gtfs_diff_field_class(
    gtfs,
    "stop_times",
    "stop_sequence",
    "character"
  )
  expect_error(tester(wrong_class))
})

test_that("raises warnings if the given ids select no visit", {
  expect_warning(
    result <- tester(trip_id = "ola"),
    class = "gtfstools_invalid_trip_id"
  )
  expect_equal(result, gtfs, ignore_attr = TRUE)

  expect_warning(
    result <- tester(stop_id = "ola"),
    class = "gtfstools_invalid_stop_id"
  )
  expect_equal(result, gtfs, ignore_attr = TRUE)

  # existing trips and stops that never meet

  expect_warning(
    result <- tester(trip_id = "CPTM L07-0", stop_id = "18960"),
    class = "gtfstools_no_calls_selected"
  )
  expect_equal(result, gtfs, ignore_attr = TRUE)

  # missing ids are not reported twice

  expect_no_warning(
    suppressWarnings(
      tester(trip_id = "ola", stop_id = "18960"),
      classes = "gtfstools_invalid_trip_id"
    )
  )
})

test_that("results in a dt_gtfs object", {
  expect_s3_class(tester(stop_id = "18960"), "dt_gtfs")

  gtfs_copy <- read_gtfs(spo_path)
  expect_s3_class(
    tester(gtfs_copy, stop_id = "18960", by_reference = TRUE),
    "dt_gtfs"
  )
})

test_that("sets the dwell time and shifts the later times", {
  new_gtfs <- tester(trip_id = "CPTM L07-0", stop_id = "18920", dwell_time = 60)

  old_times <- trip_times(gtfs, "CPTM L07-0")
  new_times <- trip_times(new_gtfs, "CPTM L07-0")
  old_secs <- lapply(old_times[, -1], string_to_seconds)
  new_secs <- lapply(new_times[, -1], string_to_seconds)

  # 18920 is the second stop. its arrival is kept and its departure and all
  # later times are 60 seconds later

  expect_identical(new_times$stop_id[2], "18920")
  expect_identical(new_times[1], old_times[1])
  expect_identical(new_times$arrival_time[2], old_times$arrival_time[2])
  expect_identical(new_times$departure_time[2], "04:09:00")
  expect_identical(
    new_secs$arrival_time[-(1:2)],
    old_secs$arrival_time[-(1:2)] + 60L
  )
  expect_identical(
    new_secs$departure_time[-1],
    old_secs$departure_time[-1] + 60L
  )

  expect_identical(
    get_dwell_time(new_gtfs, "CPTM L07-0", "18920")$dwell_time,
    60
  )

  # other trips and other tables are not changed

  expect_identical(
    new_gtfs$stop_times[trip_id != "CPTM L07-0"],
    gtfs$stop_times[trip_id != "CPTM L07-0"]
  )
  expect_identical(new_gtfs$frequencies, gtfs$frequencies)

  # every trip that visits the stop is changed when trip_id is NULL

  new_gtfs <- tester(stop_id = "18960", dwell_time = 60)
  changed <- new_gtfs$stop_times[
    gtfs$stop_times,
    on = c("trip_id", "stop_sequence"),
    trip_id[departure_time != i.departure_time]
  ]
  expect_setequal(
    unique(changed),
    c("CPTM L08-0", "CPTM L08-1", "CPTM L09-0", "CPTM L09-1")
  )
  expect_true(all(get_dwell_time(new_gtfs, stop_id = "18960")$dwell_time == 60))
})

test_that("handles loops, unordered rows, blank times and times past 24h", {
  new_gtfs <- tester(hand_gtfs, stop_id = "A", dwell_time = 120)

  expect_identical(
    trip_times(new_gtfs, "t"),
    data.table::data.table(
      stop_id = c("A", "B", "C", "A", "D"),
      arrival_time = c("23:59:00", "24:06:00", "", "24:11:00", "24:23:00"),
      departure_time = c("24:01:00", "24:06:30", "", "24:13:00", "24:24:00")
    )
  )
  expect_identical(
    get_dwell_time(new_gtfs, stop_id = "A")$dwell_time,
    c(120, 120)
  )

  # setting all dwell times to 0 skips the blank visit silently

  expect_silent(new_gtfs <- tester(hand_gtfs, dwell_time = 0))
  expect_identical(
    get_dwell_time(new_gtfs)$dwell_time,
    c(0, 0, NA, 0, 0)
  )
  expect_identical(
    trip_times(new_gtfs, "t")$arrival_time,
    c("23:59:00", "24:04:00", "", "24:08:30", "24:18:30")
  )
})

test_that("decreases dwell times and handles first and last stops", {

  # ggl's AWE1 has a 10 seconds dwell time at S3 and blank times at S2 and S5

  new_gtfs <- tester(ggl_gtfs, trip_id = "AWE1", stop_id = "S3", dwell_time = 0)
  new_times <- trip_times(new_gtfs, "AWE1")
  old_times <- trip_times(ggl_gtfs, "AWE1")
  expect_identical(new_times[stop_id == "S3"]$departure_time, "00:06:20")
  expect_identical(
    string_to_seconds(new_times[stop_id == "S6"]$arrival_time),
    string_to_seconds(old_times[stop_id == "S6"]$arrival_time) - 10L
  )
  expect_identical(
    new_times[stop_id %chin% c("S2", "S5")],
    old_times[stop_id %chin% c("S2", "S5")]
  )

  # times that don't shift keep their original format ("0:06:10")

  expect_identical(new_times[1], old_times[1])
  expect_identical(
    new_times[stop_id == "S3"]$arrival_time,
    old_times[stop_id == "S3"]$arrival_time
  )

  # the first stop shifts the whole trip after it

  new_gtfs <- tester(hand_gtfs, trip_id = "t", stop_id = "A", dwell_time = 0)
  new_gtfs <- tester(new_gtfs, stop_id = "D", dwell_time = 0)
  expect_identical(
    trip_times(new_gtfs, "t"),
    data.table::data.table(
      stop_id = c("A", "B", "C", "A", "D"),
      arrival_time = c("23:59:00", "24:04:00", "", "24:09:00", "24:19:00"),
      departure_time = c("23:59:00", "24:04:30", "", "24:09:00", "24:19:00")
    )
  )
})

test_that("leaves visits with blank times unchanged with a warning", {
  poa_gtfs <- read_gtfs(poa_path)
  trip <- "T2-1@1#520"
  old_times <- trip_times(poa_gtfs, trip)
  first_stop <- old_times$stop_id[1]
  untimed_stop <- old_times$stop_id[2]
  expect_identical(old_times$departure_time[2], "")

  # a timed first stop with untimed stops after it: the blank times stay blank

  expect_silent(
    new_gtfs <- tester(
      poa_gtfs,
      trip_id = trip,
      stop_id = first_stop,
      dwell_time = 120
    )
  )
  new_times <- trip_times(new_gtfs, trip)
  is_blank <- old_times$departure_time == ""
  expect_identical(new_times[is_blank], old_times[is_blank])
  expect_identical(
    string_to_seconds(new_times$arrival_time[!is_blank][-1]),
    string_to_seconds(old_times$arrival_time[!is_blank][-1]) + 120L
  )

  # an untimed stop can't have its dwell time set

  expect_warning(
    new_gtfs <- tester(poa_gtfs, trip_id = trip, stop_id = untimed_stop),
    class = "gtfstools_blank_dwell_time"
  )
  expect_identical(new_gtfs$stop_times, poa_gtfs$stop_times)

  # the warning counts the calls and the trips separately

  expect_warning(
    tester(hand_gtfs, stop_id = "C"),
    "1 call with .* following trip: "
  )
  two_blank_gtfs <- read_gtfs(spo_path)
  two_blank_gtfs$stop_times <- data.table::copy(hand_gtfs$stop_times)
  two_blank_gtfs$stop_times[stop_id == "B", departure_time := ""]
  expect_warning(
    tester(two_blank_gtfs, stop_id = c("B", "C")),
    "2 calls with .* following trip: "
  )

  # long lists of trips are abbreviated

  many_gtfs <- read_gtfs(spo_path)
  many_gtfs$stop_times <- data.table::data.table(
    trip_id = paste0("t", 1:8),
    stop_id = "A",
    stop_sequence = 1L,
    arrival_time = "",
    departure_time = ""
  )
  expect_warning(
    tester(many_gtfs, stop_id = "A"),
    "8 calls with .* following trips: .*t4.*, .*t5.* and 3 more"
  )
})

test_that("raises an error if times would be out of range", {
  bad_gtfs <- read_gtfs(spo_path)
  bad_gtfs$stop_times <- data.table::data.table(
    trip_id = "t",
    stop_id = c("A", "B"),
    stop_sequence = 1:2,
    arrival_time = c("00:00:00", "00:00:10"),
    departure_time = c("00:05:00", "00:00:10")
  )
  original_stop_times <- data.table::copy(bad_gtfs$stop_times)

  expect_error(
    tester(bad_gtfs, stop_id = "A", dwell_time = 0, by_reference = TRUE),
    class = "gtfstools_time_out_of_range"
  )
  expect_identical(bad_gtfs$stop_times, original_stop_times)

  # each dwell time is within the range of times that can be written, but
  # their sum isn't

  big_gtfs <- read_gtfs(spo_path)
  big_gtfs$stop_times <- data.table::data.table(
    trip_id = "t",
    stop_id = c("A", "B", "C"),
    stop_sequence = 1:3,
    arrival_time = c("08:00:00", "08:10:00", "08:20:00"),
    departure_time = c("08:00:00", "08:10:00", "08:20:00")
  )
  original_stop_times <- data.table::copy(big_gtfs$stop_times)

  expect_error(
    tester(big_gtfs, dwell_time = 2e7, by_reference = TRUE),
    class = "gtfstools_time_out_of_range"
  )
  expect_identical(big_gtfs$stop_times, original_stop_times)
})

test_that("works when no time changes or 'stop_times' is empty", {
  same_gtfs <- tester(gtfs, dwell_time = 0)
  expect_s3_class(same_gtfs, "dt_gtfs")
  expect_identical(same_gtfs$stop_times, gtfs$stop_times)

  empty_gtfs <- read_gtfs(spo_path)
  empty_gtfs$stop_times <- empty_gtfs$stop_times[0]
  result <- tester(empty_gtfs)
  expect_s3_class(result, "dt_gtfs")
  expect_identical(nrow(result$stop_times), 0L)
})

test_that("converts the unit and rounds to whole seconds", {
  new_gtfs <- tester(hand_gtfs, stop_id = "B", dwell_time = 0.5, unit = "min")
  expect_identical(get_dwell_time(new_gtfs, stop_id = "B")$dwell_time, 30)

  new_gtfs <- tester(hand_gtfs, stop_id = "B", dwell_time = 1.4)
  expect_identical(get_dwell_time(new_gtfs, stop_id = "B")$dwell_time, 1)
})

test_that("updates existing _secs columns", {
  secs_gtfs <- convert_time_to_seconds(ggl_gtfs)
  new_gtfs <- tester(secs_gtfs, stop_id = "S3", dwell_time = 30)

  st <- new_gtfs$stop_times
  expect_equal(st$arrival_time_secs, string_to_seconds(st$arrival_time))
  expect_equal(st$departure_time_secs, string_to_seconds(st$departure_time))
  expect_equal(
    st[trip_id == "AWE1" & stop_id == "S3"]$departure_time_secs,
    410
  )
})

test_that("changes the departures of frequency-based trips as documented", {
  trip <- "CPTM L09-0"
  stop <- "18960"
  expect_identical(trip_times(gtfs, trip)$stop_id[1], stop)

  old_expanded <- frequencies_to_stop_times(gtfs, trip)
  old_times <- trip_times(old_expanded, paste0(trip, "_1"))

  # at the first stop, only the arrival there is earlier

  new_expanded <- frequencies_to_stop_times(
    tester(trip_id = trip, stop_id = stop, dwell_time = 60),
    trip
  )
  new_times <- trip_times(new_expanded, paste0(trip, "_1"))
  expect_identical(new_times$departure_time, old_times$departure_time)
  expect_identical(new_times$arrival_time[-1], old_times$arrival_time[-1])
  expect_identical(
    string_to_seconds(new_times$arrival_time[1]),
    string_to_seconds(old_times$arrival_time[1]) - 60L
  )

  # at a later stop, the later times of every departure are shifted

  second_stop <- trip_times(gtfs, trip)$stop_id[2]
  new_expanded <- frequencies_to_stop_times(
    tester(trip_id = trip, stop_id = second_stop, dwell_time = 60),
    trip
  )
  new_times <- trip_times(new_expanded, paste0(trip, "_1"))
  expect_identical(new_times[1:2, -3], old_times[1:2, -3])
  expect_identical(
    string_to_seconds(new_times$departure_time[-1]),
    string_to_seconds(old_times$departure_time[-1]) + 60L
  )
})

test_that("'by_reference' parameter works adequately", {
  original_gtfs <- read_gtfs(spo_path)
  gtfs <- read_gtfs(spo_path)
  expect_identical(original_gtfs, gtfs)

  # if by_reference = FALSE then the given gtfs should not be changed

  new_gtfs <- tester(gtfs, trip_id = "CPTM L07-0", stop_id = "18920")
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  # if by_reference = TRUE then the given gtfs' 'stop_times' is altered, and
  # the function returns invisibly

  expect_invisible(
    tester(gtfs, trip_id = "CPTM L07-0", stop_id = "18920", by_reference = TRUE)
  )
  expect_equal(new_gtfs, gtfs, ignore_attr = TRUE)
  expect_false(isTRUE(all.equal(original_gtfs, gtfs, check.attributes = FALSE)))
})

test_that("only changes the visits that arrive within the time of day", {
  expect_error(tester(from = "7:00:00"))
  expect_error(
    tester(from = "09:00:00", to = "07:00:00"),
    class = "gtfstools_invalid_time_of_day"
  )

  # B and the second visit to A arrive within the time of day (the latter at
  # 'to'). the later visits are shifted by the change at B

  new_gtfs <- tester(
    hand_gtfs,
    dwell_time = 0,
    from = "24:00:00",
    to = "24:10:00"
  )
  expected_times <- data.table::data.table(
    stop_id = c("A", "B", "C", "A", "D"),
    arrival_time = c("23:59:00", "24:05:00", "", "24:09:30", "24:19:30"),
    departure_time = c("24:00:00", "24:05:00", "", "24:09:30", "24:20:30")
  )
  expect_identical(trip_times(new_gtfs, "t"), expected_times)

  # visits are selected by their arrival times before the change: the change
  # at the first visit to A moves the arrival at B out of the time of day, but
  # its dwell time is still set

  new_gtfs <- tester(
    hand_gtfs,
    dwell_time = 120,
    from = "23:59:00",
    to = "24:05:00"
  )
  expected_times <- data.table::data.table(
    stop_id = c("A", "B", "C", "A", "D"),
    arrival_time = c("23:59:00", "24:06:00", "", "24:12:30", "24:22:30"),
    departure_time = c("24:01:00", "24:08:00", "", "24:12:30", "24:23:30")
  )
  expect_identical(trip_times(new_gtfs, "t"), expected_times)

  # a stop filter and a time of day combine: only the second visit to A,
  # which arrives after 'from', is changed

  new_gtfs <- tester(
    hand_gtfs,
    stop_id = "A",
    dwell_time = 120,
    from = "24:00:00"
  )
  expected_times <- data.table::data.table(
    stop_id = c("A", "B", "C", "A", "D"),
    arrival_time = c("23:59:00", "24:05:00", "", "24:10:00", "24:22:00"),
    departure_time = c("24:00:00", "24:05:30", "", "24:12:00", "24:23:00")
  )
  expect_identical(trip_times(new_gtfs, "t"), expected_times)

  # with 'to' alone, only the first visit to A is changed, and the rest of the
  # trip is shifted by the change

  new_gtfs <- tester(hand_gtfs, dwell_time = 0, to = "24:00:00")
  expected_times <- data.table::data.table(
    stop_id = c("A", "B", "C", "A", "D"),
    arrival_time = c("23:59:00", "24:04:00", "", "24:09:00", "24:19:00"),
    departure_time = c("23:59:00", "24:04:30", "", "24:09:00", "24:20:00")
  )
  expect_identical(trip_times(new_gtfs, "t"), expected_times)

  # a time of day without visits changes nothing, silently

  expect_silent(
    new_gtfs <- tester(hand_gtfs, from = "12:00:00", to = "13:00:00")
  )
  expect_identical(new_gtfs$stop_times, hand_gtfs$stop_times)
})

test_that("visits with a blank arrival are not selected by a time of day", {

  # without a time of day, E's blank arrival raises a warning

  expect_warning(
    tester(half_blank_gtfs, stop_id = "E"),
    class = "gtfstools_blank_dwell_time"
  )

  # with one, E is not selected at all

  expect_silent(
    new_gtfs <- tester(
      half_blank_gtfs,
      stop_id = "E",
      from = "24:20:00",
      to = "24:30:00"
    )
  )
  expect_identical(new_gtfs$stop_times, half_blank_gtfs$stop_times)
})
