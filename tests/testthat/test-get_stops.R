spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)
ggl_gtfs <- read_gtfs(ggl_path)

tester <- function(gtfs = spo_gtfs, trip_id = NULL, route_id = NULL) {
  get_stops(gtfs, trip_id, route_id)
}

# the stops visited by the given trips, computed independently of get_stops()

visited_stops <- function(gtfs, trips) {
  visited <- unique(gtfs$stop_times[trip_id %chin% trips]$stop_id)
  gtfs$stops[stop_id %chin% visited]
}


# tests -------------------------------------------------------------------


test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(spo_gtfs)))
  expect_error(tester(trip_id = 1))
  expect_error(tester(trip_id = NA_character_))
  expect_error(tester(route_id = factor("CPTM L07")))
  expect_error(tester(route_id = NA_character_))

  no_stop_times <- copy_gtfs_without_file(spo_gtfs, "stop_times")
  expect_error(tester(no_stop_times))

  no_stops <- copy_gtfs_without_file(spo_gtfs, "stops")
  expect_error(tester(no_stops))

  # 'trips' is only needed to filter by route_id
  no_trips <- copy_gtfs_without_file(spo_gtfs, "trips")
  expect_error(tester(no_trips, route_id = "CPTM L07"))
  expect_s3_class(tester(no_trips, trip_id = "CPTM L07-0"), "data.table")
})

test_that("results in a data.table with the stops columns", {
  stops <- tester(trip_id = "CPTM L07-0")
  expect_s3_class(stops, "data.table")
  expect_identical(names(stops), names(spo_gtfs$stops))
})

test_that("doesn't change given gtfs", {
  # (except for some tables' indices)

  original_gtfs <- read_gtfs(spo_path)
  gtfs <- read_gtfs(spo_path)
  expect_identical(original_gtfs, gtfs)

  invisible(get_stops(gtfs, trip_id = "CPTM L07-0", route_id = "CPTM L07"))
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})

test_that("returns the stops visited by the given trips and routes", {
  expect_identical(
    tester(trip_id = "CPTM L07-0"),
    visited_stops(spo_gtfs, "CPTM L07-0")
  )

  route_trips <- c("CPTM L07-0", "CPTM L07-1")
  expect_identical(
    tester(route_id = "CPTM L07"),
    visited_stops(spo_gtfs, route_trips)
  )

  # when both are given, only the trips of the given routes count. a trip of
  # another route visits no stop, without warnings

  expect_identical(
    tester(trip_id = c("CPTM L07-0", "CPTM L08-0"), route_id = "CPTM L07"),
    visited_stops(spo_gtfs, "CPTM L07-0")
  )
  expect_silent(
    other_route <- tester(trip_id = "CPTM L08-0", route_id = "CPTM L07")
  )
  expect_identical(nrow(other_route), 0L)
})

test_that("only returns visited stops, without their parents", {
  # a station that no trip visits is added as the parent of a visited stop

  gtfs <- read_gtfs(spo_path)
  gtfs$stops <- data.table::copy(gtfs$stops)
  visited_stop <- gtfs$stop_times$stop_id[1]
  gtfs$stops[, parent_station := ""]
  gtfs$stops[stop_id == visited_stop, parent_station := "station"]
  gtfs$stops <- rbind(
    gtfs$stops,
    data.table::data.table(
      stop_id = "station",
      location_type = 1L,
      parent_station = ""
    ),
    fill = TRUE
  )
  expect_false("station" %chin% gtfs$stop_times$stop_id)

  stops <- get_stops(gtfs)
  expect_identical(stops, gtfs$stops[stop_id != "station"])
})

test_that("works with stops and trips missing from other tables", {
  # in ggl, the stops visited by trips are not listed in 'stops'

  stops <- tester(ggl_gtfs)
  expect_identical(nrow(stops), 0L)
  expect_identical(names(stops), names(ggl_gtfs$stops))

  # with these stops added, all of them are visited. S4 is only visited by
  # AWD1, which is not listed in 'trips', so it is not returned when filtering
  # by route

  gtfs <- read_gtfs(ggl_path)
  gtfs$stops <- rbind(
    gtfs$stops,
    data.table::data.table(stop_id = paste0("S", 1:6)),
    fill = TRUE
  )
  expect_false("AWD1" %chin% gtfs$trips$trip_id)

  expect_identical(tester(gtfs)$stop_id, paste0("S", 1:6))
  expect_identical(
    tester(gtfs, route_id = "A")$stop_id,
    c("S1", "S2", "S3", "S5", "S6")
  )
  expect_identical(tester(gtfs, trip_id = "AWD1")$stop_id, paste0("S", 1:6))
})

test_that("ignores trips without trip_id when filtering by route", {
  # a trips entry of CPTM L07 without trip_id must not select the stop_times
  # entries without trip_id

  gtfs <- read_gtfs(spo_path)
  gtfs$trips <- rbind(
    gtfs$trips,
    data.table::data.table(trip_id = NA_character_, route_id = "CPTM L07"),
    fill = TRUE
  )
  gtfs$stop_times <- data.table::copy(gtfs$stop_times)
  gtfs$stop_times[trip_id == "CPTM L08-0", trip_id := NA_character_]

  expect_identical(
    get_stops(gtfs, route_id = "CPTM L07"),
    visited_stops(spo_gtfs, c("CPTM L07-0", "CPTM L07-1"))
  )
})

test_that("ignores stops without stop_id", {
  gtfs <- read_gtfs(spo_path)
  gtfs$stops <- rbind(
    gtfs$stops,
    data.table::data.table(stop_id = NA_character_),
    fill = TRUE
  )
  gtfs$stop_times <- data.table::copy(gtfs$stop_times)
  gtfs$stop_times$stop_id[1] <- NA_character_

  expect_false(anyNA(get_stops(gtfs)$stop_id))
})

test_that("warns about unknown ids", {
  expect_warning(
    stops <- tester(trip_id = c("CPTM L07-0", "x", "x")),
    class = "gtfstools_invalid_trip_id"
  )
  expect_identical(stops, visited_stops(spo_gtfs, "CPTM L07-0"))

  trip_warning <- tryCatch(
    tester(trip_id = c("x", "x")),
    warning = function(cnd) conditionMessage(cnd)
  )
  expect_identical(
    lengths(regmatches(trip_warning, gregexpr("\"x\"", trip_warning))),
    1L
  )

  expect_warning(
    stops <- tester(route_id = c("x", "x")),
    class = "gtfstools_invalid_route_id"
  )
  expect_identical(nrow(stops), 0L)

  route_warning <- tryCatch(
    tester(route_id = c("x", "x")),
    warning = function(cnd) conditionMessage(cnd)
  )
  expect_identical(
    lengths(regmatches(route_warning, gregexpr("\"x\"", route_warning))),
    1L
  )
})

test_that("empty vectors select nothing", {
  expect_silent(stops <- tester(trip_id = character(0)))
  expect_identical(nrow(stops), 0L)

  expect_silent(stops <- tester(route_id = character(0)))
  expect_identical(nrow(stops), 0L)
})
