data_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
trip_id <- "143765658"

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   type = "spatial",
                   sort_sequence = FALSE) {
  get_stop_times_patterns(gtfs, trip_id, type, sort_sequence)
}

test_that("raises errors due to incorrect input types/value", {
  expect_error(tester(unclass(gtfs)))
  expect_error(tester(trip_id = as.factor(trip_id)))
  expect_error(tester(trip_id = NA))
  expect_error(tester(type = NA))
  expect_error(tester(type = c("spatial", "spatial")))
  expect_error(tester(type = "oie"))
  expect_error(tester(sort_sequence = "FALSE"))
  expect_error(tester(sort_sequence = NA))
  expect_error(tester(sort_sequence = c(TRUE, TRUE)))
})

test_that("raises warning if a non-existent trip_id is specified", {
  expect_warning(tester(trip_id = "a"))
  expect_warning(tester(trip_id = c("a", trip_id)))
})

test_that("raises errors if gtfs doesn't have required tables/fields", {
  no_stop_times_gtfs <- copy_gtfs_without_file(gtfs, "stop_times")

  no_st_tripid_gtfs <- copy_gtfs_without_field(gtfs, "stop_times", "trip_id")
  no_st_stopid_gtfs <- copy_gtfs_without_field(gtfs, "stop_times", "stop_id")
  no_st_arrtime_gtfs <- copy_gtfs_without_field(
    gtfs, "stop_times", "arrival_time"
  )
  no_st_deptime_gtfs <- copy_gtfs_without_field(
    gtfs, "stop_times", "departure_time"
  )

  diff_st_tripid_gtfs <- copy_gtfs_diff_field_class(
    gtfs,
    "stop_times",
    "trip_id",
    "factor"
  )
  diff_st_stopid_gtfs <- copy_gtfs_diff_field_class(
    gtfs,
    "stop_times",
    "stop_id",
    "factor"
  )
  diff_st_arrtime_gtfs <- copy_gtfs_diff_field_class(
    gtfs,
    "stop_times",
    "arrival_time",
    "factor"
  )
  diff_st_deptime_gtfs <- copy_gtfs_diff_field_class(
    gtfs,
    "stop_times",
    "departure_time",
    "factor"
  )

  # type = "spatial"
  expect_error(tester(no_stop_times_gtfs))
  expect_error(tester(no_st_tripid_gtfs))
  expect_error(tester(no_st_stopid_gtfs))
  expect_silent(tester(no_st_arrtime_gtfs, trip_id = trip_id))
  expect_silent(tester(no_st_deptime_gtfs, trip_id = trip_id))
  expect_error(tester(diff_st_tripid_gtfs))
  expect_error(tester(diff_st_stopid_gtfs))
  expect_silent(tester(diff_st_arrtime_gtfs, trip_id = trip_id))
  expect_silent(tester(diff_st_deptime_gtfs, trip_id = trip_id))

  # type = "spatiotemporal"
  expect_error(tester(no_stop_times_gtfs, type = "spatiotemporal"))
  expect_error(tester(no_st_tripid_gtfs, type = "spatiotemporal"))
  expect_error(tester(no_st_stopid_gtfs, type = "spatiotemporal"))
  expect_error(tester(no_st_arrtime_gtfs, type = "spatiotemporal"))
  expect_error(tester(no_st_deptime_gtfs, type = "spatiotemporal"))
  expect_error(tester(diff_st_tripid_gtfs, type = "spatiotemporal"))
  expect_error(tester(diff_st_stopid_gtfs, type = "spatiotemporal"))
  expect_error(tester(diff_st_arrtime_gtfs, type = "spatiotemporal"))
  expect_error(tester(diff_st_deptime_gtfs, type = "spatiotemporal"))
})

test_that("output is a data.table with right columns", {
  patterns <- tester(trip_id = trip_id)
  expect_s3_class(patterns, "data.table")
  expect_type(patterns$trip_id, "character")
  expect_type(patterns$pattern_id, "integer")

  # should also work with trip_id = character(0), when result is an empty dt

  patterns <- tester(trip_id = character(0))
  expect_s3_class(patterns, "data.table")
  expect_true(nrow(patterns) == 0)
  expect_type(patterns$trip_id, "character")
  expect_type(patterns$pattern_id, "integer")

  # also when none of the trips exist

  expect_warning(patterns <- tester(trip_id = "a"))
  expect_s3_class(patterns, "data.table")
  expect_true(nrow(patterns) == 0)
  expect_type(patterns$trip_id, "character")
  expect_type(patterns$pattern_id, "integer")
})

test_that("output includes the correct trip_ids", {
  # by default includes all trips in stop_times table
  patterns <- tester()
  expect_true(all(unique(gtfs$stop_times$trip_id) %chin% patterns$trip_id))

  # otherwise, only listed trips should be included
  patterns <- tester(trip_id = trip_id)
  expect_true(patterns$trip_id == trip_id)

  # should only include one entry for each trip_id
  patterns <- tester(trip_id = rep(trip_id, 2))
  expect_true(patterns$trip_id == trip_id)
})

test_that("identifies patterns correctly", {
  # trips 143765659 and 143765658 have the same spatial pattern, which is
  # different than 143765656 pattern

  expect_identical(
    gtfs$stop_times[trip_id == c("143765658")]$stop_id,
    gtfs$stop_times[trip_id == c("143765659")]$stop_id
  )
  same_pattern <- tester(trip_id = c("143765658", "143765659"))
  expect_equal(unique(same_pattern$pattern_id), 1)

  expect_false(
    identical(
      gtfs$stop_times[trip_id == c("143765656")]$stop_id,
      gtfs$stop_times[trip_id == c("143765659")]$stop_id
    )
  )
  diff_pattern <- tester(trip_id = c("143765656", "143765659"))
  expect_identical(diff_pattern$pattern_id, c(1L, 2L))

  # trips 143765659 and 143765658, however, have different spatiotemporal
  # patterns. 143765659 and 143765660 have the same spatiotemporal pattern

  diff_pattern_temp <- tester(
    trip_id = c("143765658", "143765659"),
    type = "spatiotemporal"
  )
  expect_identical(diff_pattern_temp$pattern_id, c(1L, 2L))

  same_pattern_temp <- tester(
    trip_id = c("143765660", "143765659"),
    type = "spatiotemporal"
  )
  expect_identical(same_pattern_temp$pattern_id, c(1L, 1L))
})

test_that("type = 'spatiotemporal' work correctly when times are NA", {
  poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
  poa_gtfs <- read_gtfs(poa_path)

  # trips T2-1@1#520 and T2-1@1#540 follow the same stops, depart from first
  # stop at the same time and arrive at last stop at the same time, so should
  # have the same spatiotemporal pattern

  poa_same_pattern <- tester(
    poa_gtfs,
    c("T2-1@1#520", "T2-1@1#540"),
    "spatiotemporal"
  )
  expect_identical(poa_same_pattern$pattern_id, c(1L, 1L))
})

test_that("doesn't change original gtfs", {
  new_gtfs <- read_gtfs(data_path)
  original_gtfs <- read_gtfs(data_path)
  patterns <- tester(new_gtfs)
  expect_identical(new_gtfs, original_gtfs)

  # should also work if type = "spatiotemporal"

  patterns <- tester(new_gtfs, type = "spatiotemporal")
  expect_identical(new_gtfs, original_gtfs)

  # should also work if sort_sequence = TRUE

  patterns <- tester(new_gtfs, sort_sequence = TRUE)
  expect_identical(new_gtfs, original_gtfs)

  # should also work if gtfs contain time-in-seconds columns

  convert_time_to_seconds(new_gtfs, file = "stop_times", by_reference = TRUE)
  convert_time_to_seconds(
    original_gtfs,
    file = "stop_times",
    by_reference = TRUE
  )
  expect_identical(new_gtfs, original_gtfs)
  patterns <- tester(new_gtfs, type = "spatiotemporal")
  expect_identical(new_gtfs, original_gtfs)
})

test_that("sort_sequence works correctly", {
  # trips 143765659 and 143765658 have the same spatial pattern
  ids <- c("143765658", "143765659")
  patterns <- tester(trip_id = ids)

  unordered_gtfs <- gtfs
  unordered_gtfs$stop_times <- gtfs$stop_times[trip_id %in% ids]
  unordered_gtfs$stop_times <- unordered_gtfs$stop_times[
    c(10:18, 1:9, 19:62)
  ]

  unordered_patterns <- tester(unordered_gtfs, ids)
  expect_false(identical(unordered_patterns, patterns))

  ordered_patterns <- tester(unordered_gtfs, ids, sort_sequence = TRUE)
  expect_identical(ordered_patterns, patterns)

  # sort_sequence defaults to TRUE (#94)
  default_patterns <- get_stop_times_patterns(unordered_gtfs, ids)
  expect_identical(default_patterns, patterns)
})

test_that("stop_ids containing separators don't make patterns collide", {
  # the sequences "a;b" -> "c" and "a" -> "b;c" used to be described by the
  # same "a;b;c" string, and were wrongly assigned the same pattern

  spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
  spo_gtfs <- read_gtfs(spo_path)
  trips <- spo_gtfs$trips$trip_id[1:2]

  first_trip <- spo_gtfs$stop_times[trip_id == trips[1]][1:2]
  second_trip <- spo_gtfs$stop_times[trip_id == trips[2]][1:2]
  first_trip[, stop_id := c("a;b", "c")]
  second_trip[, stop_id := c("a", "b;c")]
  spo_gtfs$stop_times <- rbind(first_trip, second_trip)

  spo_gtfs$stops <- spo_gtfs$stops[1:4]
  spo_gtfs$stops[, stop_id := c("a;b", "c", "a", "b;c")]

  spatial_patterns <- tester(spo_gtfs, type = "spatial")
  expect_identical(spatial_patterns$pattern_id, c(1L, 2L))

  spatiotemporal_patterns <- tester(spo_gtfs, type = "spatiotemporal")
  expect_identical(spatiotemporal_patterns$pattern_id, c(1L, 2L))
})

# builds a gtfs whose stop_times has the given trip_ids, stop_ids and
# (optionally) time-in-seconds columns. time strings are left blank, so the
# _secs columns are used as they are

build_stop_times_gtfs <- function(trip_id, stop_id, dep_secs = NULL) {
  stop_times <- data.table::data.table(
    trip_id = trip_id,
    stop_id = stop_id,
    stop_sequence = data.table::rowid(trip_id),
    arrival_time = "",
    departure_time = ""
  )
  if (!is.null(dep_secs)) {
    stop_times[, `:=`(
      departure_time_secs = dep_secs,
      arrival_time_secs = dep_secs
    )]
  }
  new_gtfs <- gtfs
  new_gtfs$stop_times <- stop_times
  return(new_gtfs)
}

test_that("handles rows of different trips interleaved", {
  contiguous <- build_stop_times_gtfs(
    c("a", "a", "a", "b", "b", "b", "c", "c"),
    c("x", "y", "z", "x", "y", "z", "x", "y")
  )
  interleaved <- contiguous
  interleaved$stop_times <- contiguous$stop_times[c(1, 4, 7, 2, 5, 8, 3, 6)]

  patterns <- tester(interleaved)
  expect_identical(patterns$trip_id, c("a", "b", "c"))
  expect_identical(patterns$pattern_id, c(1L, 1L, 2L))
  expect_identical(patterns, tester(contiguous))
})

test_that("rows with NA trip_id are grouped together", {
  na_gtfs <- build_stop_times_gtfs(
    c("a", NA, "a", "b", NA, "b"),
    c("x", "x", "y", "x", "y", "y")
  )

  for (sort_sequence in c(TRUE, FALSE)) {
    patterns <- tester(na_gtfs, sort_sequence = sort_sequence)
    expect_identical(patterns$trip_id, c(NA, "a", "b"))
    expect_identical(patterns$pattern_id, c(1L, 1L, 1L))
  }
})

test_that("sequences that start with the same stops are different patterns", {
  prefix_gtfs <- build_stop_times_gtfs(
    c("a", "a", "b", "b", "b"),
    c("x", "y", "x", "y", "z")
  )
  expect_identical(tester(prefix_gtfs)$pattern_id, c(1L, 2L))
})

test_that("spatiotemporal patterns use times relative to the first departure", {
  # a, b and c take 60 seconds between stops, regardless of when they depart.
  # d has no departures and e only has its last one

  int_gtfs <- build_stop_times_gtfs(
    rep(c("a", "b", "c", "d", "e"), each = 2),
    rep(c("x", "y"), 5),
    c(0L, 60L, 100L, 160L, 60L, 120L, NA, NA, NA, 60L)
  )
  patterns <- tester(int_gtfs, type = "spatiotemporal")
  expect_identical(patterns$pattern_id, c(1L, 1L, 1L, 2L, 3L))

  # pre-existing double _secs columns are compared as they were written, so
  # 0.4 - 0.1 and 0.3 - 0 are considered the same time

  double_gtfs <- build_stop_times_gtfs(
    rep(c("a", "b", "c"), each = 2),
    rep(c("x", "y"), 3),
    c(0.1, 0.4, 0, 0.3, 0, 0.5)
  )
  patterns <- tester(double_gtfs, type = "spatiotemporal")
  expect_identical(patterns$pattern_id, c(1L, 1L, 2L))
})

test_that("returns an empty table when no trip is analysed", {
  empty_patterns <- data.table::data.table(
    trip_id = character(0),
    pattern_id = integer(0),
    key = "trip_id"
  )

  for (type in c("spatial", "spatiotemporal")) {
    expect_warning(patterns <- tester(trip_id = "nope", type = type))
    expect_identical(patterns, empty_patterns)
  }
})

test_that("cpp_sequence_pattern_id() compares whole groups", {
  # groups 1 and 2 are equal and group 3 is a prefix of them. groups 6 and 7
  # are equal, as NAs are compared as any other value

  ids <- cpp_sequence_pattern_id(
    c(2L, 2L, 1L, 1L, 2L, 2L, 2L),
    list(c(1L, 2L, 1L, 2L, 1L, 3L, 4L, 5L, NA, 6L, NA, 6L))
  )
  expect_identical(ids, c(1L, 1L, 2L, 3L, 4L, 5L, 5L))

  expect_identical(
    cpp_sequence_pattern_id(integer(0), list(integer(0))),
    integer(0)
  )

  expect_error(cpp_sequence_pattern_id(1L, list()))
  expect_error(cpp_sequence_pattern_id(c(1L, -1L), list(1L)))
  expect_error(cpp_sequence_pattern_id(c(1L, NA), list(1L)))
  expect_error(cpp_sequence_pattern_id(2L, list(c(1, 2))))
  expect_error(cpp_sequence_pattern_id(2L, list(1L)))
})
