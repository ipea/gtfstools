data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

test_that("raises errors due to incorrect input types/value", {
  no_class_gtfs <- gtfs
  attr(no_class_gtfs, "class") <- NULL
  expect_error(set_trip_speed(no_class_gtfs, "CPTM L07-0", 50))
  expect_error(set_trip_speed(gtfs, as.factor("CPTM L07-0"), 50))
  expect_error(set_trip_speed(gtfs, NA, 50))
  expect_error(set_trip_speed(gtfs, "CPTM L07-0", "50"))
  expect_error(
    set_trip_speed(gtfs, c("CPTM L07-0", "6450-51-0", "2105-10-0"), c(50, 60))
  )
  expect_error(
    set_trip_speed(gtfs, c("CPTM L07-0", "6450-51-0"), c(50, NA))
  )
  expect_error(set_trip_speed(gtfs, "CPTM L07-0", 50, unit = "kms/h"))
  expect_error(set_trip_speed(gtfs, "CPTM L07-0", 50, by_reference = "TRUE"))
  expect_error(set_trip_speed(gtfs, "CPTM L07-0", 50, by_reference = NA))
  expect_error(
    set_trip_speed(gtfs, "CPTM L07-0", 50, by_reference = c(TRUE, TRUE))
  )
})

test_that("raises errors if gtfs doesn't have required files/fields", {

  # create gtfs without 'stop_times'

  no_stop_times_gtfs <- copy_gtfs_without_file(gtfs, "stop_times")

  # create gtfs without relevant fields

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

  expect_error(set_trip_speed(no_stop_times_gtfs, "CPTM L07-0", 50))
  expect_error(set_trip_speed(no_st_tripid_gtfs, "CPTM L07-0", 50))
  expect_error(set_trip_speed(no_st_arrtime_gtfs, "CPTM L07-0", 50))
  expect_error(set_trip_speed(no_st_deptime_gtfs, "CPTM L07-0", 50))
  expect_error(set_trip_speed(no_st_stopseq_gtfs, "CPTM L07-0", 50))

})

test_that("raises warnings if a non_existent trip_id is given", {
  expect_warning(set_trip_speed(gtfs, c("CPTM L07-0", "ola"), 50))
  expect_warning(set_trip_speed(gtfs, "ola", 50))
})

test_that("sets the speed of correct 'trip_id's", {

  selected_trip_ids <- c("ola", "2105-10-0", "CPTM L07-0")
  expect_warning(
    new_speeds_gtfs <- set_trip_speed(gtfs, selected_trip_ids, 50)
  )

  old_gtfs_stop_times   <- gtfs$stop_times
  new_speeds_stop_times <- new_speeds_gtfs$stop_times

  # 'stop_times' entries not related to given 'trip_id's should be identical

  expect_identical(
    old_gtfs_stop_times[! trip_id %chin% selected_trip_ids],
    new_speeds_stop_times[! trip_id %chin% selected_trip_ids]
  )

  # but given 'trip_id's entries' should be different

  expect_false(identical(
    old_gtfs_stop_times[trip_id %chin% selected_trip_ids],
    new_speeds_stop_times[trip_id %chin% selected_trip_ids]
  ))

  # if no valid 'trip_id' is given, then all entries should be identical

  expect_warning(new_speeds_gtfs <- set_trip_speed(gtfs, "ola", 50))

  old_gtfs_stop_times   <- gtfs$stop_times
  new_speeds_stop_times <- new_speeds_gtfs$stop_times

  expect_identical(old_gtfs_stop_times, new_speeds_stop_times)

})

test_that("calculates speeds correctly", {

  selected_trip_ids <- c("CPTM L07-0", "6450-51-0", "2105-10-0")

  new_speeds_gtfs <- set_trip_speed(gtfs, selected_trip_ids, 50)

  trips_speeds <- get_trip_speed(new_speeds_gtfs, selected_trip_ids, "shapes")

  # all speeds should be around 50 km/h (there is some rounding error)

  expect_identical(round(trips_speeds$speed, 0), rep(50, 3))

  # it should also work with distinct unit (m/s)

  new_speeds_gtfs <- set_trip_speed(gtfs, selected_trip_ids, 50, unit = "m/s")

  trips_speeds <- get_trip_speed(
    new_speeds_gtfs,
    selected_trip_ids,
    method = "shapes",
    unit = "m/s"
  )

  expect_identical(round(trips_speeds$speed, 0), rep(50, 3))

  # it should also work if distinct speeds are given

  new_speeds_gtfs <- set_trip_speed(gtfs, selected_trip_ids, c(50, 60, 70))

  trips_speeds <- get_trip_speed(new_speeds_gtfs, selected_trip_ids, "shapes")

  expect_identical(
    round(trips_speeds[match(trip_id, selected_trip_ids)]$speed, 0),
    c(50, 60, 70)
  )

  # and should also work if distinct speeds are given with distinct unit (m/s)

  new_speeds_gtfs <- set_trip_speed(
    gtfs,
    selected_trip_ids,
    speed = c(50, 60, 70),
    unit = "m/s"
  )

  trips_speeds <- get_trip_speed(
    new_speeds_gtfs,
    selected_trip_ids,
    method = "shapes",
    unit = "m/s"
  )

  expect_identical(
    round(trips_speeds[match(trip_id, selected_trip_ids)]$speed, 0),
    c(50, 60, 70)
  )

})

test_that("sets arrival_time and departure_time adequately", {

  # modify base gtfs to make sure set_trip_speed sets 'arrival_time' and
  # 'departure_time' as the same value

  modified_gtfs <- gtfs
  modified_gtfs$stop_times <- data.table::copy(gtfs$stop_times)
  modified_gtfs$stop_times[1,  arrival_time := "04:00:01"]
  modified_gtfs$stop_times[18, arrival_time := "06:16:01"]

  new_speed_gtfs      <- set_trip_speed(modified_gtfs, "CPTM L07-0", 50)
  filtered_stop_times <- new_speed_gtfs$stop_times[trip_id == "CPTM L07-0"]
  first_last_stops    <- filtered_stop_times[stop_sequence %in% c(1, 18)]
  intermediate_stops  <- filtered_stop_times[! stop_sequence %in% c(1, 18)]

  # check if first/last stops' arr. and dep. time are the same and not ""

  expect_identical(
    first_last_stops$arrival_time,
    first_last_stops$departure_time
  )
  expect_equal(sum(first_last_stops$arrival_time == ""), 0)
  expect_equal(sum(first_last_stops$departure_time == ""), 0)

  # check if intermediate stops' arrival and departure time are all ""

  expect_equal(sum(intermediate_stops$arrival_time == ""), 16)
  expect_equal(sum(intermediate_stops$departure_time == ""), 16)

})

test_that("outputs a dt_gtfs object", {

  # by_reference = FALSE

  expect_s3_class(set_trip_speed(gtfs, "CPTM L07-0", 50), "dt_gtfs")
  expect_warning(still_gtfs <- set_trip_speed(gtfs, "ola", 50))
  expect_s3_class(still_gtfs, "dt_gtfs")

  # by_reference = TRUE

  expect_s3_class(
    set_trip_speed(gtfs, "CPTM L07-0", 50, by_reference = TRUE),
    "dt_gtfs"
  )
  expect_s3_class(gtfs, "dt_gtfs")

})

test_that("'by_reference' parameter works adequately", {

  original_gtfs <- read_gtfs(data_path)
  gtfs <- read_gtfs(data_path)
  expect_identical(original_gtfs, gtfs)

  # if by_reference = FALSE then the given gtfs should not be changed

  new_speed_gtfs <- set_trip_speed(gtfs, "CPTM L07-0", 50)
  expect_identical(original_gtfs, gtfs)

  # if by_reference == TRUE then the given gtfs' 'stop_times' is altered

  set_trip_speed(gtfs, "CPTM L07-0", 50, by_reference = TRUE)
  expect_false(identical(original_gtfs, gtfs))

  data.table::setindex(gtfs$trips, NULL)
  data.table::setindex(gtfs$shapes, NULL)

  expect_false(identical(original_gtfs, gtfs))

  data.table::setindex(gtfs$stop_times, NULL)

  expect_false(identical(original_gtfs, gtfs))

  # the difference is exactly the trips whose speeds have been set

  expect_identical(
    gtfs$stop_times[trip_id != "CPTM L07-0"],
    original_gtfs$stop_times[trip_id != "CPTM L07-0"]
  )

  expect_false(identical(
    gtfs$stop_times[trip_id == "CPTM L07-0"],
    original_gtfs$stop_times[trip_id == "CPTM L07-0"]
  ))

})

# issue #37
test_that("results in identical gtfs if none of the specified trip_ids exist", {
  # with the exception of stop_times index
  gtfs <- read_gtfs(data_path)

  # when receives non-existent trip_id raises a warning
  expect_warning(same_speeds_gtfs <- set_trip_speed(gtfs, "a", 1))
  expect_false(identical(gtfs, same_speeds_gtfs))
  data.table::setindex(same_speeds_gtfs$stop_times, NULL)
  expect_identical(gtfs, same_speeds_gtfs)

  # when receives character(0) remain silent
  expect_silent(same_speeds_gtfs <- set_trip_speed(gtfs, character(0), 1))
  expect_equal(gtfs, same_speeds_gtfs, ignore_attr = TRUE)

  # also when speed = numeric(0), even if it requires a unit conversion
  # (issue #84)
  expect_silent(
    same_speeds_gtfs <- set_trip_speed(
      gtfs,
      character(0),
      numeric(0),
      unit = "m/s"
    )
  )
  expect_equal(gtfs, same_speeds_gtfs, ignore_attr = TRUE)
})

# issue #63
test_that("sets correct speed when max(stop_sequence) != number of stops", {
  edited_gtfs <- gtfs
  edited_gtfs$stop_times <- data.table::copy(gtfs$stop_times)

  edited_gtfs$stop_times[
    trip_id == "CPTM L07-0" & stop_sequence == 18,
    stop_sequence := 19
  ]

  correct_speed_gtfs <- set_trip_speed(
    edited_gtfs,
    "CPTM L07-0",
    speed = 20
  )
  speed <- get_trip_speed(correct_speed_gtfs, "CPTM L07-0")

  expect_identical(round(speed$speed), 20)
})

# issue #63 ("part two")
test_that("sets correct speed independent of id order in trips & stop_times", {
  trip_ids <- c("CPTM L07-0", "5290-10-1")
  smaller_gtfs <- filter_by_trip_id(gtfs, trip_ids)
  smaller_gtfs$trips <- rbind(smaller_gtfs$trips[2], smaller_gtfs$trips[1])

  new_speed <- set_trip_speed(smaller_gtfs, trip_ids, 20)

  speeds <- get_trip_speed(new_speed)
  expect_true(all(round(speeds$speed) == 20))
})

test_that("leaves trips without a usable shape unchanged", {
  shapeless_gtfs <- read_gtfs(data_path)
  shapeless_gtfs$trips <- data.table::copy(shapeless_gtfs$trips)
  shapeless_gtfs$trips[trip_id == "CPTM L07-0", shape_id := ""]
  shapeless_gtfs$trips[trip_id == "CPTM L07-1", shape_id := "nonexistent"]

  trip_ids <- c("CPTM L07-0", "CPTM L07-1", "CPTM L08-0")
  expect_warning(
    new_speed_gtfs <- set_trip_speed(shapeless_gtfs, trip_ids, 50),
    class = "gtfstools_trips_without_shape"
  )

  unchanged <- c("CPTM L07-0", "CPTM L07-1")
  expect_identical(
    new_speed_gtfs$stop_times[trip_id %chin% unchanged],
    shapeless_gtfs$stop_times[trip_id %chin% unchanged]
  )

  speed <- get_trip_speed(new_speed_gtfs, "CPTM L08-0")
  expect_identical(round(speed$speed), 50)
})

test_that("uses straight-line lengths when there are no shapes", {
  no_shapes_gtfs <- copy_gtfs_without_file(gtfs, "shapes")

  expect_warning(
    new_speed_gtfs <- set_trip_speed(no_shapes_gtfs, "CPTM L07-0", 50),
    class = "gtfstools_shapes_unavailable"
  )
  speed <- get_trip_speed(new_speed_gtfs, "CPTM L07-0", method = "euclidean")
  expect_identical(round(speed$speed), 50)
})

# issue #89
test_that("raises errors due to incorrect segment and time of day args", {
  gtfs <- read_gtfs(data_path)

  expect_error(
    set_trip_speed(gtfs, "CPTM L07-0", 50, first_stop = ""),
    "'first_stop'"
  )
  expect_error(
    set_trip_speed(gtfs, "CPTM L07-0", 50, first_stop = c("a", "b")),
    "'first_stop'"
  )
  expect_error(
    set_trip_speed(gtfs, "CPTM L07-0", 50, last_stop = 18922),
    "'last_stop'"
  )
  expect_error(
    set_trip_speed(gtfs, "CPTM L07-0", 50, from = "7:00:00"),
    "'from'"
  )
  expect_error(
    set_trip_speed(gtfs, "CPTM L07-0", 50, to = "07:60:00"),
    "'to'"
  )
  expect_error(
    set_trip_speed(gtfs, "CPTM L07-0", 50, from = "09:00:00", to = "08:00:00"),
    class = "gtfstools_invalid_time_of_day"
  )
})

test_that("sets the speed of a segment and shifts the following stops", {
  gtfs <- read_gtfs(data_path)

  new_speed_gtfs <- set_trip_speed(
    gtfs,
    "CPTM L07-0",
    30,
    first_stop = "18917",
    last_stop = "18922"
  )

  old_st <- gtfs$stop_times[trip_id == "CPTM L07-0"]
  new_st <- new_speed_gtfs$stop_times[trip_id == "CPTM L07-0"]

  # stops 18917 and 18922 have stop_sequence 4 and 8. stops before the segment,
  # including the departure at its first stop, are unchanged

  expect_identical(new_st[stop_sequence <= 3], old_st[stop_sequence <= 3])
  expect_identical(new_st[4]$arrival_time, old_st[4]$arrival_time)
  expect_identical(new_st[4]$departure_time, old_st[4]$departure_time)

  # stops inside the segment are blank

  expect_true(all(new_st[stop_sequence %in% 5:7]$arrival_time == ""))
  expect_true(all(new_st[stop_sequence %in% 5:7]$departure_time == ""))

  # the segment has the given speed

  segment_length <- get_trip_length(gtfs, "CPTM L07-0", by = "segment")
  segment_length <- sum(segment_length[segment %in% 4:7]$length)
  segment_duration <- string_to_seconds(new_st[8]$arrival_time) -
    string_to_seconds(new_st[4]$departure_time)
  expect_identical(round(segment_length / segment_duration * 3600), 30)

  # the following stops are shifted by a constant

  shift <- c(
    string_to_seconds(new_st[stop_sequence >= 8]$arrival_time) -
      string_to_seconds(old_st[stop_sequence >= 8]$arrival_time),
    string_to_seconds(new_st[stop_sequence >= 8]$departure_time) -
      string_to_seconds(old_st[stop_sequence >= 8]$departure_time)
  )
  expect_length(unique(shift), 1)
  expect_false(shift[1] == 0)

  # other trips are unchanged

  expect_identical(
    new_speed_gtfs$stop_times[trip_id != "CPTM L07-0"],
    gtfs$stop_times[trip_id != "CPTM L07-0"]
  )
})

test_that("keeps dwell times and blank times after the segment", {
  gtfs <- read_gtfs(data_path)

  edited_gtfs <- gtfs
  edited_gtfs$stop_times <- data.table::copy(gtfs$stop_times)
  edited_gtfs$stop_times[
    trip_id == "CPTM L07-0" & stop_sequence == 4,
    departure_time := "04:25:00"
  ]
  edited_gtfs$stop_times[
    trip_id == "CPTM L07-0" & stop_sequence == 8,
    departure_time := "04:57:00"
  ]
  edited_gtfs$stop_times[
    trip_id == "CPTM L07-0" & stop_sequence == 12,
    `:=`(arrival_time = "", departure_time = "")
  ]

  new_speed_gtfs <- set_trip_speed(
    edited_gtfs,
    "CPTM L07-0",
    30,
    first_stop = "18917",
    last_stop = "18922"
  )
  new_st <- new_speed_gtfs$stop_times[trip_id == "CPTM L07-0"]

  expect_identical(new_st[4]$arrival_time, "04:24:00")
  expect_identical(new_st[4]$departure_time, "04:25:00")

  dwell <- string_to_seconds(new_st[8]$departure_time) -
    string_to_seconds(new_st[8]$arrival_time)
  expect_identical(dwell, 60L)

  expect_identical(new_st[12]$arrival_time, "")
  expect_identical(new_st[12]$departure_time, "")
})

test_that("leaves trips without the segment unchanged, with a warning", {
  gtfs <- read_gtfs(data_path)

  expect_warning(
    new_speed_gtfs <- set_trip_speed(
      gtfs,
      c("CPTM L07-0", "CPTM L07-1"),
      30,
      first_stop = "18922",
      last_stop = "18917"
    ),
    class = "gtfstools_trips_without_segment"
  )

  # in CPTM L07-0 18917 comes before 18922. in CPTM L07-1 it's the opposite

  expect_identical(
    new_speed_gtfs$stop_times[trip_id == "CPTM L07-0"],
    gtfs$stop_times[trip_id == "CPTM L07-0"]
  )
  expect_false(identical(
    new_speed_gtfs$stop_times[trip_id == "CPTM L07-1"],
    gtfs$stop_times[trip_id == "CPTM L07-1"]
  ))

  expect_warning(
    set_trip_speed(gtfs, "CPTM L07-0", 30, first_stop = "ola"),
    class = "gtfstools_trips_without_segment"
  )

  # the last stop can't be a segment's first stop if last_stop is NULL

  expect_warning(
    set_trip_speed(gtfs, "CPTM L07-0", 30, first_stop = "18975"),
    class = "gtfstools_trips_without_segment"
  )
})

test_that("matches last_stop at its next visit after first_stop", {
  gtfs <- read_gtfs(data_path)

  loop_gtfs <- gtfs
  loop_gtfs$stop_times <- data.table::copy(gtfs$stop_times)
  loop_gtfs$stop_times[
    trip_id == "CPTM L07-0" & stop_sequence == 10,
    stop_id := "18917"
  ]

  new_speed_gtfs <- set_trip_speed(
    loop_gtfs,
    "CPTM L07-0",
    30,
    first_stop = "18917",
    last_stop = "18917"
  )
  new_st <- new_speed_gtfs$stop_times[trip_id == "CPTM L07-0"]

  expect_true(all(new_st[stop_sequence %in% 5:9]$arrival_time == ""))
  expect_false(new_st[10]$arrival_time == "")
  expect_false(new_st[11]$arrival_time == "")
})

test_that("only changes trips that depart within from and to", {
  gtfs <- read_gtfs(data_path)

  trip_ids <- unique(gtfs$stop_times$trip_id)
  first_departure <- gtfs$stop_times[
    stop_sequence == 1,
    .(trip_id, departure_time)
  ]

  changed_trips <- function(new_gtfs) {
    is_changed <- vapply(
      trip_ids,
      function(id) {
        !identical(
          gtfs$stop_times[trip_id == id],
          new_gtfs$stop_times[trip_id == id]
        )
      },
      logical(1)
    )
    sort(trip_ids[is_changed])
  }

  # both bounds are inclusive. some trips depart at exactly 07:00 and 09:00

  new_speed_gtfs <- set_trip_speed(
    gtfs,
    trip_ids,
    30,
    from = "07:00:00",
    to = "09:00:00"
  )
  expect_identical(
    changed_trips(new_speed_gtfs),
    sort(
      first_departure[
        departure_time >= "07:00:00" & departure_time <= "09:00:00"
      ]$trip_id
    )
  )

  # from and to can be used alone

  new_speed_gtfs <- set_trip_speed(gtfs, trip_ids, 30, from = "10:00:00")
  expect_identical(
    changed_trips(new_speed_gtfs),
    sort(first_departure[departure_time >= "10:00:00"]$trip_id)
  )

  new_speed_gtfs <- set_trip_speed(gtfs, trip_ids, 30, to = "00:59:59")
  expect_identical(
    changed_trips(new_speed_gtfs),
    sort(first_departure[departure_time <= "00:59:59"]$trip_id)
  )
})

test_that("sets the arrival of single-stop trips to their departure", {
  gtfs <- read_gtfs(data_path)

  single_stop_gtfs <- gtfs
  single_stop_gtfs$stop_times <- data.table::copy(gtfs$stop_times)
  single_stop_gtfs$stop_times <- single_stop_gtfs$stop_times[
    trip_id != "CPTM L07-0" | stop_sequence == 1
  ]
  single_stop_gtfs$stop_times[
    trip_id == "CPTM L07-0",
    arrival_time := "03:59:00"
  ]

  new_speed_gtfs <- set_trip_speed(single_stop_gtfs, "CPTM L07-0", 30)
  new_st <- new_speed_gtfs$stop_times[trip_id == "CPTM L07-0"]

  expect_identical(new_st$arrival_time, "04:00:00")
  expect_identical(new_st$departure_time, "04:00:00")
})

test_that("segment and time of day args work by reference and on other feeds", {
  gtfs <- read_gtfs(data_path)
  secs_gtfs <- convert_time_to_seconds(gtfs, "stop_times")
  secs_st <- data.table::copy(secs_gtfs$stop_times)

  # the given gtfs is unchanged, and *_secs columns are refreshed

  new_speed_gtfs <- set_trip_speed(
    secs_gtfs,
    "CPTM L07-0",
    30,
    first_stop = "18917",
    last_stop = "18922"
  )
  expect_identical(secs_gtfs$stop_times, secs_st)
  new_st <- new_speed_gtfs$stop_times
  expect_identical(
    new_st$arrival_time_secs,
    string_to_seconds(new_st$arrival_time)
  )
  expect_identical(
    new_st$departure_time_secs,
    string_to_seconds(new_st$departure_time)
  )

  # by reference gives the same times

  set_trip_speed(
    gtfs,
    "CPTM L07-0",
    30,
    first_stop = "18917",
    last_stop = "18922",
    by_reference = TRUE
  )
  expect_identical(
    gtfs$stop_times[, .(arrival_time, departure_time)],
    new_st[, .(arrival_time, departure_time)]
  )

  # time of day on a feed without frequencies: only the trips departing in
  # the window are changed, and trips outside it don't raise warnings

  poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
  poa_gtfs <- read_gtfs(poa_path)
  trip_ids <- unique(poa_gtfs$stop_times$trip_id)
  first_departure <- poa_gtfs$stop_times[
    poa_gtfs$stop_times[, .I[which.min(stop_sequence)], by = trip_id]$V1
  ]
  in_window <- first_departure[
    departure_time >= "07:00:00" & departure_time <= "09:00:00"
  ]$trip_id

  expect_silent(
    new_poa <- set_trip_speed(
      poa_gtfs,
      trip_ids,
      25,
      from = "07:00:00",
      to = "09:00:00"
    )
  )
  expect_identical(
    new_poa$stop_times[!trip_id %chin% in_window],
    poa_gtfs$stop_times[!trip_id %chin% in_window]
  )
  expect_false(identical(
    new_poa$stop_times[trip_id %chin% in_window],
    poa_gtfs$stop_times[trip_id %chin% in_window]
  ))
})
