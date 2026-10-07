spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)
spo_shape <- "68962"
bbox <- sf::st_bbox(convert_shapes_to_sf(spo_gtfs, spo_shape))
polygon <- sf::st_as_sf(sf::st_buffer(sf::st_as_sfc(bbox), 0))

tester <- function(gtfs = spo_gtfs,
                   geom = bbox,
                   spatial_operation = sf::st_intersects,
                   keep = TRUE) {
  filter_by_spatial_extent(gtfs, geom, spatial_operation, keep)
}

# tests -------------------------------------------------------------------

test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(spo_gtfs)))

  expect_error(tester(geom = unclass(bbox)))
  expect_error(tester(geom = sf::st_transform(polygon, 4674)))

  expect_error(tester(spatial_operation = "sf::st_intersect"))
  expect_error(tester(spatial_operation = sf::st_crop))

  expect_error(tester(keep = "TRUE"))
  expect_error(tester(keep = c(TRUE, TRUE)))
  expect_error(tester(keep = NA))
})

test_that("results in a dt_gtfs object", {
  # a dt_gtfs object is a list with "dt_gtfs" and "gtfs" classes
  dt_gtfs_class <- c("dt_gtfs", "gtfs", "list")
  smaller_gtfs <- tester(spo_gtfs, bbox)
  expect_s3_class(smaller_gtfs, dt_gtfs_class)
  expect_type(smaller_gtfs, "list")

  # all objects inside a dt_gtfs are data.tables
  invisible(lapply(smaller_gtfs, expect_s3_class, "data.table"))
})

test_that("doesn't change given gtfs", {
  # (except for some tables' indices)

  original_gtfs <- read_gtfs(spo_path)
  gtfs <- read_gtfs(spo_path)
  expect_identical(original_gtfs, gtfs)

  smaller_gtfs <- tester(gtfs, bbox)
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})

test_that("supports sf, sfc and bbox objects", {
  result1 <- tester(spo_gtfs, polygon)
  result2 <- tester(spo_gtfs, sf::st_geometry(polygon))
  result3 <- tester(spo_gtfs, bbox)

  expect_identical(result1, result2)
  expect_identical(result1, result3)
})

test_that("'keep' and 'spatial_operation' arguments work correctly", {
  # st_intersects

  shapes <- convert_shapes_to_sf(spo_gtfs)
  shapes_intersected <- sf::st_intersects(polygon, shapes, sparse = FALSE)
  shapes_intersected <- shapes[shapes_intersected, ]$shape_id

  trips <- get_trip_geometry(spo_gtfs, method = "euclidean")
  trips_intersected <- sf::st_intersects(polygon, trips, sparse = FALSE)
  trips_intersected <- trips[trips_intersected, ]$trip_id

  smaller_keeping <- tester(spo_gtfs, bbox)
  expect_true(all(smaller_keeping$trips$trip_id %chin% trips_intersected))
  expect_true(all(smaller_keeping$shapes$shape_id %chin% shapes_intersected))

  smaller_not_keeping <- tester(spo_gtfs, bbox, keep = FALSE)
  expect_true(!any(smaller_not_keeping$trips$trip_id %chin% trips_intersected))
  expect_true(
    !any(smaller_not_keeping$shapes$shape_id %chin% shapes_intersected)
  )

  # st_contains

  shapes_contained <- sf::st_contains(polygon, shapes, sparse = FALSE)
  shapes_contained <- shapes[shapes_contained, ]$shape_id

  trips_contained <- sf::st_contains(polygon, trips, sparse = FALSE)
  trips_contained <- trips[trips_contained, ]$trip_id

  smaller_keeping <- tester(
    spo_gtfs,
    bbox,
    spatial_operation = sf::st_contains
  )
  expect_true(all(smaller_keeping$trips$trip_id %chin% trips_contained))
  expect_true(all(smaller_keeping$shapes$shape_id %chin% shapes_contained))

  smaller_not_keeping <- tester(
    spo_gtfs,
    bbox,
    spatial_operation = sf::st_contains,
    keep = FALSE
  )
  expect_true(!any(smaller_not_keeping$trips$trip_id %chin% trips_contained))
  expect_true(
    !any(smaller_not_keeping$shapes$shape_id %chin% shapes_contained)
  )
})

test_that("selects the union of trips selected by shapes and by stop_times", {
  # a trip is selected if its shape or the path through its stops intersects
  # with the polygon. 'keep = FALSE' must drop all of these trips. the western
  # half of the feed's extent selects some trips only through their stops

  shapes <- convert_shapes_to_sf(spo_gtfs)
  half_bbox <- sf::st_bbox(shapes)
  half_bbox["xmax"] <- (half_bbox["xmin"] + half_bbox["xmax"]) / 2
  half_polygon <- sf::st_as_sfc(half_bbox)

  shapes_hit <- sf::st_intersects(half_polygon, shapes, sparse = FALSE)
  shapes_hit <- shapes[shapes_hit, ]$shape_id
  trips_hit_by_shape <- spo_gtfs$trips[shape_id %chin% shapes_hit]$trip_id

  trips <- get_trip_geometry(spo_gtfs, method = "euclidean")
  trips_hit_by_stops <- sf::st_intersects(half_polygon, trips, sparse = FALSE)
  trips_hit_by_stops <- trips[trips_hit_by_stops, ]$trip_id

  # make sure the test is not vacuous: some trips are selected by only one of
  # the criteria

  expect_false(setequal(trips_hit_by_shape, trips_hit_by_stops))

  selected_trips <- union(trips_hit_by_shape, trips_hit_by_stops)
  not_selected_trips <- setdiff(spo_gtfs$trips$trip_id, selected_trips)

  smaller_keeping <- tester(spo_gtfs, half_polygon)
  expect_setequal(smaller_keeping$trips$trip_id, selected_trips)

  smaller_not_keeping <- tester(spo_gtfs, half_polygon, keep = FALSE)
  expect_setequal(smaller_not_keeping$trips$trip_id, not_selected_trips)
})

test_that("doesn't add attributes to the given stop_times table", {
  gtfs <- read_gtfs(spo_path)
  original_attributes <- attributes(gtfs$stop_times)

  smaller_gtfs <- tester(gtfs, bbox)
  expect_identical(attributes(gtfs$stop_times), original_attributes)
})

test_that("works with sf describing two features", {
  another_shape <- "17846"
  another_bbox <- sf::st_bbox(convert_shapes_to_sf(spo_gtfs, another_shape))
  another_polygon <- sf::st_as_sf(sf::st_as_sfc(another_bbox))
  bigger_polygon <- rbind(polygon, another_polygon)

  smaller_gtfs <- tester(
    spo_gtfs,
    bigger_polygon,
    spatial_operation = sf::st_contains
  )

  # shape 17847 is also contained inside 17846's bbox
  expect_true(
    all(smaller_gtfs$shapes$shape_id %chin% c("68962", "17846", "17847"))
  )
})

test_that("error if gtfs doesn't contain neither shapes nor stop_times table", {
  spo_gtfs$shapes <- NULL
  spo_gtfs$stop_times <- NULL
  expect_error(tester(spo_gtfs, bbox))
})

test_that("ignores stops with missing coordinates", {
  na_gtfs <- read_gtfs(spo_path)
  na_gtfs$shapes <- NULL
  na_stops <- na_gtfs$stop_times[trip_id == "CPTM L07-0"]$stop_id[1:3]
  na_gtfs$stops[stop_id %chin% na_stops, stop_lat := NA]

  expect_s3_class(tester(na_gtfs), "dt_gtfs")

  # the trip is still selected by its stops with coordinates

  feed_bbox <- sf::st_bbox(convert_stops_to_sf(spo_gtfs))
  result <- tester(na_gtfs, geom = feed_bbox)
  expect_true("CPTM L07-0" %chin% result$trips$trip_id)
})
