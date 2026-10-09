spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)
ggl_gtfs <- read_gtfs(ggl_path)
ber_gtfs <- read_gtfs(ber_path)

tester <- function(gtfs = spo_gtfs, trip_id = NULL) {
  convert_stops_to_shapes(gtfs, trip_id)
}

# collects all the warnings raised by an expression, muffling them

collect_warnings <- function(expr) {
  warnings <- list()
  result <- withCallingHandlers(
    expr,
    warning = function(cnd) {
      warnings <<- c(warnings, list(cnd))
      invokeRestart("muffleWarning")
    }
  )
  return(list(result = result, warnings = warnings))
}


# tests -------------------------------------------------------------------


test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(spo_gtfs)))
  expect_error(tester(trip_id = 1))
  expect_error(tester(trip_id = NA_character_))

  no_stops <- copy_gtfs_without_file(spo_gtfs, "stops")
  expect_error(tester(no_stops))

  bad_shapes <- copy_gtfs_diff_field_class(
    spo_gtfs,
    "shapes",
    "shape_pt_lat",
    "character"
  )
  expect_error(tester(bad_shapes, trip_id = "CPTM L07-0"))
})

test_that("results in a dt_gtfs object", {
  dt_gtfs_class <- c("dt_gtfs", "gtfs", "list")
  new_gtfs <- tester(trip_id = "CPTM L07-0")
  expect_s3_class(new_gtfs, dt_gtfs_class)
  invisible(lapply(new_gtfs, expect_s3_class, "data.table"))
})

test_that("doesn't change given gtfs", {
  # (except for some tables' indices). stop_times gets a shape_dist_traveled
  # column, which is changed for the trips that get new shapes

  original_gtfs <- read_gtfs(spo_path)
  original_gtfs$stop_times[, shape_dist_traveled := as.numeric(.I)]
  gtfs <- read_gtfs(spo_path)
  gtfs$stop_times[, shape_dist_traveled := as.numeric(.I)]
  expect_identical(original_gtfs, gtfs)

  invisible(convert_stops_to_shapes(gtfs, trip_id = "CPTM L07-0"))
  gtfs_without_shapes <- gtfs
  gtfs_without_shapes$shapes <- NULL
  invisible(convert_stops_to_shapes(gtfs_without_shapes))
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})

test_that("given trips get shapes linking their stops", {
  trip <- "CPTM L07-0"
  new_gtfs <- tester(trip_id = trip)

  old_shape <- spo_gtfs$trips[trip_id == trip]$shape_id
  new_shape <- new_gtfs$trips[trip_id == trip]$shape_id
  expect_false(new_shape == old_shape)
  expect_identical(new_shape, "stops_shape_1")

  # the shape points are the trip's stops, linked as in the geometry built by
  # get_trip_geometry() with straight lines between stops

  geometry <- get_trip_geometry(spo_gtfs, trip, method = "euclidean")
  coords <- sf::st_coordinates(geometry)
  new_points <- new_gtfs$shapes[shape_id == new_shape]
  expect_equal(new_points$shape_pt_lon, unname(coords[, "X"]))
  expect_equal(new_points$shape_pt_lat, unname(coords[, "Y"]))
  expect_identical(new_points$shape_pt_sequence, seq_len(nrow(new_points)))

  # the other trips and the existing shapes are kept as they were

  expect_identical(
    new_gtfs$trips[trip_id != trip],
    spo_gtfs$trips[trip_id != trip]
  )
  expect_identical(
    new_gtfs$shapes[shape_id != new_shape],
    spo_gtfs$shapes,
    ignore_attr = TRUE
  )
  expect_true(all(is.na(new_points$shape_dist_traveled)))
})

test_that("trips that visit the same stops share a shape", {
  gtfs <- read_gtfs(ber_path)
  gtfs$shapes <- NULL

  # guard: every trip can get a shape, so that each pattern gets one
  stop_idx <- match(gtfs$stop_times$stop_id, gtfs$stops$stop_id)
  expect_false(anyNA(gtfs$stops$stop_lat[stop_idx]))

  new_gtfs <- tester(gtfs)
  patterns <- get_stop_times_patterns(gtfs)
  trip_shapes <- new_gtfs$trips[, .(trip_id, shape_id)]
  trip_shapes <- trip_shapes[patterns, on = "trip_id"]

  n_patterns <- data.table::uniqueN(patterns$pattern_id)
  expect_identical(data.table::uniqueN(new_gtfs$shapes$shape_id), n_patterns)
  expect_identical(
    nrow(unique(trip_shapes[, .(shape_id, pattern_id)])),
    n_patterns
  )
  expect_false(anyNA(new_gtfs$trips$shape_id))
})

test_that("by default, only trips without usable shapes get new shapes", {
  # every spo trip is linked to a usable shape, so nothing changes

  expect_identical(tester(), spo_gtfs)

  # one trip without shape_id, one linked to a shape not listed in shapes, and
  # the trips linked to a shape with a single distinct point

  gtfs <- read_gtfs(spo_path)
  gtfs$trips[1, shape_id := ""]
  gtfs$trips[2, shape_id := "nowhere"]
  degenerate_shape <- gtfs$trips$shape_id[3]
  gtfs$shapes[
    shape_id == degenerate_shape,
    c("shape_pt_lat", "shape_pt_lon") := list(shape_pt_lat[1], shape_pt_lon[1])
  ]

  expected_trips <- c(
    gtfs$trips$trip_id[1:2],
    gtfs$trips[shape_id == degenerate_shape]$trip_id
  )

  new_gtfs <- tester(gtfs)
  is_new <- grepl("^stops_shape_", new_gtfs$trips$shape_id)
  expect_setequal(new_gtfs$trips$trip_id[is_new], expected_trips)

  # trips without the shape_id column all get new shapes

  no_shape_id <- copy_gtfs_without_field(spo_gtfs, "trips", "shape_id")
  new_gtfs <- tester(no_shape_id)
  expect_type(new_gtfs$trips$shape_id, "character")
  expect_true(all(grepl("^stops_shape_", new_gtfs$trips$shape_id)))
})

test_that("skips stops without coordinates", {
  # a middle stop of a trip loses its coordinates. it's skipped in the trip's
  # shape, so the trip shares a shape with a copy of it that doesn't visit it

  gtfs <- read_gtfs(spo_path)
  gtfs$shapes <- NULL
  trip <- "CPTM L07-0"
  trip_stops <- gtfs$stop_times[trip_id == trip]
  skipped_stop <- trip_stops$stop_id[2]
  gtfs$stops[stop_id == skipped_stop, c("stop_lat", "stop_lon") := NA_real_]

  trip_copy <- trip_stops[stop_id != skipped_stop]
  trip_copy[, trip_id := "copy"]
  gtfs$stop_times <- rbind(gtfs$stop_times, trip_copy)
  gtfs$trips <- rbind(
    gtfs$trips,
    gtfs$trips[trip_id == trip][, trip_id := "copy"]
  )

  new_gtfs <- tester(gtfs)
  trip_shape <- new_gtfs$trips[trip_id == trip]$shape_id
  expect_identical(new_gtfs$trips[trip_id == "copy"]$shape_id, trip_shape)
  expect_identical(
    nrow(new_gtfs$shapes[shape_id == trip_shape]),
    nrow(trip_stops) - 1L
  )
})

test_that("is idempotent by default", {
  gtfs <- read_gtfs(spo_path)
  gtfs$shapes <- NULL

  new_gtfs <- tester(gtfs)
  expect_identical(tester(new_gtfs), new_gtfs)
})

test_that("new shape_ids don't clash with existing ones", {
  gtfs <- read_gtfs(spo_path)
  clashing_shape <- gtfs$shapes[shape_id == gtfs$shapes$shape_id[1]]
  clashing_shape[, shape_id := "stops_shape_1"]
  gtfs$shapes <- rbind(gtfs$shapes, clashing_shape)
  gtfs$trips[1, shape_id := "stops_shape_2"]

  new_gtfs <- tester(gtfs)
  expect_identical(new_gtfs$trips$shape_id[1], "stops_shape_3")
})

test_that("blanks the shape_dist_traveled of the trips' stop_times", {
  gtfs <- read_gtfs(spo_path)
  gtfs$stop_times[, shape_dist_traveled := as.numeric(.I)]
  expect_true("shape_dist_traveled" %in% names(gtfs$stop_times))

  trip <- "CPTM L07-0"
  new_gtfs <- tester(gtfs, trip_id = trip)
  is_trip <- new_gtfs$stop_times$trip_id == trip

  expect_true(all(is.na(new_gtfs$stop_times$shape_dist_traveled[is_trip])))
  expect_identical(
    new_gtfs$stop_times$shape_dist_traveled[!is_trip],
    gtfs$stop_times$shape_dist_traveled[!is_trip]
  )
})

test_that("warns about trips that can't get a shape", {
  # no ggl trip can get a shape: the stops of AWE1 are not listed in 'stops'
  # and AWE2 has no stop_times. AWD1 is not listed in 'trips', so it is ignored

  output <- collect_warnings(tester(ggl_gtfs))
  expect_length(output$warnings, 1)
  expect_s3_class(output$warnings[[1]], "gtfstools_shapes_not_built")

  message <- conditionMessage(output$warnings[[1]])
  expect_match(message, "AWE1", fixed = TRUE)
  expect_match(message, "AWE2", fixed = TRUE)
  expect_false(grepl("AWD1", message, fixed = TRUE))

  expect_identical(output$result, ggl_gtfs)
})

test_that("ignores trips not listed in trips", {
  # a spo trip removed from 'trips' keeps its stop_times, but gets no shape

  gtfs <- read_gtfs(spo_path)
  gtfs$shapes <- NULL
  removed_trip <- "CPTM L07-0"
  gtfs$trips <- gtfs$trips[trip_id != removed_trip]
  expect_true(removed_trip %chin% gtfs$stop_times$trip_id)

  expect_silent(new_gtfs <- tester(gtfs))
  expected_n_shapes <- data.table::uniqueN(
    get_stop_times_patterns(gtfs, trip_id = gtfs$trips$trip_id)$pattern_id
  )
  expect_identical(
    data.table::uniqueN(new_gtfs$shapes$shape_id),
    expected_n_shapes
  )
})

test_that("warns about unknown trip_ids", {
  expect_warning(
    new_gtfs <- tester(trip_id = c("CPTM L07-0", "x", "x")),
    class = "gtfstools_invalid_trip_id"
  )
  expect_identical(new_gtfs, tester(trip_id = "CPTM L07-0"))

  expect_warning(
    new_gtfs <- tester(trip_id = "x"),
    class = "gtfstools_invalid_trip_id"
  )
  expect_identical(new_gtfs, spo_gtfs)
})
