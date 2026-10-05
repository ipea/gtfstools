data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

test_that("raises errors due to incorrect input types", {
  no_class_gtfs <- unclass(gtfs)

  expect_error(convert_shapes_to_sf(no_class_gtfs))
  expect_error(convert_shapes_to_sf(gtfs, shape_id = as.factor("17846")))
  expect_error(convert_shapes_to_sf(gtfs, shape_id = NA))
  expect_error(convert_shapes_to_sf(gtfs, crs = "4326"))
  expect_error(convert_shapes_to_sf(gtfs, crs = NA))
  expect_error(convert_shapes_to_sf(gtfs, sort_sequence = "FALSE"))
  expect_error(convert_shapes_to_sf(gtfs, sort_sequence = NA))
  expect_error(convert_shapes_to_sf(gtfs, sort_sequence = c(TRUE, TRUE)))

  wrong_types_gtfs <- read_gtfs(data_path)
  wrong_types_gtfs$shapes[, shape_id := as.factor(shape_id)]
  expect_error(convert_shapes_to_sf(wrong_types_gtfs))

  wrong_types_gtfs$shapes[
    ,
    `:=`(
      shape_id = as.character(shape_id),
      shape_pt_lon = as.character(shape_pt_lon)
    )
  ]
  expect_error(convert_shapes_to_sf(wrong_types_gtfs))

  wrong_types_gtfs$shapes[
    ,
    `:=`(
      shape_pt_lon = as.numeric(shape_pt_lon),
      shape_pt_lat = as.character(shape_pt_lat)
    )
  ]
  expect_error(convert_shapes_to_sf(wrong_types_gtfs))

  # shape_pt_sequence is required when sort_sequence = TRUE
  wrong_types_gtfs$shapes[
    ,
    `:=`(
      shape_pt_lat = as.numeric(shape_pt_lat),
      shape_pt_sequence = as.character(shape_pt_sequence)
    )
  ]
  expect_error(convert_shapes_to_sf(wrong_types_gtfs, sort_sequence = TRUE))
})

test_that("convert correct shapes", {
  # if 'shape_id' is NULL (default), all shapes are converted
  shapes_sf <- convert_shapes_to_sf(gtfs)
  expect_true(
    all(gtfs$shapes$shape_id %chin% shapes_sf$shape_id)
  )

  # else only (valid) shapes are converted
  shape_ids <- c("17846", "ola")
  suppressWarnings(
    shapes_sf <- convert_shapes_to_sf(gtfs, shape_id = shape_ids)
  )
  expect_identical(shapes_sf$shape_id, "17846")
})

test_that("raises warnings/erros if invalid stop_ids are passed", {
  expect_warning(convert_shapes_to_sf(gtfs, shape_id = c("17846", "ola")))
  expect_warning(convert_shapes_to_sf(gtfs, shape_id = c("ola")))
  expect_silent(convert_shapes_to_sf(gtfs, character(0)))
})

test_that("returns a LINESTRING sf with correct crs", {
  # outputs a LINESTRING sf
  shapes_sf <- convert_shapes_to_sf(gtfs)
  expect_s3_class(shapes_sf, "sf")
  expect_s3_class(shapes_sf$geometry, "sfc_LINESTRING")

  # crs is 4326 by default
  expect_identical(sf::st_crs(shapes_sf), sf::st_crs(4326))

  # which can be changed with 'crs' argument
  shapes_sf <- convert_shapes_to_sf(gtfs, crs = 4674)
  expect_identical(sf::st_crs(shapes_sf), sf::st_crs(4674))

  # works even if none of the specified shapes exist/character(0) is given
  suppressWarnings(
    shapes_sf <- convert_shapes_to_sf(gtfs, "ola")
  )
  expect_s3_class(shapes_sf, "sf")
  expect_s3_class(shapes_sf$geometry, "sfc_LINESTRING")

  shapes_sf <- convert_shapes_to_sf(gtfs, character(0))
  expect_s3_class(shapes_sf, "sf")
  expect_s3_class(shapes_sf$geometry, "sfc_LINESTRING")
})

test_that("sort_sequence works correctly", {
  shapes_sf <- convert_shapes_to_sf(gtfs, "17846")

  unordered_gtfs <- gtfs
  unordered_gtfs$shapes <- gtfs$shapes[shape_id == "17846"]
  unordered_gtfs$shapes <- unordered_gtfs$shapes[c(200:547, 1:199)]

  unordered_sf <- convert_shapes_to_sf(unordered_gtfs, sort_sequence = FALSE)
  expect_false(identical(unordered_sf, shapes_sf))

  ordered_sf <- convert_shapes_to_sf(unordered_gtfs, sort_sequence = TRUE)
  expect_identical(ordered_sf, shapes_sf)

  # sort_sequence defaults to TRUE (#94)
  expect_identical(convert_shapes_to_sf(unordered_gtfs), shapes_sf)
})

test_that("doesn't change passed gtfs object (only the index of gtfs$shapes)", {
  original_gtfs <- read_gtfs(data_path)
  gtfs <- read_gtfs(data_path)
  shapes_sf <- convert_shapes_to_sf(gtfs)

  # 'shape_id' is set as gtfs$shapes index because of data.table subset
  data.table::setindex(gtfs$shapes, NULL)
  expect_identical(original_gtfs, gtfs)

  # should also work when sorting shapes
  shapes_sf <- convert_shapes_to_sf(gtfs, sort_sequence = TRUE)
  expect_identical(original_gtfs, gtfs)
})
