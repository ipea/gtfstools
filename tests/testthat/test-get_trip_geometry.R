data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
poa_gtfs <- read_gtfs(poa_path)
trip_id <- "CPTM L07-0"

tester <- function(gtfs = get("gtfs", envir = parent.frame()),
                   trip_id = NULL,
                   method = "shapes",
                   crs = 4326,
                   sort_sequence = TRUE) {
  get_trip_geometry(gtfs, trip_id, method, crs, sort_sequence)
}

# creates a feed with a single shape ('shape_lon' and 'shape_lat') and a single
# trip that serves the stops described by 'stop_lon' and 'stop_lat', in this
# order. stops at the same coordinates share the same stop_id

synthetic_feed <- function(shape_lon, shape_lat, stop_lon, stop_lat) {
  stop_coords <- paste(stop_lon, stop_lat)
  unique_coords <- unique(stop_coords)
  stop_ids <- paste0("s", match(stop_coords, unique_coords))

  feed <- list(
    trips = data.table::data.table(trip_id = "t1", shape_id = "sh1"),
    shapes = data.table::data.table(
      shape_id = "sh1",
      shape_pt_lat = shape_lat,
      shape_pt_lon = shape_lon,
      shape_pt_sequence = seq_along(shape_lat)
    ),
    stops = data.table::data.table(
      stop_id = unique(stop_ids),
      stop_lat = stop_lat[!duplicated(stop_ids)],
      stop_lon = stop_lon[!duplicated(stop_ids)]
    ),
    stop_times = data.table::data.table(
      trip_id = "t1",
      stop_id = stop_ids,
      stop_sequence = seq_along(stop_ids)
    )
  )

  return(gtfsio::new_gtfs(feed, "dt_gtfs"))
}

# great-circle length, in meters, of an arc of 'degrees' degrees
arc <- function(degrees) 6371010 * degrees * pi / 180

# coordinates of a single geometry, as a two-column (lon, lat) matrix
coords <- function(geom) unname(sf::st_coordinates(geom)[, 1:2, drop = FALSE])

# tests -------------------------------------------------------------------

test_that("raises errors due to incorrect input types/value", {
  expect_error(tester(unclass(gtfs)))
  expect_error(tester(trip_id = as.factor("CPTM L07-0")))
  expect_error(tester(trip_id = NA))
  expect_error(tester(method = "stop_times"))
  expect_error(tester(method = c("shapes", "euclidean")))
  expect_error(tester(crs = "4674"))
  expect_error(tester(sort_sequence = "FALSE"))
  expect_error(tester(sort_sequence = NA))
  expect_error(tester(sort_sequence = c(TRUE, TRUE)))
  expect_error(get_trip_geometry(gtfs, file = c("shapes", "stops")))
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

  # both methods require 'stop_times' and 'stops'

  for (method in c("shapes", "euclidean")) {
    expect_error(tester(no_stop_times_gtfs, trip_id, method))
    expect_error(tester(no_stops_gtfs, trip_id, method))
    expect_error(tester(no_stt_tripid_gtfs, trip_id, method))
    expect_error(tester(no_stt_stopid_gtfs, trip_id, method))
    expect_error(tester(no_stt_stopseq_gtfs, trip_id, method))
    expect_error(tester(no_sts_stopid_gtfs, trip_id, method))
    expect_error(tester(no_sts_stoplat_gtfs, trip_id, method))
    expect_error(tester(no_sts_stoplon_gtfs, trip_id, method))
    expect_s3_class(
      tester(no_stt_stopseq_gtfs, trip_id, method, sort_sequence = FALSE),
      "sf"
    )
  }

  # 'shapes'-based geometries also require 'trips' and 'shapes' fields

  expect_error(tester(no_trp_tripid_gtfs, trip_id, "shapes"))
  expect_error(tester(no_shp_shapeid_gtfs, trip_id, "shapes"))
  expect_error(tester(no_shp_shapelat_gtfs, trip_id, "shapes"))
  expect_error(tester(no_shp_shapelon_gtfs, trip_id, "shapes"))
  expect_error(tester(no_shp_shapeseq_gtfs, trip_id, "shapes"))
  expect_s3_class(
    tester(no_shp_shapeseq_gtfs, trip_id, "shapes", sort_sequence = FALSE),
    "sf"
  )

  # 'euclidean' geometries don't require 'trips' or 'shapes'

  expect_s3_class(tester(no_trips_gtfs, trip_id, "euclidean"), "sf")
  expect_s3_class(tester(no_shapes_gtfs, trip_id, "euclidean"), "sf")
  expect_s3_class(tester(no_trp_tripid_gtfs, trip_id, "euclidean"), "sf")
})

test_that("falls back to straight lines when shapes are unavailable", {
  no_trips_gtfs <- copy_gtfs_without_file(gtfs, "trips")
  no_shapes_gtfs <- copy_gtfs_without_file(gtfs, "shapes")
  no_trp_shapeid_gtfs <- copy_gtfs_without_field(gtfs, "trips", "shape_id")
  expected <- tester(trip_id = trip_id, method = "euclidean")

  for (feed in list(no_trips_gtfs, no_shapes_gtfs, no_trp_shapeid_gtfs)) {
    expect_warning(
      result <- tester(feed, trip_id),
      class = "gtfstools_shapes_unavailable"
    )
    expect_identical(result, expected)
  }
})

test_that("the deprecated 'file' argument is mapped to 'method'", {
  expect_warning(
    result <- get_trip_geometry(gtfs, trip_id, file = "stop_times"),
    class = "deprecated_file"
  )
  expect_identical(result, tester(trip_id = trip_id, method = "euclidean"))

  expect_warning(
    result <- get_trip_geometry(gtfs, trip_id, file = "shapes"),
    class = "deprecated_file"
  )
  expect_identical(result, tester(trip_id = trip_id))

  expect_warning(
    result <- get_trip_geometry(
      gtfs,
      trip_id,
      file = c("shapes", "stop_times")
    ),
    class = "deprecated_file"
  )
  expect_identical(result, tester(trip_id = trip_id))
})

test_that("returns the geometries of correct 'trip_id's", {
  for (method in c("shapes", "euclidean")) {
    geometries <- tester(method = method)
    expect_identical(
      sort(geometries$trip_id),
      sort(unique(gtfs$stop_times$trip_id))
    )
    expect_false(any(duplicated(geometries$trip_id)))
  }

  # only the geometries of (valid) trip_ids are generated

  selected_trip_ids <- c("CPTM L07-0", "ola")
  suppressWarnings(
    geom_selected_trip_ids <- tester(trip_id = selected_trip_ids)
  )
  expect_identical(geom_selected_trip_ids$trip_id, "CPTM L07-0")

  # trips listed in 'trips' but not in 'stop_times' are not returned

  extra_trip_gtfs <- read_gtfs(data_path)
  extra_trip_gtfs$trips <- rbind(
    extra_trip_gtfs$trips,
    extra_trip_gtfs$trips[trip_id == "CPTM L07-0"][, trip_id := "extra"]
  )
  expect_false("extra" %chin% tester(extra_trip_gtfs)$trip_id)
})

test_that("raises warnings if a non_existent 'trip_id' is given", {
  expect_warning(tester(trip_id = c("CPTM L07-0", "ola")))

  # the check is made against 'stop_times'

  extra_trip_gtfs <- read_gtfs(data_path)
  extra_trip_gtfs$trips <- rbind(
    extra_trip_gtfs$trips,
    extra_trip_gtfs$trips[trip_id == "CPTM L07-0"][, trip_id := "extra"]
  )
  expect_warning(tester(extra_trip_gtfs, trip_id = "extra"))
})

test_that("geometry lengths match the lengths from get_trip_length()", {
  old_s2 <- suppressMessages(sf::sf_use_s2(TRUE))
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)

  for (feed in list(gtfs, poa_gtfs)) {
    for (method in c("shapes", "euclidean")) {
      geometries <- tester(feed, method = method)
      lengths <- get_trip_length(feed, method = method, unit = "m")
      expect_identical(geometries$trip_id, lengths$trip_id)

      has_length <- !is.na(lengths$length)
      expect_true(any(has_length))
      expect_equal(
        as.numeric(sf::st_length(geometries))[has_length],
        lengths$length[has_length],
        tolerance = 1e-6
      )
    }
  }
})

test_that("geometries along shapes start and end at the snapped stops", {
  # straight shape along the equator, with stops slightly off the shape

  feed <- synthetic_feed(
    shape_lon = c(0, 0.05, 0.1),
    shape_lat = c(0, 0, 0),
    stop_lon = c(0.02, 0.05, 0.08),
    stop_lat = c(0.0001, -0.0001, 0.0001)
  )
  expect_equal(
    coords(tester(feed)),
    cbind(c(0.02, 0.05, 0.08), c(0, 0, 0))
  )

  # the euclidean geometry links the stops themselves

  expect_equal(
    coords(tester(feed, method = "euclidean")),
    cbind(c(0.02, 0.05, 0.08), c(0.0001, -0.0001, 0.0001))
  )

  # out-and-back shape on the same street. the third stop is located on the
  # way back, so the geometry goes to the end of the shape and comes back

  out_and_back_lon <- c(0, 0.05, 0.1, 0.05, 0)
  out_and_back_lat <- c(0, 0, 0, 0, 0)

  feed <- synthetic_feed(
    out_and_back_lon,
    out_and_back_lat,
    stop_lon = c(0.02, 0.08, 0.05),
    stop_lat = c(0, 0, 0)
  )
  geometry <- coords(tester(feed))
  expect_equal(geometry[1, ], c(0.02, 0))
  expect_equal(geometry[nrow(geometry), ], c(0.05, 0))
  expect_true(any(geometry[, 1] == 0.1))
  expect_equal(
    as.numeric(sf::st_length(tester(feed))),
    get_trip_length(feed, unit = "m")$length,
    tolerance = 1e-6
  )

  # closed loop whose first and last stops are the same stop: the geometry is
  # the entire loop

  loop_lon <- c(0, 0, 0.01, 0.01, 0)
  loop_lat <- c(0, 0.01, 0.01, 0, 0)

  feed <- synthetic_feed(
    loop_lon,
    loop_lat,
    stop_lon = c(0, 0.01, 0),
    stop_lat = c(0, 0.01, 0)
  )
  expect_equal(coords(tester(feed)), unname(cbind(loop_lon, loop_lat)))
})

test_that("ignores shape points and stops with missing coordinates", {
  # shape points with missing coordinates are ignored

  na_shape_gtfs <- read_gtfs(data_path)
  na_shape_gtfs$shapes[
    shape_id == "17846" & shape_pt_sequence %in% c(10L, 200L),
    shape_pt_lat := NA
  ]
  removed_gtfs <- read_gtfs(data_path)
  removed_gtfs$shapes <- removed_gtfs$shapes[
    !(shape_id == "17846" & shape_pt_sequence %in% c(10L, 200L))
  ]
  expect_identical(
    tester(na_shape_gtfs, trip_id),
    tester(removed_gtfs, trip_id)
  )

  # stops with missing coordinates, or not listed in 'stops', are ignored

  trip_stops <- gtfs$stop_times[trip_id == "CPTM L07-0"]$stop_id

  na_stop_gtfs <- read_gtfs(data_path)
  na_stop_gtfs$stops[stop_id == trip_stops[1], stop_lat := NA]
  na_stop_gtfs$stops <- na_stop_gtfs$stops[stop_id != trip_stops[5]]

  removed_gtfs <- read_gtfs(data_path)
  removed_gtfs$stop_times <- removed_gtfs$stop_times[
    !(trip_id == "CPTM L07-0" & stop_id %chin% trip_stops[c(1, 5)])
  ]

  for (method in c("shapes", "euclidean")) {
    result <- tester(na_stop_gtfs, trip_id, method)
    expect_false(anyNA(coords(result)))
    expect_identical(result, tester(removed_gtfs, trip_id, method))
  }

  expect_identical(
    nrow(coords(tester(na_stop_gtfs, trip_id, "euclidean"))),
    length(trip_stops) - 2L
  )
})

test_that("trips without a usable geometry get an empty geometry", {
  # trips not linked to a usable shape, with a warning

  bad_gtfs <- read_gtfs(data_path)
  bad_trips <- c("CPTM L07-0", "CPTM L07-1", "CPTM L08-0")
  bad_gtfs$trips[trip_id == bad_trips[1], shape_id := ""]
  bad_gtfs$trips[trip_id == bad_trips[2], shape_id := "nonexistent"]
  identical_shape <- bad_gtfs$trips[trip_id == bad_trips[3]]$shape_id
  bad_gtfs$shapes[
    shape_id == identical_shape,
    `:=`(shape_pt_lat = -23.5, shape_pt_lon = -46.6)
  ]

  expect_warning(
    result <- tester(bad_gtfs, c(bad_trips, "CPTM L09-0")),
    class = "gtfstools_trips_without_shape"
  )
  expect_identical(result$trip_id, sort(c(bad_trips, "CPTM L09-0")))
  expect_identical(
    sf::st_is_empty(result),
    result$trip_id %chin% bad_trips
  )
  expect_identical(class(result$geometry), c("sfc_LINESTRING", "sfc"))

  # a trip whose 'shape_id' is blank gets a single, empty row

  expect_warning(
    result <- tester(bad_gtfs, "CPTM L07-0"),
    class = "gtfstools_trips_without_shape"
  )
  expect_identical(nrow(result), 1L)
  expect_true(sf::st_is_empty(result))
  expect_identical(class(result$geometry), c("sfc_LINESTRING", "sfc"))

  # transformed geometries keep the empty ones

  suppressWarnings(
    projected <- tester(bad_gtfs, c(bad_trips, "CPTM L09-0"), crs = 31983)
  )
  suppressWarnings(
    wgs <- tester(bad_gtfs, c(bad_trips, "CPTM L09-0"))
  )
  expect_identical(projected, sf::st_transform(wgs, 31983))

  # trips with a single stop get an empty geometry along the shapes and a
  # single-point one with straight lines

  one_stop_gtfs <- read_gtfs(data_path)
  one_stop_gtfs$stop_times <- one_stop_gtfs$stop_times[
    trip_id != "CPTM L07-0" | stop_sequence == 1L
  ]
  result <- tester(one_stop_gtfs, trip_id)
  expect_true(sf::st_is_empty(result))
  result <- tester(one_stop_gtfs, trip_id, "euclidean")
  expect_identical(nrow(coords(result)), 1L)

  # trips whose stops all have missing coordinates

  na_gtfs <- read_gtfs(data_path)
  na_stops <- na_gtfs$stop_times[trip_id == "CPTM L07-0"]$stop_id
  na_gtfs$stops[stop_id %chin% na_stops, stop_lon := NA]

  for (method in c("shapes", "euclidean")) {
    result <- tester(na_gtfs, trip_id, method)
    expect_identical(nrow(result), 1L)
    expect_true(sf::st_is_empty(result))
    expect_identical(class(result$geometry), c("sfc_LINESTRING", "sfc"))
  }
})

test_that("outputs an 'sf' object with correct crs", {
  for (method in c("shapes", "euclidean")) {
    # crs is WGS by default

    point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326)
    sf_geom <- tester(trip_id = "CPTM L07-0", method = method)
    expect_s3_class(sf_geom, "sf")
    expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

    # 'crs' can be an integer or crs object

    point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4674)
    sf_geom <- tester(trip_id = "CPTM L07-0", method = method, crs = 4674)
    expect_s3_class(sf_geom, "sf")
    expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

    sf_geom <- tester(
      trip_id = "CPTM L07-0",
      method = method,
      crs = sf::st_crs(point)
    )
    expect_s3_class(sf_geom, "sf")
    expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

    # should work even when all 'trip_id's given are not present in the gtfs

    point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326)
    expect_warning(sf_geom <- tester(trip_id = "ola", method = method))
    expect_s3_class(sf_geom, "sf")
    expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

    point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4674)
    expect_warning(
      sf_geom <- tester(trip_id = "ola", method = method, crs = 4674)
    )
    expect_s3_class(sf_geom, "sf")
    expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

    # and when trip_id = character(0)

    point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326)
    sf_geom <- tester(trip_id = character(0), method = method)
    expect_s3_class(sf_geom, "sf")
    expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))

    point <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 4674)
    sf_geom <- tester(trip_id = character(0), method = method, crs = 4674)
    expect_s3_class(sf_geom, "sf")
    expect_identical(sf::st_crs(sf_geom), sf::st_crs(point))
  }
})

test_that("projected geometries equal the transformed WGS 84 geometries", {
  for (method in c("shapes", "euclidean")) {
    expected <- sf::st_transform(tester(poa_gtfs, method = method), 31982)
    expect_identical(
      tester(poa_gtfs, method = method, crs = 31982),
      expected
    )
    expect_identical(
      tester(poa_gtfs, method = method, crs = sf::st_crs(31982)),
      expected
    )

    # subset of trips

    trips <- c("CPTM L07-0", "CPTM L07-1", "CPTM L08-0")
    expect_identical(
      tester(trip_id = trips, method = method, crs = 31983),
      sf::st_transform(tester(trip_id = trips, method = method), 31983)
    )
  }
})

test_that("outputs an 'sf' object with correct column types", {
  for (method in c("shapes", "euclidean")) {
    sf_geom <- tester(trip_id = "CPTM L07-0", method = method)
    expect_s3_class(sf_geom, "sf")
    expect_identical(names(sf_geom), c("trip_id", "geometry"))
    expect_equal(class(sf_geom$trip_id), "character")
    expect_identical(class(sf_geom$geometry), c("sfc_LINESTRING", "sfc"))

    # should work even when all 'trip_id's given are not present in the gtfs

    expect_warning(sf_geom <- tester(trip_id = "ola", method = method))
    expect_s3_class(sf_geom, "sf")
    expect_identical(names(sf_geom), c("trip_id", "geometry"))
    expect_equal(class(sf_geom$trip_id), "character")
    expect_identical(class(sf_geom$geometry), c("sfc_LINESTRING", "sfc"))

    # and when trip_id = character(0)

    sf_geom <- tester(trip_id = character(0), method = method)
    expect_s3_class(sf_geom, "sf")
    expect_identical(nrow(sf_geom), 0L)
    expect_equal(class(sf_geom$trip_id), "character")
    expect_identical(class(sf_geom$geometry), c("sfc_LINESTRING", "sfc"))
  }
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(data_path)
  gtfs <- read_gtfs(data_path)
  expect_identical(original_gtfs, gtfs)

  for (method in c("shapes", "euclidean")) {
    for (sort_sequence in c(TRUE, FALSE)) {
      sf_geom <- tester(method = method, sort_sequence = sort_sequence)
      sf_geom <- tester(
        trip_id = "CPTM L07-0",
        method = method,
        sort_sequence = sort_sequence
      )
      expect_identical(original_gtfs, gtfs)
    }
  }
})

test_that("sort_sequence works correctly", {
  unordered_gtfs <- read_gtfs(data_path)
  unordered_gtfs$shapes <- gtfs$shapes[shape_id == "17846"]
  unordered_gtfs$shapes <- unordered_gtfs$shapes[c(200:547, 1:199)]
  unordered_gtfs$stop_times <- gtfs$stop_times[trip_id == "CPTM L07-0"]
  unordered_gtfs$stop_times <- unordered_gtfs$stop_times[c(10:18, 1:9)]

  for (method in c("shapes", "euclidean")) {
    geoms <- tester(trip_id = trip_id, method = method)

    unordered_geoms <- tester(
      unordered_gtfs,
      trip_id,
      method,
      sort_sequence = FALSE
    )
    expect_false(identical(unordered_geoms, geoms))

    ordered_geoms <- tester(unordered_gtfs, trip_id, method)
    expect_identical(ordered_geoms, geoms)

    # sort_sequence defaults to TRUE (#94)
    default_geoms <- get_trip_geometry(unordered_gtfs, trip_id, method)
    expect_identical(default_geoms, geoms)
  }
})

test_that("geometries along shapes handle repeated points and shape ends", {
  # straight shape along the equator whose middle point is repeated, so that
  # some points have the same cumulative distance

  shape_lon <- c(0, 0.05, 0.05, 0.05, 0.1)
  shape_lat <- c(0, 0, 0, 0, 0)

  # the repeated points are kept between the first and last stops

  feed <- synthetic_feed(shape_lon, shape_lat, c(0.02, 0.08), c(0, 0))
  expect_equal(
    coords(tester(feed)),
    cbind(c(0.02, 0.05, 0.05, 0.05, 0.08), 0)
  )

  # a trip starting at the repeated point doesn't include it again

  feed <- synthetic_feed(shape_lon, shape_lat, c(0.05, 0.08), c(0, 0))
  expect_equal(coords(tester(feed)), cbind(c(0.05, 0.08), 0))

  # a trip whose stops are located at the same point gets a degenerate line

  feed <- synthetic_feed(shape_lon, shape_lat, c(0.02, 0.02), c(0, 0))
  expect_equal(coords(tester(feed)), cbind(c(0.02, 0.02), 0))

  # a stop beyond the end of the shape is placed at the shape's last point

  feed <- synthetic_feed(shape_lon, shape_lat, c(0.02, 0.12), c(0, 0))
  expect_equal(
    coords(tester(feed)),
    cbind(c(0.02, 0.05, 0.05, 0.05, 0.1), 0)
  )
})

test_that("results don't depend on the number of threads", {
  ber_gtfs <- read_gtfs(
    system.file("extdata/ber_gtfs.zip", package = "gtfstools")
  )

  old_threads <- data.table::setDTthreads(1)
  on.exit(data.table::setDTthreads(old_threads), add = TRUE)
  one_thread <- list(tester(gtfs), tester(ber_gtfs))

  data.table::setDTthreads(2)
  skip_if(data.table::getDTthreads() < 2, "Can't use more than one thread.")
  two_threads <- list(tester(gtfs), tester(ber_gtfs))

  expect_identical(two_threads, one_thread)
})
