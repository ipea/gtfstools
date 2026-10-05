data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
trip_id <- "CPTM L07-0"

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   file = NULL,
                   unit = "km",
                   sort_sequence = FALSE) {
  get_trip_length(gtfs, trip_id, file, unit, sort_sequence)
}

test_that("raises errors due to incorrect input types/value", {
  expect_error(tester(unclass(gtfs)))
  expect_error(tester(trip_id = as.factor("CPTM L07-0")))
  expect_error(tester(trip_id = NA))
  expect_error(tester(file = c("shapes", "stops")))
  expect_error(tester(unit = "s"))
  expect_error(tester(unit = c("km", "m")))
  expect_error(tester(sort_sequence = "FALSE"))
  expect_error(tester(sort_sequence = NA))
  expect_error(tester(sort_sequence = c(TRUE, TRUE)))
})

test_that("raises errors if gtfs doesn't have required files/fields", {
  no_trips_gtfs <- copy_gtfs_without_file(gtfs, "trips")
  no_shapes_gtfs <- copy_gtfs_without_file(gtfs, "shapes")
  no_stop_times_gtfs <- copy_gtfs_without_file(gtfs, "stop_times")
  no_stops_gtfs <- copy_gtfs_without_file(gtfs, "stops")
  no_shapes_and_stop_times_gtfs <- copy_gtfs_without_file(
    no_shapes_gtfs,
    "stop_times"
  )

  no_trp_tripid_gtfs <- copy_gtfs_without_field(gtfs, "trips", "trip_id")
  no_trp_shapeid_gtfs <- copy_gtfs_without_field(gtfs, "trips", "shape_id")

  no_shp_shapeid_gtfs <- copy_gtfs_without_field(gtfs, "shapes", "shape_id")
  no_shp_shapelat_gtfs <- copy_gtfs_without_field(
    gtfs, "shapes", "shape_pt_lat"
  )
  no_shp_shapelon_gtfs <- copy_gtfs_without_field(
    gtfs, "shapes", "shape_pt_lon"
  )
  no_shp_shapeseq_gtfs <- copy_gtfs_without_field(
    gtfs, "shapes", "shape_pt_sequence"
  )

  no_stt_tripid_gtfs <- copy_gtfs_without_field(gtfs, "stop_times", "trip_id")
  no_stt_stopid_gtfs <- copy_gtfs_without_field(gtfs, "stop_times", "stop_id")
  no_stt_stopseq_gtfs <- copy_gtfs_without_field(
    gtfs,
    "stop_times",
    "stop_sequence"
  )

  no_sts_stopid_gtfs <- copy_gtfs_without_field(gtfs, "stops", "stop_id")
  no_sts_stoplat_gtfs <- copy_gtfs_without_field(gtfs, "stops", "stop_lat")
  no_sts_stoplon_gtfs <- copy_gtfs_without_field(gtfs, "stops", "stop_lon")

  # shapes-based lengths

  expect_error(
    tester(no_trips_gtfs, trip_id, "shapes"),
    class = "missing_required_file"
  )
  expect_error(
    tester(no_shapes_gtfs, trip_id, "shapes"),
    class = "missing_required_file"
  )
  expect_error(
    tester(no_trp_tripid_gtfs, trip_id, "shapes"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_trp_shapeid_gtfs, trip_id, "shapes"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_shp_shapeid_gtfs, trip_id, "shapes"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_shp_shapelat_gtfs, trip_id, "shapes"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_shp_shapelon_gtfs, trip_id, "shapes"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_shp_shapeseq_gtfs, trip_id, "shapes", sort_sequence = TRUE),
    class = "missing_required_field"
  )
  expect_s3_class(tester(no_stop_times_gtfs, trip_id, "shapes"), "data.table")
  expect_s3_class(tester(no_stops_gtfs, trip_id, "shapes"), "data.table")

  # stop_times-based lengths

  expect_error(
    tester(no_trips_gtfs, trip_id, "stop_times"),
    class = "missing_required_file"
  )
  expect_error(
    tester(no_stop_times_gtfs, trip_id, "stop_times"),
    class = "missing_required_file"
  )
  expect_error(
    tester(no_stops_gtfs, trip_id, "stop_times"),
    class = "missing_required_file"
  )
  expect_error(
    tester(no_trp_tripid_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_stt_tripid_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_stt_stopid_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_stt_stopseq_gtfs, trip_id, "stop_times", sort_sequence = TRUE),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_sts_stopid_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_sts_stoplat_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_sts_stoplon_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_s3_class(tester(no_shapes_gtfs, trip_id, "stop_times"), "data.table")
  expect_s3_class(
    tester(no_trp_shapeid_gtfs, trip_id, "stop_times"),
    "data.table"
  )

  # when file = NULL, the gtfs must have either a shapes or a stop_times table

  expect_error(tester(no_shapes_and_stop_times_gtfs, trip_id))
})

test_that("returns the lengths of correct trip_ids", {
  # if 'trip_id' = NULL, all trips have their geometries returned

  all_trip_ids <- unique(gtfs$trips$trip_id)
  all_trip_ids <- all_trip_ids[order(all_trip_ids)]

  length_all_trip_ids <- tester()
  trip_ids_from_length <- unique(length_all_trip_ids$trip_id)
  trip_ids_from_length <- trip_ids_from_length[order(trip_ids_from_length)]

  expect_identical(all_trip_ids, trip_ids_from_length)

  # else, only the duration of (valid) trip_ids are calculated

  selected_trip_ids <- c("CPTM L07-0", "ola")
  suppressWarnings(
    length_selected_trip_ids <- tester(trip_id = selected_trip_ids)
  )
  expect_equal(unique(length_selected_trip_ids$trip_id), "CPTM L07-0")
})

test_that("raises warnings if a non_existent 'trip_id' is given", {
  expect_warning(tester(trip_id = c("CPTM L07-0", "ola")))
})

test_that("returns the lengths created by the given 'file'", {
  shape_length <- tester(trip_id = "CPTM L07-0", file = "shapes")
  stop_times_length <- tester(trip_id = "CPTM L07-0", file = "stop_times")
  both_length <- tester(trip_id = "CPTM L07-0")

  expect_equal(unique(shape_length$origin_file), "shapes")
  expect_equal(unique(stop_times_length$origin_file), "stop_times")
  expect_identical(unique(both_length$origin_file), c("shapes", "stop_times"))
})

test_that("outputs a data.table with correct column types", {
  lengths <- tester(trip_id = trip_id)
  expect_s3_class(lengths, "data.table")
  expect_type(lengths$trip_id, "character")
  expect_type(lengths$length, "double")
  expect_type(lengths$origin_file, "character")

  # should work even when none of the trip_ids privded exist in the gtfs

  expect_warning(lengths <- tester(trip_id = "oi"))
  expect_true(nrow(lengths) == 0)
  expect_s3_class(lengths, "data.table")
  expect_type(lengths$trip_id, "character")
  expect_type(lengths$length, "double")
  expect_type(lengths$origin_file, "character")

  # and when trip_id = character(0)

  lengths <- tester(trip_id = character(0))
  expect_true(nrow(lengths) == 0)
  expect_s3_class(lengths, "data.table")
  expect_type(lengths$trip_id, "character")
  expect_type(lengths$length, "double")
  expect_type(lengths$origin_file, "character")
})

test_that("unit argument affects the results correctly", {
  lengths_km <- tester(trip_id = trip_id)$length
  lengths_m <- tester(trip_id = trip_id, unit = "m")$length

  tol <- .Machine$double.eps^0.5
  expect_true(all(abs(lengths_km * 1000 - lengths_m) < tol))
})

test_that("doesn't change given gtfs", {
  # (except for 'stop_times' and 'shapes' indices)

  original_gtfs <- read_gtfs(data_path)
  gtfs <- read_gtfs(data_path)
  expect_identical(original_gtfs, gtfs)

  lengths <- tester(trip_id = "CPTM L07-0")
  expect_false(identical(original_gtfs, gtfs))

  data.table::setindex(gtfs$shapes, NULL)
  data.table::setindex(gtfs$stop_times, NULL)
  expect_identical(original_gtfs, gtfs)

  # should also work when sorting shapes/timetables
  lengths <- tester(sort_sequence = TRUE)
  data.table::setindex(gtfs$shapes, NULL)
  data.table::setindex(gtfs$stop_times, NULL)
  expect_identical(original_gtfs, gtfs)
})

test_that("sort_sequence works correctly", {
  lengths <- tester(trip_id = trip_id)

  unordered_gtfs <- gtfs
  unordered_gtfs$shapes <- gtfs$shapes[shape_id == "17846"]
  unordered_gtfs$shapes <- unordered_gtfs$shapes[c(200:547, 1:199)]
  unordered_gtfs$stop_times <- gtfs$stop_times[trip_id == "CPTM L07-0"]
  unordered_gtfs$stop_times <- unordered_gtfs$stop_times[c(10:18, 1:9)]

  unordered_lengths <- tester(unordered_gtfs, trip_id)
  expect_false(identical(unordered_lengths, lengths))

  ordered_lengths <- tester(unordered_gtfs, trip_id, sort_sequence = TRUE)
  expect_identical(ordered_lengths, lengths)

  # sort_sequence defaults to TRUE (#94)
  default_lengths <- get_trip_length(unordered_gtfs, trip_id, unit = "km")
  expect_identical(default_lengths, lengths)
})
