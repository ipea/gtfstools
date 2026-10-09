spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)

# a small feed with stops listed out of order, a duplicated stop_id ("a",
# whose first entry must be used), a stop without latitude ("d"), a stop
# not visited by any trip ("z") and a visited stop missing from stops
# ("ghost")

small_gtfs <- gtfsio::new_gtfs(
  list(
    stops = data.table::data.table(
      stop_id = c("c", "a", "b", "a", "d", "z"),
      stop_lat = c(0, 0, 1, 5, NA, 3),
      stop_lon = c(0, 1, 0, 5, 2, 3)
    ),
    trips = data.table::data.table(
      route_id = c("R1", "R2"),
      trip_id = c("T1", "T2")
    ),
    stop_times = data.table::data.table(
      trip_id = c("T1", "T1", "T1", "T1", "T2", "T2"),
      stop_id = c("c", "a", "b", "ghost", "d", "a"),
      stop_sequence = c(1:4, 1:2)
    )
  ),
  "dt_gtfs"
)

tester <- function(gtfs = small_gtfs, trip_id = NULL, route_id = NULL) {
  get_stop_distances(gtfs, trip_id, route_id)
}

# the coordinates of the stops of the small feed, as they must be used

coords <- list(a = c(0, 1), b = c(1, 0), c = c(0, 0), d = c(NA, 2))

expected_distances <- function(from, to) {
  data.table::data.table(
    from_stop_id = from,
    to_stop_id = to,
    distance = rcpp_distance_haversine(
      vapply(coords[from], `[`, numeric(1), 1),
      vapply(coords[from], `[`, numeric(1), 2),
      vapply(coords[to], `[`, numeric(1), 1),
      vapply(coords[to], `[`, numeric(1), 2)
    )
  )
}


# tests -------------------------------------------------------------------


test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(small_gtfs)))
  expect_error(tester(trip_id = 1))
  expect_error(tester(route_id = NA_character_))
  expect_error(tester(copy_gtfs_without_field(small_gtfs, "stops", "stop_lat")))
  expect_error(tester(copy_gtfs_without_file(small_gtfs, "stop_times")))
})

test_that("returns the distances between all pairs of stops", {
  result <- tester(spo_gtfs)
  expect_s3_class(result, "data.table")
  expect_named(result, c("from_stop_id", "to_stop_id", "distance"))

  n_stops <- nrow(get_stops(spo_gtfs))
  expect_identical(nrow(result), as.integer(choose(n_stops, 2)))

  # each pair listed once, in order, with the right coordinates. the
  # duplicated "a" uses its first entry, "d" has NA distances, and "z" (not
  # visited) and "ghost" (not in stops) are left out

  expect_identical(
    tester(),
    expected_distances(
      from = c("a", "a", "a", "b", "b", "c"),
      to = c("b", "c", "d", "c", "d", "d")
    )
  )
})

test_that("considers only the stops of the given trips and routes", {
  expect_identical(
    tester(trip_id = "T1"),
    expected_distances(from = c("a", "a", "b"), to = c("b", "c", "c"))
  )
  expect_identical(
    tester(route_id = "R2"),
    expected_distances(from = "a", to = "d")
  )

  expect_warning(
    result <- tester(trip_id = c("T2", "unknown")),
    class = "gtfstools_invalid_trip_id"
  )
  expect_identical(result, tester(trip_id = "T2"))

  # fewer than 2 stops result in an empty table

  empty_result <- tester(trip_id = character(0))
  expect_identical(empty_result, tester()[0])
  expect_identical(tester(trip_id = "T1", route_id = "R2"), empty_result)
})

test_that("warns if the distances may use a lot of memory", {
  expect_no_warning(tester(spo_gtfs))

  # the threshold is lowered, so that the small feed's 6 pairs exceed it

  testthat::local_mocked_bindings(max_stop_pairs_without_warning = function() 5)
  expect_warning(
    result <- tester(),
    class = "gtfstools_many_stops_warning"
  )
  expect_identical(nrow(result), 6L)
  expect_no_warning(tester(trip_id = "T1"))
})

test_that("raises an error if there are too many pairs of stops", {
  n_stops <- 65537L
  stop_ids <- as.character(seq_len(n_stops))
  large_gtfs <- gtfsio::new_gtfs(
    list(
      stops = data.table::data.table(
        stop_id = stop_ids,
        stop_lat = 0,
        stop_lon = 0
      ),
      stop_times = data.table::data.table(trip_id = "T1", stop_id = stop_ids)
    ),
    "dt_gtfs"
  )

  expect_error(tester(large_gtfs), class = "gtfstools_too_many_stops")
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(spo_path)
  gtfs <- read_gtfs(spo_path)
  expect_identical(original_gtfs, gtfs)

  result <- tester(gtfs, route_id = "CPTM L07")
  expect_identical(original_gtfs, gtfs)
})
