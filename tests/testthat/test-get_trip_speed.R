data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
trip_id <- "CPTM L07-0"

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   file = "shapes",
                   unit = "km/h",
                   sort_sequence = FALSE) {
  get_trip_speed(gtfs, trip_id, file, unit, sort_sequence)
}

test_that("raises errors due to incorrect input types/value", {
  expect_error(tester(unclass(gtfs)))
  expect_error(tester(trip_id = as.factor("CPTM L07-0")))
  expect_error(tester(trip_id = NA))
  expect_error(tester(file = c("shape", "stop_times")))
  expect_error(tester(unit = "km/s"))
  expect_error(tester(sort_sequence = "FALSE"))
  expect_error(tester(sort_sequence = NA))
  expect_error(tester(sort_sequence = c(TRUE, TRUE)))
})

test_that("raises errors if gtfs doesn't have required files/fields", {
  no_trips_gtfs <- copy_gtfs_without_file(gtfs, "trips")
  no_shapes_gtfs <- copy_gtfs_without_file(gtfs, "shapes")
  no_stops_gtfs <- copy_gtfs_without_file(gtfs, "stops")
  no_stop_times_gtfs <- copy_gtfs_without_file(gtfs, "stop_times")

  no_trp_tripid_gtfs <- copy_gtfs_without_field(gtfs, "trips", "trip_id")
  no_trp_shapeid_gtfs <- copy_gtfs_without_field(gtfs, "trips", "shape_id")

  no_shp_shapeid_gtfs <- copy_gtfs_without_field(gtfs, "shapes", "shape_id")
  no_shp_shapeptlat_gtfs <- copy_gtfs_without_field(
    gtfs, "shapes", "shape_pt_lat"
  )
  no_shp_shapeptlon_gtfs <- copy_gtfs_without_field(
    gtfs, "shapes", "shape_pt_lon"
  )
  no_shp_shapeseq_gtfs <- copy_gtfs_without_field(
    gtfs, "shapes", "shape_pt_sequence"
  )

  no_stt_tripid_gtfs <- copy_gtfs_without_field(gtfs, "stop_times", "trip_id")
  no_stt_stopid_gtfs <- copy_gtfs_without_field(gtfs, "stop_times", "stop_id")
  no_stt_arrtime_gtfs <- copy_gtfs_without_field(
    gtfs, "stop_times", "arrival_time"
  )
  no_stt_deptime_gtfs <- copy_gtfs_without_field(
    gtfs, "stop_times", "departure_time"
  )
  no_stt_stopseq_gtfs <- copy_gtfs_without_field(
    gtfs,
    "stop_times",
    "stop_sequence"
  )

  no_sto_stopid_gtfs <- copy_gtfs_without_field(gtfs, "stops", "stop_id")
  no_sto_stoplat_gtfs <- copy_gtfs_without_field(gtfs, "stops", "stop_lat")
  no_sto_stoplon_gtfs <- copy_gtfs_without_field(gtfs, "stops", "stop_lon")

  # file = "shapes"

  expect_error(tester(no_trips_gtfs, trip_id), class = "missing_required_file")
  expect_error(tester(no_shapes_gtfs, trip_id), class = "missing_required_file")
  expect_error(
    tester(no_stop_times_gtfs, trip_id),
    class = "missing_required_file"
  )
  expect_error(
    tester(no_trp_tripid_gtfs, trip_id),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_trp_shapeid_gtfs, trip_id),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_shp_shapeid_gtfs, trip_id),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_shp_shapeptlat_gtfs, trip_id),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_shp_shapeptlon_gtfs, trip_id),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_stt_tripid_gtfs, trip_id),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_stt_arrtime_gtfs, trip_id),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_stt_deptime_gtfs, trip_id),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_shp_shapeseq_gtfs, trip_id, sort_sequence = TRUE),
    class = "missing_required_field"
  )

  # file = "stop_times"

  expect_error(
    tester(no_stops_gtfs, trip_id, "stop_times"),
    class = "missing_required_file"
  )
  expect_error(
    tester(no_stop_times_gtfs, trip_id, "stop_times"),
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
    tester(no_stt_arrtime_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_stt_deptime_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_stt_stopid_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_sto_stopid_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_sto_stoplat_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_sto_stoplon_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_stt_arrtime_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_stt_deptime_gtfs, trip_id, "stop_times"),
    class = "missing_required_field"
  )
  expect_error(
    tester(no_stt_stopseq_gtfs, trip_id, "stop_times", sort_sequence = TRUE),
    class = "missing_required_field"
  )
})

test_that("raises warnings if a non_existent trip_id is given", {
  expect_warning(tester(trip_id = c("CPTM L07-0", "ola")))
  expect_warning(tester(trip_id = "ola"))
})

test_that("gets the speed of correct 'trip_id's", {
  # if 'trip_id' = NULL, all trips have their geometries returned

  all_trip_ids <- unique(gtfs$trips$trip_id)
  all_trip_ids <- all_trip_ids[order(all_trip_ids)]

  speeds_all_trip_ids <- tester()
  trip_ids_from_speeds <- unique(speeds_all_trip_ids$trip_id)
  trip_ids_from_speeds <- trip_ids_from_speeds[order(trip_ids_from_speeds)]

  expect_identical(all_trip_ids, trip_ids_from_speeds)

  # else, only the duration of (valid) trip_ids are calculated

  selected_trip_ids <- c("CPTM L07-0", "ola")
  suppressWarnings(
    speeds_selected_trip_ids <- tester(trip_id = selected_trip_ids)
  )
  expect_equal(unique(speeds_selected_trip_ids$trip_id), "CPTM L07-0")
})

test_that("calculates the speed based on correct 'file'", {

  shape_speed <- tester(trip_id = "CPTM L07-0")
  stop_times_speed <- tester(trip_id = "CPTM L07-0", file = "stop_times")
  both_speed <- tester(
    gtfs,
    "CPTM L07-0",
    file = c("shapes", "stop_times")
  )

  expect_equal(unique(shape_speed$origin_file), "shapes")
  expect_equal(unique(stop_times_speed$origin_file), "stop_times")
  expect_identical(unique(both_speed$origin_file), c("shapes", "stop_times"))

})

test_that("outputs a 'data.table' with correct column types", {
  speeds_dt <- tester(trip_id = "CPTM L07-0")
  expect_s3_class(speeds_dt, "data.table")
  expect_equal(class(speeds_dt$trip_id), "character")
  expect_equal(class(speeds_dt$origin_file), "character")
  expect_equal(class(speeds_dt$speed), "numeric")

  # should work even when no given 'trip_id's given are present in the gtfs

  expect_warning(speeds_dt <- tester(trip_id = "ola"))
  expect_s3_class(speeds_dt, "data.table")
  expect_equal(class(speeds_dt$trip_id), "character")
  expect_equal(class(speeds_dt$origin_file), "character")
  expect_equal(class(speeds_dt$speed), "numeric")

  # and when trip_id = character(0)

  speeds_dt <- tester(trip_id = character(0))
  expect_s3_class(speeds_dt, "data.table")
  expect_equal(class(speeds_dt$trip_id), "character")
  expect_equal(class(speeds_dt$origin_file), "character")
  expect_equal(class(speeds_dt$speed), "numeric")
})

test_that("outputs speeds in correct unit", {

  # km/h

  kmh_speeds_dt <- tester(trip_id = "CPTM L07-0", unit = "km/h")

  trip_id_len <- sf::st_length(get_trip_geometry(gtfs, "CPTM L07-0", "shapes"))
  trip_id_len <- as.numeric(units::set_units(trip_id_len, "km"))
  trip_id_duration <- get_trip_duration(gtfs, "CPTM L07-0", unit = "h")

  expect_equal(trip_id_len / trip_id_duration$duration, kmh_speeds_dt$speed)

  # m/s

  ms_speeds_dt <- tester(trip_id = "CPTM L07-0", unit = "m/s")

  trip_id_len <- sf::st_length(get_trip_geometry(gtfs, "CPTM L07-0", "shapes"))
  trip_id_len <- as.numeric(units::set_units(trip_id_len, "m"))
  trip_id_duration <- get_trip_duration(gtfs, "CPTM L07-0", unit = "s")

  expect_equal(trip_id_len / trip_id_duration$duration, ms_speeds_dt$speed)

  # km/h = 3.6 * m/s

  expect_equal(kmh_speeds_dt$speed, ms_speeds_dt$speed * 3.6)

})

test_that("doesn't change given gtfs", {
  # (except for 'stop_times' and 'shapes' indices)

  original_gtfs <- read_gtfs(data_path)
  gtfs <- read_gtfs(data_path)
  expect_identical(original_gtfs, gtfs)

  speeds <- tester(trip_id = "CPTM L07-0", file = c("shapes", "stop_times"))
  expect_false(identical(original_gtfs, gtfs))

  data.table::setindex(gtfs$shapes, NULL)
  data.table::setindex(gtfs$stop_times, NULL)
  expect_identical(original_gtfs, gtfs)

  # should also work when sorting shapes/timetables
  speeds <- tester(
    trip_id = "CPTM L07-0",
    file = c("shapes", "stop_times"),
    sort_sequence = TRUE
  )
  data.table::setindex(gtfs$shapes, NULL)
  data.table::setindex(gtfs$stop_times, NULL)
  expect_identical(original_gtfs, gtfs)
})

# issue #35
test_that("warnings works properly", {
  # should raise warning if trip_id is specified and doesn't exist (and should
  # not calculate speed, instead of returning NA)
  gtfs$stop_times <- gtfs$stop_times[trip_id != "CPTM L07-0"]
  expect_warning(
    speed <- tester(trip_id = "CPTM L07-0")
  )
  expect_true(nrow(speed) == 0)

  # but if trip_id is not specified, it should not raise a warning
  expect_silent(speed <- tester())
  expect_true(!any("CPTM L07-0" %chin% speed$trip_id))
  expect_true(all(gtfs$stop_times$trip_id %chin% speed$trip_id))
})

test_that("sort_sequence works correctly", {
  speeds <- tester(trip_id = trip_id, file = c("shapes", "stop_times"))

  unordered_gtfs <- gtfs
  unordered_gtfs$shapes <- gtfs$shapes[shape_id == "17846"]
  unordered_gtfs$shapes <- unordered_gtfs$shapes[c(200:547, 1:199)]
  unordered_gtfs$stop_times <- gtfs$stop_times[trip_id == "CPTM L07-0"]
  unordered_gtfs$stop_times <- unordered_gtfs$stop_times[c(10:18, 1:9)]

  unordered_speeds <- tester(
    unordered_gtfs,
    trip_id,
    file = c("shapes", "stop_times")
  )
  expect_false(identical(unordered_speeds, speeds))

  ordered_speeds <- tester(
    unordered_gtfs,
    trip_id,
    file = c("shapes", "stop_times"),
    sort_sequence = TRUE
  )
  expect_identical(ordered_speeds, speeds)

  # sort_sequence defaults to TRUE (#94)
  default_speeds <- get_trip_speed(
    unordered_gtfs,
    trip_id,
    file = c("shapes", "stop_times"),
    unit = "km/h"
  )
  expect_identical(default_speeds, speeds)
})
