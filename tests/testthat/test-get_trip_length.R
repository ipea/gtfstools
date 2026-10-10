spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)

tester <- function(gtfs = spo_gtfs,
                   trip_id = NULL,
                   method = "shapes",
                   by = "trip",
                   unit = "km",
                   sort_sequence = TRUE) {
  get_trip_length(gtfs, trip_id, method, by, unit, sort_sequence)
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

# tests -------------------------------------------------------------------

test_that("raises errors due to incorrect input types and missing fields", {
  expect_error(tester(unclass(spo_gtfs)))
  expect_error(tester(trip_id = NA))
  expect_error(tester(trip_id = factor("CPTM L07-0")))
  expect_error(tester(method = "straight"))
  expect_error(tester(method = c("shapes", "euclidean")))
  expect_error(tester(by = "stop"))
  expect_error(tester(unit = "mi"))
  expect_error(tester(sort_sequence = NA))

  # missing required tables and fields

  no_stops_gtfs <- copy_gtfs_without_file(spo_gtfs, "stops")
  expect_error(tester(no_stops_gtfs), class = "missing_required_file")
  no_seq_gtfs <- copy_gtfs_without_field(
    spo_gtfs,
    "stop_times",
    "stop_sequence"
  )
  expect_error(tester(no_seq_gtfs), class = "missing_required_field")
  expect_s3_class(tester(no_seq_gtfs, sort_sequence = FALSE), "data.table")

  # 'shapes' is present but misses a required field

  no_shape_seq_gtfs <- copy_gtfs_without_field(
    spo_gtfs,
    "shapes",
    "shape_pt_sequence"
  )
  expect_error(tester(no_shape_seq_gtfs), class = "missing_required_field")
})

test_that("falls back to euclidean lengths when there are no shapes", {
  euclidean_lengths <- tester(method = "euclidean")

  no_shapes_gtfs <- copy_gtfs_without_file(spo_gtfs, "shapes")
  expect_warning(
    result <- tester(no_shapes_gtfs),
    class = "gtfstools_shapes_unavailable"
  )
  expect_identical(result, euclidean_lengths)

  no_shape_id_gtfs <- copy_gtfs_without_field(spo_gtfs, "trips", "shape_id")
  expect_warning(
    result <- tester(no_shape_id_gtfs),
    class = "gtfstools_shapes_unavailable"
  )
  expect_identical(result, euclidean_lengths)

  expect_silent(tester(no_shapes_gtfs, method = "euclidean"))
})

test_that("the deprecated 'file' argument still works", {
  old_s2 <- suppressMessages(sf::sf_use_s2(TRUE))
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)

  expect_warning(
    from_stop_times <- get_trip_length(spo_gtfs, file = "stop_times"),
    class = "deprecated_file"
  )
  expect_identical(from_stop_times, tester(method = "euclidean"))

  # straight-line lengths are the same as the ones calculated by the previous
  # implementation of the function, based on sf::st_length()

  trip <- "CPTM L07-0"
  stops <- spo_gtfs$stops[
    match(spo_gtfs$stop_times[trip_id == trip]$stop_id, stop_id)
  ]
  previous_length <- as.numeric(
    sf::st_length(
      sf::st_sfc(
        sf::st_linestring(as.matrix(stops[, .(stop_lon, stop_lat)])),
        crs = 4326
      )
    )
  ) / 1000
  expect_equal(
    from_stop_times[trip_id == trip]$length,
    previous_length,
    tolerance = 1e-8
  )

  expect_warning(
    from_shapes <- get_trip_length(spo_gtfs, file = "shapes"),
    class = "deprecated_file"
  )
  expect_identical(from_shapes, tester())

  expect_warning(
    get_trip_length(spo_gtfs, file = c("shapes", "stop_times")),
    class = "deprecated_file"
  )
  expect_error(get_trip_length(spo_gtfs, file = "shape"))
})

test_that("results in data.tables with the right columns and types", {
  trip_result <- tester()
  expect_s3_class(trip_result, "data.table")
  expect_identical(names(trip_result), c("trip_id", "length"))
  expect_type(trip_result$length, "double")

  segment_result <- tester(by = "segment")
  expect_identical(
    names(segment_result),
    c("trip_id", "segment", "from_stop_id", "to_stop_id", "length")
  )
  expect_type(segment_result$segment, "integer")
  expect_type(segment_result$length, "double")

  expect_true(all(segment_result$length >= 0))
})

test_that("doesn't change the given gtfs", {
  original_gtfs <- read_gtfs(spo_path)
  gtfs <- read_gtfs(spo_path)
  expect_identical(original_gtfs, gtfs)

  for (method in c("shapes", "euclidean")) {
    for (sort_sequence in c(TRUE, FALSE)) {
      for (trip_id in list(NULL, "CPTM L07-0")) {
        result <- tester(
          gtfs,
          trip_id = trip_id,
          method = method,
          by = "segment",
          sort_sequence = sort_sequence
        )
        expect_identical(original_gtfs, gtfs)
      }
    }
  }
})

test_that("euclidean distances match the distances calculated by sf/s2", {
  old_s2 <- suppressMessages(sf::sf_use_s2(TRUE))
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)

  result <- tester(
    trip_id = "CPTM L07-0",
    method = "euclidean",
    by = "segment",
    unit = "m"
  )

  stops <- spo_gtfs$stops
  from <- stops[match(result$from_stop_id, stops$stop_id)]
  to <- stops[match(result$to_stop_id, stops$stop_id)]
  to_sf <- function(x) {
    sf::st_as_sf(x, coords = c("stop_lon", "stop_lat"), crs = 4326)
  }
  expected <- as.numeric(
    sf::st_distance(to_sf(from), to_sf(to), by_element = TRUE)
  )
  expect_equal(result$length, expected)

  # the trip distance is the sum of its segments

  trip_result <- tester(
    trip_id = "CPTM L07-0",
    method = "euclidean",
    unit = "m"
  )
  expect_equal(trip_result$length, sum(expected))
})

test_that("lengths along the shape are not longer than the shape", {
  trip_lengths <- tester(unit = "m")
  shape_lengths <- get_shape_length(spo_gtfs, unit = "m")
  trip_lengths[spo_gtfs$trips, on = "trip_id", shape_id := i.shape_id]
  compared <- trip_lengths[shape_lengths, on = "shape_id", nomatch = NULL]

  expect_true(all(compared$length <= compared$i.length * (1 + 1e-9)))
  expect_true(all(compared$length > 0.5 * compared$i.length))
})

test_that("stops are located along synthetic shapes correctly", {
  # straight shape along the equator, with stops slightly off the shape

  feed <- synthetic_feed(
    shape_lon = c(0, 0.05, 0.1),
    shape_lat = c(0, 0, 0),
    stop_lon = c(0.02, 0.05, 0.08),
    stop_lat = c(0.0001, -0.0001, 0.0001)
  )
  result <- tester(feed, by = "segment", unit = "m")
  expect_equal(result$length, c(arc(0.03), arc(0.03)))

  # out-and-back shape on the same street. the first trip only serves the
  # outbound stops, the second one goes to the end and comes back, so the
  # third stop must be located on the way back

  out_and_back_lon <- c(0, 0.05, 0.1, 0.05, 0)
  out_and_back_lat <- c(0, 0, 0, 0, 0)

  feed <- synthetic_feed(
    out_and_back_lon,
    out_and_back_lat,
    stop_lon = c(0.02, 0.05, 0.08),
    stop_lat = c(0, 0, 0)
  )
  result <- tester(feed, by = "segment", unit = "m")
  expect_equal(result$length, c(arc(0.03), arc(0.03)))

  feed <- synthetic_feed(
    out_and_back_lon,
    out_and_back_lat,
    stop_lon = c(0.02, 0.08, 0.05),
    stop_lat = c(0, 0, 0)
  )
  result <- tester(feed, by = "segment", unit = "m")
  expect_equal(result$length, c(arc(0.06), arc(0.02) + arc(0.05)))

  # closed loop whose first and last stops are the same stop

  loop_lon <- c(0, 0, 0.01, 0.01, 0)
  loop_lat <- c(0, 0.01, 0.01, 0, 0)

  feed <- synthetic_feed(
    loop_lon,
    loop_lat,
    stop_lon = c(0, 0.01, 0),
    stop_lat = c(0, 0.01, 0)
  )
  loop_length <- sum(
    rcpp_distance_haversine(
      loop_lat[-5],
      loop_lon[-5],
      loop_lat[-1],
      loop_lon[-1]
    )
  )
  result <- tester(feed, by = "segment", unit = "m")
  expect_identical(result$from_stop_id[1], result$to_stop_id[2])
  expect_equal(sum(result$length), loop_length)
  expect_equal(result$length[1], loop_length / 2, tolerance = 1e-6)

  # stops slightly out of order along the shape (the second stop is 0.001
  # degrees before the first one) are handled in the same way regardless of
  # how the shape is split into points: the result may only vary by the gap
  # between the out-of-order stops, which can't be resolved

  lengths_by_split <- vapply(
    list(c(0, 0.02), c(0, 0.01, 0.02), seq(0, 0.02, by = 0.001)),
    FUN.VALUE = numeric(1),
    FUN = function(shape_lon) {
      feed <- synthetic_feed(
        shape_lon,
        shape_lat = rep(0, length(shape_lon)),
        stop_lon = c(0.012, 0.011, 0.019),
        stop_lat = c(0, 0, 0)
      )
      tester(feed, unit = "m")$length
    }
  )
  expect_equal(lengths_by_split[1], arc(0.007))
  expect_equal(lengths_by_split[2], arc(0.007))
  expect_true(
    all(lengths_by_split >= arc(0.007) - 1e-6) &&
      all(lengths_by_split <= arc(0.008) + 1e-6)
  )

  # shape crossing the antimeridian

  feed <- synthetic_feed(
    shape_lon = c(179.98, -179.98),
    shape_lat = c(0, 0),
    stop_lon = c(179.99, -179.99),
    stop_lat = c(0, 0)
  )
  result <- tester(feed, unit = "m")
  expect_equal(result$length, arc(0.02))
})

test_that("segments are numbered as in get_trip_segment_duration()", {
  trips <- c("CPTM L07-0", "CPTM L07-1")
  compare_numbering <- function(gtfs, sort_sequence = TRUE) {
    distances <- suppressWarnings(
      tester(
        gtfs,
        trips,
        by = "segment",
        sort_sequence = sort_sequence
      )
    )
    durations <- get_trip_segment_duration(
      gtfs,
      trips,
      sort_sequence = sort_sequence
    )
    expect_identical(distances$trip_id, durations$trip_id)
    expect_identical(distances$segment, durations$segment)
    return(distances)
  }

  compare_numbering(spo_gtfs)

  # interleaved rows, without sorting

  interleaved_gtfs <- read_gtfs(spo_path)
  st <- interleaved_gtfs$stop_times[trip_id %chin% trips]
  data.table::setorderv(st, c("stop_sequence", "trip_id"))
  interleaved_gtfs$stop_times <- st
  compare_numbering(interleaved_gtfs, sort_sequence = FALSE)

  # a stop with missing coordinates results in NA distances for the segments
  # around it and for its trip, without changing the numbering

  na_gtfs <- read_gtfs(spo_path)
  na_stop <- na_gtfs$stop_times[trip_id == trips[1]]$stop_id[3]
  na_gtfs$stops <- data.table::copy(na_gtfs$stops)
  na_gtfs$stops[stop_id == na_stop, stop_lat := NA]

  for (method in c("shapes", "euclidean")) {
    distances <- tester(na_gtfs, trips[1], method = method, by = "segment")
    expect_identical(which(is.na(distances$length)), c(2L, 3L))
    expect_true(is.na(tester(na_gtfs, trips[1], method = method)$length))
  }
  compare_numbering(na_gtfs)

  # duplicated stop_ids in 'stops' don't duplicate rows

  dup_gtfs <- read_gtfs(spo_path)
  dup_gtfs$stops <- rbind(dup_gtfs$stops, dup_gtfs$stops[1:5])
  expect_identical(compare_numbering(dup_gtfs), compare_numbering(spo_gtfs))
})

test_that("trips without a usable shape have NA distances and a warning", {
  bad_gtfs <- read_gtfs(spo_path)
  bad_gtfs$trips <- data.table::copy(bad_gtfs$trips)
  bad_gtfs$shapes <- data.table::copy(bad_gtfs$shapes)

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
  expect_true(all(is.na(result[trip_id %chin% bad_trips]$length)))
  expect_false(is.na(result[trip_id == "CPTM L09-0"]$length))

  # trip whose stops all have missing coordinates

  na_gtfs <- read_gtfs(spo_path)
  na_stops <- na_gtfs$stop_times[trip_id == "CPTM L09-0"]$stop_id
  na_gtfs$stops <- data.table::copy(na_gtfs$stops)
  na_gtfs$stops[stop_id %chin% na_stops, stop_lon := NA]
  expect_true(is.na(tester(na_gtfs, "CPTM L09-0")$length))
})

test_that("handles trips with a single stop and empty selections", {
  one_stop_gtfs <- read_gtfs(spo_path)
  one_stop_gtfs$stop_times <- one_stop_gtfs$stop_times[
    trip_id != "CPTM L07-0" | stop_sequence == 1L
  ]
  one_stop_gtfs$trips <- data.table::copy(one_stop_gtfs$trips)
  one_stop_gtfs$trips[trip_id == "CPTM L07-0", shape_id := ""]

  for (method in c("shapes", "euclidean")) {
    expect_identical(
      tester(one_stop_gtfs, "CPTM L07-0", method = method)$length,
      0
    )
    segments <- tester(
      one_stop_gtfs,
      "CPTM L07-0",
      method = method,
      by = "segment"
    )
    expect_identical(nrow(segments), 0L)
  }

  empty_trip <- tester(trip_id = character(0))
  expect_identical(nrow(empty_trip), 0L)
  expect_type(empty_trip$length, "double")

  empty_segment <- tester(trip_id = character(0), by = "segment")
  expect_identical(nrow(empty_segment), 0L)
  expect_type(empty_segment$segment, "integer")

  expect_warning(tester(trip_id = "nonexistent"))
})

test_that("unit argument converts distances correctly", {
  for (method in c("shapes", "euclidean")) {
    in_km <- tester(trip_id = "CPTM L07-0", method = method)
    in_m <- tester(trip_id = "CPTM L07-0", method = method, unit = "m")
    expect_equal(in_m$length, in_km$length * 1000)
  }
})

test_that("shape rows of different shapes may be interleaved", {
  # with sort_sequence = FALSE the points of each shape are used in the order
  # they appear, even if the rows of different shapes are interleaved

  sorted_gtfs <- read_gtfs(spo_path)
  data.table::setorderv(sorted_gtfs$shapes, c("shape_id", "shape_pt_sequence"))
  interleaved_gtfs <- read_gtfs(spo_path)
  interleaved_gtfs$shapes <- sorted_gtfs$shapes[
    order(data.table::rowid(shape_id), shape_id)
  ]
  expect_true(is.unsorted(interleaved_gtfs$shapes$shape_id))

  # the order of the trips in the result may change, but not their lengths

  interleaved_lengths <- tester(interleaved_gtfs, sort_sequence = FALSE)
  sorted_lengths <- tester(sorted_gtfs)
  expect_identical(
    interleaved_lengths[order(trip_id)],
    sorted_lengths[order(trip_id)]
  )
})

test_that("results don't depend on the number of threads", {
  ber_gtfs <- read_gtfs(
    system.file("extdata/ber_gtfs.zip", package = "gtfstools")
  )

  old_threads <- data.table::setDTthreads(1)
  on.exit(data.table::setDTthreads(old_threads), add = TRUE)
  one_thread <- list(
    tester(),
    tester(by = "segment"),
    tester(ber_gtfs)
  )

  data.table::setDTthreads(2)
  skip_if(data.table::getDTthreads() < 2, "Can't use more than one thread.")
  two_threads <- list(
    tester(),
    tester(by = "segment"),
    tester(ber_gtfs)
  )

  expect_identical(two_threads, one_thread)
})
