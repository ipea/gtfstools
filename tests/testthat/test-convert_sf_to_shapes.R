data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

shapes_sf <- convert_shapes_to_sf(gtfs, shape_id = c("17846", "17847", "17848"))

tester <- function(sf_shapes = shapes_sf,
                   shape_id = NULL,
                   calculate_distance = FALSE) {
  convert_sf_to_shapes(sf_shapes, shape_id, calculate_distance)
}

test_that("raises errors due to incorrect input types", {
  expect_error(tester("a"))
  expect_error(tester(sf::st_cast(shapes_sf, "POINT")))
  expect_error(tester(sf::st_transform(shapes_sf, 4674)))

  expect_error(tester(shape_id = 1))
  expect_error(tester(shape_id = NA_character_))

  expect_error(tester(calculate_distance = "TRUE"))
  expect_error(tester(calculate_distance = c(TRUE, TRUE)))
  expect_error(tester(calculate_distance = NA))
})

test_that("convert correct shapes", {
  # if 'shape_id' is NULL (default), all shapes are converted
  shapes <- tester()
  expect_true(all(shapes_sf$shape_id %chin% shapes$shape_id))

  # else only (valid) shapes are converted
  shape_ids <- c("17846", "ola")
  suppressWarnings(shapes <- tester(shape_id = shape_ids))
  expect_true(all(shapes$shape_id == "17846"))
})

test_that("raises warnings if some of the specified ids don't exist", {
  expect_warning(tester(shape_id = c("17846", "ola")))
  expect_warning(tester(shape_id = "ola"))
})

test_that("returns empty dt with empty sf and shape_id as inputs", {
  empty_sf_result <- tester(shapes_sf[0, ])
  expect_true(nrow(empty_sf_result) == 0)

  empty_shape_id_result <- tester(shape_id = character(0))
  expect_true(nrow(empty_shape_id_result) == 0)
})

test_that("returns a data.table with columns of correct class", {
  result <- tester()
  expect_s3_class(result, "data.table")
  expect_type(result$shape_id, "character")
  expect_type(result$shape_pt_lon, "double")
  expect_type(result$shape_pt_lat, "double")
  expect_type(result$shape_pt_sequence, "integer")

  # should work even if shape_id = character(0)

  result <- tester(shape_id = character(0))
  expect_s3_class(result, "data.table")
  expect_type(result$shape_id, "character")
  expect_type(result$shape_pt_lon, "double")
  expect_type(result$shape_pt_lat, "double")
  expect_type(result$shape_pt_sequence, "integer")

  # and both cases above should work when additional columns are present

  larger_sf <- shapes_sf
  larger_sf$extra_col <- c(1L, 2L, 3L)

  result <- tester(larger_sf)
  expect_s3_class(result, "data.table")
  expect_type(result$shape_id, "character")
  expect_type(result$shape_pt_lon, "double")
  expect_type(result$shape_pt_lat, "double")
  expect_type(result$shape_pt_sequence, "integer")
  expect_type(result$extra_col, "integer")

  result <- tester(larger_sf, shape_id = character(0))
  expect_s3_class(result, "data.table")
  expect_type(result$shape_id, "character")
  expect_type(result$shape_pt_lon, "double")
  expect_type(result$shape_pt_lat, "double")
  expect_type(result$shape_pt_sequence, "integer")
  expect_type(result$extra_col, "integer")
})

test_that("calculate_distance calculates shape_dist_traveled", {
  result <- tester(calculate_distance = TRUE)
  expect_type(result$shape_dist_traveled, "double")

  # works when shape_id = character(0)

  result <- tester(shape_id = character(0), calculate_distance = TRUE)
  expect_type(result$shape_dist_traveled, "double")
})

test_that("calculated coords and distances are correct", {
  filtered_original_shapes <- gtfs$shapes[
    shape_id %in% c("17846", "17847", "17848")
  ]

  shapes_from_sf <- tester()

  expect_identical(
    filtered_original_shapes[
      ,
      .(shape_id, shape_pt_lon, shape_pt_lat, shape_pt_sequence)
    ],
    shapes_from_sf
  )

  # distances in original gtfs don't start at 0 and are not really trustworthy,
  # so not checking that for now
})

test_that("shape_dist_traveled matches the distances calculated by sf/s2", {
  old_s2 <- sf::sf_use_s2(TRUE)
  on.exit(sf::sf_use_s2(old_s2), add = TRUE)

  result <- tester(calculate_distance = TRUE)
  expect_identical(
    names(result),
    c(
      "shape_id", "shape_dist_traveled", "shape_pt_lon", "shape_pt_lat",
      "shape_pt_sequence"
    )
  )

  # cumulative distance between consecutive points, calculated with sf

  expected <- result[
    ,
    {
      points <- sf::st_as_sf(
        data.frame(x = shape_pt_lon, y = shape_pt_lat),
        coords = c("x", "y"),
        crs = 4326
      )
      dists <- sf::st_distance(
        points[-.N, ],
        points[-1, ],
        by_element = TRUE
      )
      .(dist = cumsum(c(0, as.numeric(dists))))
    },
    by = shape_id
  ]
  expect_equal(
    result$shape_dist_traveled,
    expected$dist,
    tolerance = 1e-6 / max(expected$dist)
  )
  expect_true(all(result[, shape_dist_traveled[1], by = shape_id]$V1 == 0))

  # the last value of each shape equals the length of the shape

  lengths <- as.numeric(sf::st_length(shapes_sf))
  last_dist <- result[, shape_dist_traveled[.N], by = shape_id]$V1
  expect_equal(last_dist, lengths, tolerance = 1e-6 / max(lengths))

  # results don't depend on whether s2 is enabled

  sf::sf_use_s2(FALSE)
  expect_identical(tester(calculate_distance = TRUE), result)
})

test_that("keeps extra columns before shape_dist_traveled", {
  larger_sf <- shapes_sf
  larger_sf$extra_col <- c(1L, 2L, 3L)

  result <- tester(larger_sf, calculate_distance = TRUE)
  expect_identical(
    names(result),
    c(
      "shape_id", "extra_col", "shape_dist_traveled", "shape_pt_lon",
      "shape_pt_lat", "shape_pt_sequence"
    )
  )
})

test_that("doesn't change given sf", {
  original_sf <- convert_shapes_to_sf(
    gtfs,
    shape_id = c("17846", "17847", "17848")
  )
  given_sf <- convert_shapes_to_sf(
    gtfs,
    shape_id = c("17846", "17847", "17848")
  )
  expect_identical(original_sf, given_sf)

  result <- tester(given_sf, calculate_distance = TRUE)
  expect_identical(original_sf, given_sf)
})

test_that("rcpp_distance_haversine() calculates distances correctly", {
  # one degree along the equator and along a meridian

  one_degree <- 6371010 * pi / 180
  expect_equal(
    rcpp_distance_haversine(c(0, 0), c(0, 0), c(0, 1), c(1, 0)),
    c(one_degree, one_degree)
  )

  # antipodal points

  expect_equal(rcpp_distance_haversine(0, 0, 0, 180), 6371010 * pi)

  # NA coordinates result in NA

  expect_identical(
    rcpp_distance_haversine(c(NA, 0), c(0, 0), c(0, 0), c(0, NA)),
    c(NA_real_, NA_real_)
  )
  expect_identical(
    rcpp_distance_haversine(numeric(0), numeric(0), numeric(0), numeric(0)),
    numeric(0)
  )
  expect_error(rcpp_distance_haversine(0, 0, 0, c(0, 1)))
})
