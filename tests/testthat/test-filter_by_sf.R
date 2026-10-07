spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)
bbox <- sf::st_bbox(convert_shapes_to_sf(spo_gtfs, "68962"))

test_that("filter_by_sf is defunct", {
  expect_error(
    filter_by_sf(spo_gtfs, bbox),
    class = "gtfstools_defunct_filter_by_sf_error"
  )
  expect_error(filter_by_sf(), class = "gtfstools_defunct_filter_by_sf_error")

  expect_snapshot(filter_by_sf(spo_gtfs, bbox), error = TRUE)
})
