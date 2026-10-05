data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
trip_id <- "CPTM L07-0"

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   file = NULL,
                   crs = 4326,
                   sort_sequence = FALSE) {
  get_trip_geometry(gtfs, trip_id, file, crs, sort_sequence)
}

test_that("raises errors due to incorrect input types/value", {
  expect_error(tester(unclass(gtfs)))
  expect_error(tester(trip_id = as.factor("CPTM L07-0")))
  expect_error(tester(trip_id = NA))
  expect_error(tester(file = c("shapes", "stops")))
  expect_error(tester(crs = "4674"))
  expect_error(tester(sort_sequence = "FALSE"))
  expect_error(tester(sort_sequence = NA))
  expect_error(tester(sort_sequence = c(TRUE, TRUE)))
})

test_that("raises errors if gtfs doesn't have required files/fields", {
  no_trips_gtfs <- copy_gtfs_without_file(gtfs, "trips")
  no_shapes_gtfs <- copy_gtfs_without_file(gtfs, "shapes")
  no_stop_times_gtfs <- copy_gtfs_without_file(gtfs, "stop_times")
  no_stops_gtfs <- copy_gtfs_without_file(gtfs, "stops")

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

  # 'shapes'-based geometries

  expect_error(tester(no_trips_gtfs, trip_id, "shapes"))
  expect_error(tester(no_shapes_gtfs, trip_id, "shapes"))
  expect_error(tester(no_trp_tripid_gtfs, trip_id, "shapes"))
  expect_error(tester(no_trp_shapeid_gtfs, trip_id, "shapes"))
  expect_error(tester(no_shp_shapeid_gtfs, trip_id, "shapes"))
  expect_error(tester(no_shp_shapelat_gtfs, trip_id, "shapes"))
  expect_error(tester(no_shp_shapelon_gtfs, trip_id, "shapes"))
  expect_error(
    tester(no_shp_shapeseq_gtfs, trip_id, "shapes", sort_sequence = TRUE)
  )
  expect_s3_class(tester(no_stop_times_gtfs, trip_id, "shapes"), "sf")
  expect_s3_class(tester(no_stops_gtfs, trip_id, "shapes"), "sf")

  # 'stop_times'-based geometries

  expect_error(tester(no_trips_gtfs, trip_id, "stop_times"))
  expect_error(tester(no_stop_times_gtfs, trip_id, "stop_times"))
  expect_error(tester(no_stops_gtfs, trip_id, "stop_times"))
  expect_error(tester(no_trp_tripid_gtfs, trip_id, "stop_times"))
  expect_error(tester(no_stt_tripid_gtfs, trip_id, "stop_times"))
  expect_error(tester(no_stt_stopid_gtfs, trip_id, "stop_times"))
  expect_error(tester(no_sts_stopid_gtfs, trip_id, "stop_times"))
  expect_error(tester(no_sts_stoplat_gtfs, trip_id, "stop_times"))
  expect_error(tester(no_sts_stoplon_gtfs, trip_id, "stop_times"))
  expect_error(
    tester(no_stt_stopseq_gtfs, trip_id, "stop_times", sort_sequence = TRUE)
  )
  expect_s3_class(tester(no_shapes_gtfs, trip_id, "stop_times"), "sf")
  expect_s3_class(tester(no_trp_shapeid_gtfs, trip_id, "stop_times"), "sf")
})

test_that("returns the geometries of correct 'trip_id's", {
  all_trip_ids <- unique(gtfs$trips$trip_id)
  all_trip_ids <- all_trip_ids[order(all_trip_ids)]

  geometries_all_trip_ids <- tester(gtfs)
  trip_ids_from_geom <- unique(geometries_all_trip_ids$trip_id)
  trip_ids_from_geom <- trip_ids_from_geom[order(trip_ids_from_geom)]

  expect_identical(all_trip_ids, trip_ids_from_geom)

  # else, only the duration of (valid) trip_ids are calculated

  selected_trip_ids <- c("CPTM L07-0", "ola")
  suppressWarnings(
    geom_selected_trip_ids <- tester(trip_id = selected_trip_ids)
  )
  expect_equal(unique(geom_selected_trip_ids$trip_id), "CPTM L07-0")

})

test_that("raises warnings if a non_existent 'trip_id' is given", {
  expect_warning(tester(trip_id = c("CPTM L07-0", "ola")))
})

test_that("returns the geometries created by the given 'file'", {
  shape_geom <- tester(trip_id = "CPTM L07-0", file = "shapes")
  stop_times_geom <- tester(trip_id = "CPTM L07-0", file = "stop_times")
  both_geom <- tester(trip_id = "CPTM L07-0")

  expect_equal(unique(shape_geom$origin_file), "shapes")
  expect_equal(unique(stop_times_geom$origin_file), "stop_times")
  expect_identical(unique(both_geom$origin_file), c("shapes", "stop_times"))
})

test_that("outputs an 'sf' object with correct crs", {
  # crs is WGS by default

  point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326)
  sf_geom <- tester(trip_id = c("CPTM L07-0"))
  expect_s3_class(sf_geom, "sf")
  expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

  # 'crs' can be an integer or crs object

  point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4674)
  sf_geom <- tester(trip_id = c("CPTM L07-0"), crs = 4674)
  expect_s3_class(sf_geom, "sf")
  expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

  sf_geom <- tester(trip_id = c("CPTM L07-0"), crs = sf::st_crs(point))
  expect_s3_class(sf_geom, "sf")
  expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

  # should work even when all 'trip_id's given are not present in the gtfs

  point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326)
  expect_warning(sf_geom <- tester(trip_id = c("ola")))
  expect_s3_class(sf_geom, "sf")
  expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

  point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4674)
  expect_warning(sf_geom <- tester(trip_id = c("ola"), crs = 4674))
  expect_s3_class(sf_geom, "sf")
  expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

  expect_warning(
    sf_geom <- tester(trip_id = c("ola"), crs = sf::st_crs(point))
  )
  expect_s3_class(sf_geom, "sf")
  expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

  # and when trip_id = character(0)

  point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326)
  sf_geom <- tester(trip_id = character(0))
  expect_s3_class(sf_geom, "sf")
  expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

  point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4674)
  sf_geom <- tester(trip_id = character(0), crs = 4674)
  expect_s3_class(sf_geom, "sf")
  expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

  sf_geom <- tester(trip_id = character(0), crs = sf::st_crs(point))
  expect_s3_class(sf_geom, "sf")
  expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))
})

test_that("outputs an 'sf' object with correct column types", {
  sf_geom <- tester(trip_id = "CPTM L07-0")
  expect_s3_class(sf_geom, "sf")
  expect_equal(class(sf_geom$trip_id), "character")
  expect_equal(class(sf_geom$origin_file), "character")
  expect_identical(class(sf_geom$geometry), c("sfc_LINESTRING", "sfc"))

  # should work even when all 'trip_id's given are not present in the gtfs

  expect_warning(sf_geom <- tester(trip_id = "ola"))
  expect_s3_class(sf_geom, "sf")
  expect_equal(class(sf_geom$trip_id), "character")
  expect_equal(class(sf_geom$origin_file), "character")
  expect_identical(class(sf_geom$geometry), c("sfc_LINESTRING", "sfc"))

  # and when trip_id = character(0)

  sf_geom <- tester(trip_id = character(0))
  expect_s3_class(sf_geom, "sf")
  expect_equal(class(sf_geom$trip_id), "character")
  expect_equal(class(sf_geom$origin_file), "character")
  expect_identical(class(sf_geom$geometry), c("sfc_LINESTRING", "sfc"))
})

test_that("doesn't change given gtfs", {
  # (except for 'stop_times' and 'shapes' indices)

  original_gtfs <- read_gtfs(data_path)
  gtfs <- read_gtfs(data_path)
  expect_identical(original_gtfs, gtfs)

  sf_geom <- tester(trip_id = "CPTM L07-0")
  expect_false(identical(original_gtfs, gtfs))

  data.table::setindex(gtfs$shapes, NULL)
  data.table::setindex(gtfs$stop_times, NULL)
  expect_identical(original_gtfs, gtfs)

  # should also work when sorting shapes/timetables
  sf_geom <- tester(sort_sequence = TRUE)
  data.table::setindex(gtfs$shapes, NULL)
  data.table::setindex(gtfs$stop_times, NULL)
  expect_identical(original_gtfs, gtfs)
})

test_that("returns empty sf if passed 'trip_id' isn't linked to a 'shape_id'", {
  gtfs$trips[trip_id == "CPTM L07-0", shape_id := ""]

  # if requested geometry from both files, output should only contain
  # 'stop_times' geometry

  sf_geom <- tester(trip_id = "CPTM L07-0")
  expect_identical(sf_geom$origin_file, "stop_times")

  # if request geometry from 'shapes', output should be an empty sf

  sf_geom <- tester(trip_id = "CPTM L07-0", file = "shapes")
  expect_s3_class(sf_geom, "sf")
  expect_identical(class(sf_geom$geometry), c("sfc_LINESTRING", "sfc"))
  expect_equal(nrow(sf_geom), 0)
})

# issue #29
test_that("works correctly if 'file' is untouched and one file is missing", {
  no_shapes <- read_gtfs(data_path)
  no_shapes$shapes <- NULL
  expect_s3_class(tester(no_shapes), "sf")
  expect_true(all(tester(no_shapes)$origin_file == "stop_times"))

  no_stop_times <- read_gtfs(data_path)
  no_stop_times$stop_times <- NULL
  expect_s3_class(tester(no_stop_times), "sf")
  expect_true(all(tester(no_stop_times)$origin_file == "shapes"))

  none_of_them <- read_gtfs(data_path)
  none_of_them$shapes <- none_of_them$stop_times <- NULL
  expect_error(
    tester(none_of_them),
    regexp = paste0(
      "The GTFS object must have either a ",
      "'shapes' or a 'stop_times' table\\."
    )
  )
})

test_that("sort_sequence works correctly", {
  geoms <- tester(trip_id = trip_id)

  unordered_gtfs <- gtfs
  unordered_gtfs$shapes <- gtfs$shapes[shape_id == "17846"]
  unordered_gtfs$shapes <- unordered_gtfs$shapes[c(200:547, 1:199)]
  unordered_gtfs$stop_times <- gtfs$stop_times[trip_id == "CPTM L07-0"]
  unordered_gtfs$stop_times <- unordered_gtfs$stop_times[c(10:18, 1:9)]

  unordered_geoms <- tester(unordered_gtfs, trip_id)
  expect_false(identical(unordered_geoms, geoms))

  ordered_geoms <- tester(unordered_gtfs, trip_id, sort_sequence = TRUE)
  expect_identical(ordered_geoms, geoms)

  # sort_sequence defaults to TRUE (#94)
  default_geoms <- get_trip_geometry(unordered_gtfs, trip_id)
  expect_identical(default_geoms, geoms)
})
