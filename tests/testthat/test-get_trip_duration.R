data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   unit = "min") {
  get_trip_duration(gtfs, trip_id, unit)
}

test_that("raises errors due to incorrect input types/value", {
  expect_error(tester(unclass(gtfs)))
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
    gtfs,
    "stop_times",
    "arrival_time"
  )
  no_st_deptime_gtfs <- copy_gtfs_without_field(
    gtfs,
    "stop_times",
    "departure_time"
  )

  wrong_tripid_gtfs <- copy_gtfs_diff_field_class(
    gtfs,
    "stop_times",
    "trip_id",
    "factor"
  )
  wrong_arrtime_gtfs <- copy_gtfs_diff_field_class(
    gtfs,
    "stop_times",
    "arrival_time",
    "factor"
  )
  wrong_deptime_gtfs <- copy_gtfs_diff_field_class(
    gtfs,
    "stop_times",
    "departure_time",
    "factor"
  )

  expect_error(tester(no_stop_times_gtfs), class = "missing_required_file")
  expect_error(tester(no_st_tripid_gtfs), class = "missing_required_field")
  expect_error(tester(no_st_arrtime_gtfs), class = "missing_required_field")
  expect_error(tester(no_st_deptime_gtfs), class = "missing_required_field")
  expect_error(tester(wrong_tripid_gtfs), class = "wrong_class_field")
  expect_error(tester(wrong_arrtime_gtfs), class = "wrong_class_field")
  expect_error(tester(wrong_deptime_gtfs), class = "wrong_class_field")
})

test_that("calculates the duration of correct 'trip_id's", {
  all_trip_ids <- unique(gtfs$stop_times$trip_id)
  duration_all_trip_ids <- tester()
  expect_equal(length(all_trip_ids), nrow(duration_all_trip_ids))

  # else only the duration of (valid) trip_ids are calculated

  selected_trip_ids <- c("CPTM L07-0", "ola")
  expect_warning(
    duration_selected_trip_ids <- tester(trip_id = selected_trip_ids)
  )
  expect_equal(1, nrow(duration_selected_trip_ids))
})

test_that("raises warnings if a non_existent trip_id is given", {
  expect_warning(
    tester(trip_id = c("CPTM L07-0", "ola")),
    regexp = "'stop_times' doesn't contain the following trip_id(s): 'ola'",
    fixed = TRUE
  )
  expect_warning(tester(trip_id = "ola"))
})

test_that("outputs a data.table with adequate columns' classes", {
  durations <- tester(trip_id = "CPTM L07-0")

  expect_s3_class(durations, "data.table")
  expect_equal(class(durations$trip_id), "character")
  expect_equal(class(durations$duration), "numeric")

  # should work even if no given 'trip_id's are present in 'stop_times'

  expect_warning(durations <- tester(trip_id = "ola"))
  expect_s3_class(durations, "data.table")
  expect_equal(class(durations$trip_id), "character")
  expect_equal(class(durations$duration), "numeric")

  # and when trip_id = character(0)

  durations <- tester(trip_id = character(0))
  expect_s3_class(durations, "data.table")
  expect_equal(class(durations$trip_id), "character")
  expect_equal(class(durations$duration), "numeric")
})

test_that("calculates duration correctly", {
  durations <- tester(trip_id = "CPTM L07-0")
  expect_equal(durations$duration, 136)

  modified_st_gtfs <- gtfs
  modified_st_gtfs$stop_times <- data.table::copy(gtfs$stop_times)
  last_stop <- modified_st_gtfs$stop_times[
    trip_id == "CPTM L07-0",
    max(stop_sequence)
  ]
  modified_st_gtfs$stop_times[
    trip_id == "CPTM L07-0" & stop_sequence == last_stop,
    `:=`(arrival_time = "24:00:00", departure_time = "24:00:00")
  ]

  durations <- tester(modified_st_gtfs, "CPTM L07-0")
  expect_equal(durations$duration, 1200)
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

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(data_path)
  new_gtfs <- read_gtfs(data_path)
  expect_identical(original_gtfs, new_gtfs)

  # selecting trips doesn't add an index to the given stop_times either

  durations <- tester(gtfs = new_gtfs, trip_id = "CPTM L07-0")
  expect_identical(original_gtfs, new_gtfs)
  expect_null(data.table::indices(new_gtfs$stop_times))

  durations <- get_trip_duration(new_gtfs, from = "07:00:00")
  expect_identical(original_gtfs, new_gtfs)

  # with all trips, the given stop_times is used directly and must not get
  # (even temporary) auxiliary columns. an error in the middle of the
  # calculation would leave them behind if they were added by reference

  stop_times_before <- data.table::copy(new_gtfs$stop_times)
  tester(gtfs = new_gtfs)
  expect_identical(new_gtfs$stop_times, stop_times_before)

  n_calls <- 0
  testthat::local_mocked_bindings(
    string_to_seconds = function(x) {
      n_calls <<- n_calls + 1
      if (n_calls > 1) stop("interrupted")
      return(rep(0L, length(x)))
    }
  )
  expect_error(tester(gtfs = new_gtfs), "interrupted")
  expect_identical(names(new_gtfs$stop_times), names(stop_times_before))
})

test_that("trips without times get NA durations, with a warning", {
  blank_gtfs <- read_gtfs(data_path)
  trip_ids <- sort(unique(blank_gtfs$stop_times$trip_id))
  blank_trips <- trip_ids[c(1, 10)]
  blank_gtfs$stop_times[
    trip_id %chin% blank_trips,
    `:=`(arrival_time = "", departure_time = "")
  ]

  expected <- get_trip_duration(gtfs, unit = "s")
  expected[trip_id %chin% blank_trips, duration := NA]

  old_options <- options(datatable.optimize = Inf)
  on.exit(options(old_options), add = TRUE)

  for (optimize in c(Inf, 0L)) {
    options(datatable.optimize = optimize)

    expect_warning(
      result <- get_trip_duration(blank_gtfs, unit = "s"),
      class = "gtfstools_trips_without_times"
    )
    expect_identical(result, expected)
    expect_type(result$duration, "integer")

    expect_warning(
      result <- get_trip_duration(blank_gtfs, blank_trips, unit = "s"),
      class = "gtfstools_trips_without_times"
    )
    expect_identical(result, expected[trip_id %chin% blank_trips])
  }
  options(old_options)

  expect_warning(
    speeds <- get_trip_speed(blank_gtfs, blank_trips),
    class = "gtfstools_trips_without_times"
  )
  expect_true(all(is.na(speeds$speed)))
})

# departure time of the first stop of each trip, and of each segment, as
# written in stop_times

first_departures <- function(gtfs) {
  st <- data.table::copy(gtfs$stop_times)
  data.table::setorderv(st, c("trip_id", "stop_sequence"))
  return(st[!duplicated(st$trip_id), .(trip_id, departure_time)])
}

test_that("from and to select the trips by their first departure", {
  first <- first_departures(gtfs)
  in_window <- first$departure_time >= "07:00:00" &
    first$departure_time <= "10:59:59"
  expected <- first$trip_id[in_window]
  expect_true(length(expected) > 0 && length(expected) < nrow(first))

  result <- get_trip_duration(gtfs, from = "07:00:00", to = "10:59:59")
  expect_identical(result, tester(trip_id = sort(expected)))

  # bounds are inclusive, and either can be given alone

  dep <- first$departure_time[1]
  result <- get_trip_duration(gtfs, from = dep, to = dep)
  expect_true(first$trip_id[1] %chin% result$trip_id)
  expect_identical(
    get_trip_duration(gtfs, from = "07:00:00")$trip_id,
    sort(first$trip_id[first$departure_time >= "07:00:00"])
  )
  expect_identical(
    get_trip_duration(gtfs, to = "06:59:59")$trip_id,
    sort(first$trip_id[first$departure_time <= "06:59:59"])
  )

  empty <- get_trip_duration(gtfs, from = "99:00:00")
  expect_identical(nrow(empty), 0L)
  expect_identical(names(empty), c("trip_id", "duration"))

  expect_error(
    get_trip_duration(gtfs, from = "09:00:00", to = "08:00:00"),
    class = "gtfstools_invalid_time_of_day"
  )
  expect_error(get_trip_duration(gtfs, from = "9:00:00"))
})

test_that("from and to handle blank and late first departures", {
  late_gtfs <- read_gtfs(data_path)
  first_seq <- min(late_gtfs$stop_times[trip_id == "CPTM L07-0"]$stop_sequence)
  late_gtfs$stop_times[
    trip_id == "CPTM L07-0" & stop_sequence == first_seq,
    departure_time := "25:00:00"
  ]
  late_gtfs$stop_times[
    trip_id == "2002-10-0" & stop_sequence == 1L,
    departure_time := ""
  ]

  result <- get_trip_duration(late_gtfs, from = "24:00:00")
  expect_identical(result$trip_id, "CPTM L07-0")

  result <- get_trip_duration(late_gtfs, from = "00:00:00", to = "99:59:59")
  expect_false("2002-10-0" %chin% result$trip_id)
})

test_that("from and to keep the warnings and require stop_sequence", {
  warning_of <- function(expr) {
    tryCatch(expr, warning = function(w) conditionMessage(w))
  }
  expect_identical(
    warning_of(get_trip_duration(gtfs, "ola", from = "07:00:00")),
    warning_of(tester(trip_id = "ola"))
  )

  no_sequence_gtfs <- copy_gtfs_without_field(
    gtfs,
    "stop_times",
    "stop_sequence"
  )
  expect_error(get_trip_duration(no_sequence_gtfs, from = "07:00:00"))
  expect_no_error(tester(no_sequence_gtfs))
})

test_that("empty results have the same duration type as non-empty ones", {
  secs_gtfs <- convert_time_to_seconds(gtfs, "stop_times")

  for (unit in c("s", "min")) {
    for (feed in list(gtfs, secs_gtfs)) {
      non_empty <- get_trip_duration(feed, "CPTM L07-0", unit = unit)
      expect_true(nrow(non_empty) > 0)

      empty_window <- get_trip_duration(feed, from = "99:00:00", unit = unit)
      empty_selection <- get_trip_duration(feed, character(0), unit = unit)

      for (empty in list(empty_window, empty_selection)) {
        expect_identical(nrow(empty), 0L)
        expect_identical(names(empty), c("trip_id", "duration"))
        expect_identical(typeof(empty$duration), typeof(non_empty$duration))
      }
    }
  }
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
  expect_equal(durations$duration, 15)
  expect_equal(overnight_gtfs, original_gtfs, ignore_attr = TRUE)

  poa_gtfs <- read_gtfs(
    system.file("extdata/poa_gtfs.zip", package = "gtfstools")
  )
  expect_equal(get_trip_duration(poa_gtfs, "T2-1@1#2310")$duration, 52)

  # without stop_sequence the times can't be ordered, so they are used as
  # written

  no_sequence <- copy_gtfs_without_field(
    overnight_gtfs,
    "stop_times",
    "stop_sequence"
  )
  durations <- get_trip_duration(no_sequence)
  expect_equal(durations$duration, 1437)
})
