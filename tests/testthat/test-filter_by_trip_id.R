spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)
spo_trips <- c("CPTM L07-0", "2002-10-0")

ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
ggl_gtfs <- read_gtfs(ggl_path)
ggl_trips <- "AWE1"

tester <- function(gtfs = spo_gtfs, trip_id = spo_trips, keep = TRUE) {
  filter_by_trip_id(gtfs, trip_id, keep)
}

# tests -------------------------------------------------------------------

test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(spo_gtfs)))
  expect_error(tester(trip_id = factor(spo_trips)))
  expect_error(tester(trip_id = NA))
  expect_error(tester(keep = "TRUE"))
  expect_error(tester(keep = NA))
})

test_that("results in a dt_gtfs object", {
  dt_gtfs_class <- c("dt_gtfs", "gtfs", "list")

  smaller_gtfs <- tester()
  expect_s3_class(smaller_gtfs, dt_gtfs_class)
  expect_type(smaller_gtfs, "list")
  invisible(lapply(smaller_gtfs, expect_s3_class, "data.table"))
})

test_that("doesn't change given gtfs", {
  # (except for some tables' indices)

  original_gtfs <- read_gtfs(spo_path)
  gtfs <- read_gtfs(spo_path)
  expect_identical(original_gtfs, gtfs)

  smaller_gtfs <- tester(gtfs)
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})

test_that("'trip_id' and 'keep' arguments work correctly", {
  smaller_keeping <- tester(ggl_gtfs, ggl_trips)
  expect_true(all(smaller_keeping$trips$trip_id %chin% ggl_trips))
  expect_true(all(smaller_keeping$stop_times$trip_id %chin% ggl_trips))
  expect_true(all(smaller_keeping$frequencies$trip_id %chin% ggl_trips))

  smaller_not_keeping <- tester(ggl_gtfs, ggl_trips, keep = FALSE)
  expect_true(!any(smaller_not_keeping$trips$trip_id %chin% ggl_trips))
  expect_true(!any(smaller_not_keeping$stop_times$trip_id %chin% ggl_trips))
  expect_true(!any(smaller_not_keeping$frequencies$trip_id %chin% ggl_trips))
})

test_that("it doesn't throw warnings because of missing stations in 'stops'", {
  # this would be caused if 'stop_times' mentioned a stop not listed in 'stops'.
  # the current implementation suppress this eventual warning, but perhaps we
  # could throw a meaningful warning in the future
  expect_silent(tester(ggl_gtfs, ggl_trips))
})

test_that("the function filters berlin's gtfs correctly", {
  ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
  ber_gtfs <- read_gtfs(ber_path)
  ber_trips <- c("146389748", "146387802")

  smaller_ber <- tester(ber_gtfs, ber_trips)

  # trips
  expect_true(nrow(smaller_ber$trips) == 2)
  expect_true(all(smaller_ber$trips$trip_id %chin% ber_trips))

  # shapes
  relevant_shapes <- c("19", "4")
  expect_true(all(smaller_ber$shapes$shape_id %chin% relevant_shapes))

  # calendar and calendar_dates
  relevant_services <- c("3", "8")
  expect_true(all(smaller_ber$calendar$service_id %chin% relevant_services))
  expect_true(
    all(smaller_ber$calendar_dates$service_id %chin% relevant_services)
  )

  # routes
  relevant_routes <- c("1923_700", "1920_700")
  expect_true(all(smaller_ber$routes$route_id %chin% relevant_routes))

  # agency
  relevant_agency <- "92"
  expect_true(smaller_ber$agency$agency_id == relevant_agency)

  # stop_times
  expect_true(all(smaller_ber$stop_times$trip_id %chin% ber_trips))

  # stops
  relevant_stops <- unique(
    ber_gtfs$stop_times[trip_id %chin% ber_trips]$stop_id
  )
  relevant_stops <- get_parent_station(ber_gtfs, relevant_stops)$stop_id
  expect_true(all(smaller_ber$stops$stop_id %chin% relevant_stops))
})

test_that("the function filters sao paulo's gtfs correctly", {
  smaller_spo <- tester(spo_gtfs, spo_trips)

  # trips
  expect_true(all(smaller_spo$trips$trip_id %chin% spo_trips))

  # shapes
  relevant_shapes <- c("17846", "69240")
  expect_true(all(smaller_spo$shapes$shape_id %chin% relevant_shapes))

  # calendar and calendar_dates
  relevant_services <- "USD"
  expect_true(all(smaller_spo$calendar$service_id %chin% relevant_services))
  expect_true(
    all(smaller_spo$calendar_dates$service_id %chin% relevant_services)
  )

  # routes
  relevant_routes <- c("CPTM L07", "2002-10")
  expect_true(all(smaller_spo$routes$route_id %chin% relevant_routes))

  # agency
  relevant_agency <- "1"
  expect_true(all(smaller_spo$agency$agency_id %chin% relevant_agency))

  # stop_times
  expect_true(all(smaller_spo$stop_times$trip_id %chin% spo_trips))

  # stops
  relevant_stops <- unique(
    spo_gtfs$stop_times[trip_id %chin% spo_trips]$stop_id
  )
  expect_true(all(smaller_spo$stops$stop_id %chin% relevant_stops))

  # frequencies
  expect_true(all(smaller_spo$frequencies$trip_id %chin% spo_trips))
})

test_that("the function filters google's gtfs correctly", {
  smaller_ggl <- tester(ggl_gtfs, ggl_trips)

  # trips
  expect_true(all(smaller_ggl$trips$trip_id %chin% ggl_trips))

  # shapes - no rows because trips doesn't contain a shape_id column
  expect_true(nrow(smaller_ggl$shapes) == 0)

  # calendar and calendar_dates
  relevant_services <- "WE"
  expect_true(all(smaller_ggl$calendar$service_id %chin% relevant_services))
  expect_true(
    all(smaller_ggl$calendar_dates$service_id %chin% relevant_services)
  )

  # routes
  relevant_routes <- c("A")
  expect_true(all(smaller_ggl$routes$route_id %chin% relevant_routes))

  # fare_rules - no rows because the relevant_route is not listed in fare_rules
  expect_true(nrow(smaller_ggl$fare_rules) == 0)

  # fare_attributes - no rows either
  expect_true(nrow(smaller_ggl$fare_attributes) == 0)

  # agency
  relevant_agency <- "agency001"
  expect_true(all(smaller_ggl$agency$agency_id %chin% relevant_agency))

  # stop_times
  expect_true(all(smaller_ggl$stop_times$trip_id %chin% ggl_trips))

  # stops - no rows because stop_times' stops are not listed in 'stops'
  expect_true(nrow(smaller_ggl$stops) == 0)

  # transfers - no rows either
  expect_true(nrow(smaller_ggl$transfers) == 0)

  # pathways - no rows either
  expect_true(nrow(smaller_ggl$pathways) == 0)

  # levels - no rows either
  expect_true(nrow(smaller_ggl$levels) == 0)

  # frequencies
  expect_true(all(smaller_ggl$frequencies$trip_id %chin% ggl_trips))
})

test_that("behaves correctly when trip_id = character(0)", {
  ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
  ber_gtfs <- read_gtfs(ber_path)

  # if keep = TRUE, gtfs should be empty
  empty <- tester(ber_gtfs, character(0))
  n_rows <- vapply(empty, nrow, FUN.VALUE = integer(1))
  expect_true(all(n_rows == 0))

  # if keep = FALSE, gtfs should remain unchanged
  # this is actually not true because the calendar, calendar_dates and agency
  # tables contain ids not listed in the routes and trips tables, which and up
  # removed anyway (I like this behaviour, so not considering a bug)
  full <- tester(ber_gtfs, character(0), keep = FALSE)
  modified_ber <- read_gtfs(ber_path)
  modified_ber$calendar <- modified_ber$calendar[
    service_id %in% modified_ber$trips$service_id
  ]
  modified_ber$calendar_dates <- modified_ber$calendar_dates[
    service_id %in% modified_ber$trips$service_id
  ]
  modified_ber$agency <- modified_ber$agency[
    agency_id %in% modified_ber$routes$agency_id
  ]
  expect_identical(modified_ber, full)
})

test_that("agency table is kept intact if routes not list agency_id", {
  agencyless <- read_gtfs(spo_path)
  agencyless$routes[, agency_id := NULL]

  filtered_agencyless <- tester(agencyless)

  expect_identical(agencyless$agency, filtered_agencyless$agency)
})

test_that("drops fare_attributes whose fare_rules are all dropped by zone", {
  # fare "2" only applies to a zone that no kept stop is in
  gtfs <- read_gtfs(ggl_path)
  gtfs$stop_times[, stop_id := "F12S"]
  gtfs$stops[, zone_id := "z1"]
  gtfs$fare_rules <- data.table::data.table(
    fare_id = c("1", "2"),
    route_id = c("A", ""),
    origin_id = c("", "z9")
  )

  smaller_gtfs <- tester(gtfs, "AWE1")
  expect_identical(smaller_gtfs$fare_rules$fare_id, "1")
  expect_identical(smaller_gtfs$fare_attributes$fare_id, "1")
})
