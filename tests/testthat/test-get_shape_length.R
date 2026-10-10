spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)

tester <- function(gtfs = spo_gtfs, shape_id = NULL, unit = "km") {
  get_shape_length(gtfs, shape_id, unit)
}

# tests -------------------------------------------------------------------

test_that("raises errors due to incorrect input types and missing fields", {
  expect_error(tester(unclass(spo_gtfs)))
  expect_error(tester(shape_id = NA))
  expect_error(tester(shape_id = factor("17846")))
  expect_error(tester(unit = "mi"))
  expect_error(tester(unit = c("km", "m")))

  no_shapes_gtfs <- copy_gtfs_without_file(spo_gtfs, "shapes")
  expect_error(tester(no_shapes_gtfs), class = "missing_required_file")
  no_seq_gtfs <- copy_gtfs_without_field(
    spo_gtfs,
    "shapes",
    "shape_pt_sequence"
  )
  expect_error(tester(no_seq_gtfs), class = "missing_required_field")
})

test_that("calculates the lengths calculated by sf/s2", {
  old_s2 <- suppressMessages(sf::sf_use_s2(TRUE))
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)

  result <- tester(unit = "m")
  expect_s3_class(result, "data.table")
  expect_identical(names(result), c("shape_id", "length"))
  expect_type(result$length, "double")

  shapes_sf <- convert_shapes_to_sf(spo_gtfs)
  expected <- as.numeric(sf::st_length(shapes_sf))
  expect_equal(
    result$length,
    expected[match(result$shape_id, shapes_sf$shape_id)]
  )

  # points are sorted by shape_pt_sequence, and km = m / 1000

  shuffled_gtfs <- read_gtfs(spo_path)
  shuffled_gtfs$shapes <- shuffled_gtfs$shapes[
    sample(nrow(shuffled_gtfs$shapes))
  ]
  shuffled_result <- tester(shuffled_gtfs, unit = "km")
  expect_equal(
    shuffled_result$length,
    result$length[match(shuffled_result$shape_id, result$shape_id)] / 1000
  )
})

test_that("returns the lengths of the given shape_ids", {
  shape_ids <- c("68962", "17846")
  result <- tester(shape_id = shape_ids)
  expect_setequal(result$shape_id, shape_ids)

  expect_warning(
    result <- tester(shape_id = c("17846", "nonexistent")),
    regexp = "nonexistent"
  )
  expect_identical(result$shape_id, "17846")

  empty_result <- tester(shape_id = character(0))
  expect_identical(nrow(empty_result), 0L)
  expect_type(empty_result$length, "double")
})

test_that("handles points with missing coordinates and one-point shapes", {
  edge_gtfs <- read_gtfs(spo_path)
  edge_gtfs$shapes <- data.table::copy(edge_gtfs$shapes)
  edge_gtfs$shapes[
    shape_id == "17846" & shape_pt_sequence == 3L,
    shape_pt_lat := NA
  ]
  edge_gtfs$shapes <- edge_gtfs$shapes[
    shape_id != "17847" | shape_pt_sequence == 1L
  ]

  result <- tester(edge_gtfs, shape_id = c("17846", "17847"))
  expect_true(is.na(result[shape_id == "17846"]$length))
  expect_identical(result[shape_id == "17847"]$length, 0)
})

test_that("doesn't change the given gtfs", {
  original_gtfs <- read_gtfs(spo_path)
  gtfs <- read_gtfs(spo_path)
  expect_identical(original_gtfs, gtfs)

  result <- tester(gtfs)
  expect_identical(original_gtfs, gtfs)
  result <- tester(gtfs, shape_id = "17846")
  expect_identical(original_gtfs, gtfs)
})

test_that("results don't depend on the number of threads", {
  # spo's shapes have more than 10,000 points, enough to use several threads

  ber_gtfs <- read_gtfs(
    system.file("extdata/ber_gtfs.zip", package = "gtfstools")
  )
  expect_gt(nrow(spo_gtfs$shapes), 10000)

  old_threads <- data.table::setDTthreads(1)
  on.exit(data.table::setDTthreads(old_threads), add = TRUE)
  one_thread <- list(tester(), tester(ber_gtfs))

  data.table::setDTthreads(2)
  skip_if(data.table::getDTthreads() < 2, "Can't use more than one thread.")
  two_threads <- list(tester(), tester(ber_gtfs))

  expect_identical(two_threads, one_thread)
})
