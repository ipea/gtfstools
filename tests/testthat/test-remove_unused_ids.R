spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")

ber_gtfs <- read_gtfs(ber_path)
ggl_gtfs <- read_gtfs(ggl_path)

# ggl's stop_times refer to stops absent from 'stops', so we make its only
# trip with stop_times (AWE1) serve the F12S platform of the F12 station
served_ggl <- function() {
  gtfs <- read_gtfs(ggl_path)
  gtfs$stop_times[, stop_id := "F12S"]
  gtfs
}

# tests -------------------------------------------------------------------

test_that("raises errors due to incorrect input", {
  expect_error(remove_unused_ids(unclass(ggl_gtfs)))
  expect_error(remove_unused_ids(copy_gtfs_without_file(ggl_gtfs, "trips")))
  expect_error(
    remove_unused_ids(copy_gtfs_without_field(ggl_gtfs, "trips", "trip_id"))
  )
  expect_error(
    remove_unused_ids(copy_gtfs_without_file(ggl_gtfs, "stop_times"))
  )
})

test_that("outputs a dt_gtfs object and doesn't change given gtfs", {
  original_gtfs <- read_gtfs(ggl_path)
  gtfs <- read_gtfs(ggl_path)
  expect_identical(original_gtfs, gtfs)

  result <- remove_unused_ids(gtfs)
  expect_s3_class(result, c("dt_gtfs", "gtfs", "list"))
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})

test_that("removes unused ids and is idempotent", {
  result <- remove_unused_ids(ber_gtfs)
  expect_identical(nrow(ber_gtfs$agency), 37L)
  expect_identical(result$agency$agency_id, "92")

  for (path in c(spo_path, poa_path, ber_path, ggl_path)) {
    result <- remove_unused_ids(read_gtfs(path))
    expect_identical(remove_unused_ids(result), result)
  }
})

test_that("removes trips without stop_times and orphan stop_times", {
  result <- remove_unused_ids(ggl_gtfs)

  # AWE2 has no stop_times and AWD1 is only listed in stop_times
  expect_identical(result$trips$trip_id, "AWE1")
  expect_true(all(result$stop_times$trip_id == "AWE1"))

  expect_true(all(result$routes$route_id %chin% result$trips$route_id))
  expect_true(
    all(result$calendar$service_id %chin% result$trips$service_id)
  )
  expect_true(
    all(result$calendar_dates$service_id %chin% result$trips$service_id)
  )
})

test_that("keeps feed-wide fares and removes fares dropped by zone", {
  # fares without fare_rules apply to the whole feed, so their agencies are
  # kept even if no route uses them
  gtfs <- read_gtfs(ber_path)
  gtfs$fare_attributes <- data.table::data.table(
    fare_id = "f",
    price = 1,
    currency_type = "EUR",
    payment_method = 0L,
    transfers = "",
    agency_id = "1"
  )
  original_gtfs <- data.table::copy(gtfs)
  result <- remove_unused_ids(gtfs)
  expect_identical(result$fare_attributes, gtfs$fare_attributes)
  expect_identical(result$agency$agency_id, c("1", "92"))
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  # fare "2" only applies to a zone that no used stop is in
  gtfs <- served_ggl()
  gtfs$stops[, zone_id := "z1"]
  gtfs$fare_rules <- data.table::data.table(
    fare_id = c("1", "2"),
    route_id = c("A", ""),
    origin_id = c("", "z9")
  )
  result <- remove_unused_ids(gtfs)
  expect_identical(result$fare_attributes$fare_id, "1")
  expect_identical(remove_unused_ids(result), result)
})

test_that("removes attributions and translations of removed ids", {
  gtfs <- served_ggl()
  gtfs$attributions <- data.table::data.table(
    attribution_id = c("at1", "at2", "at3"),
    agency_id = c("agency001", "", ""),
    route_id = c("", "Z", ""),
    trip_id = c("", "", "AWE2"),
    organization_name = "org",
    is_producer = 1L
  )
  gtfs$translations <- data.table::data.table(
    table_name = c(
      "stops", "stops", "routes", "routes", "trips", "stop_times",
      "stop_times", "feed_info", "stops", "agency", "attributions",
      "attributions"
    ),
    field_name = "name",
    language = "fr",
    translation = "x",
    record_id = c(
      "F12S", "F12N", "A", "Z", "AWE2", "AWE1", "AWE2", "", "", "agency001",
      "at1", "at2"
    ),
    field_value = c(rep("", 8), "5 Av/53 St", rep("", 3))
  )

  result <- remove_unused_ids(gtfs)
  expect_identical(result$attributions$attribution_id, "at1")
  expect_identical(
    result$translations$record_id,
    c("F12S", "A", "AWE1", "", "", "agency001", "at1")
  )

  # agency translations are kept if 'agency' has no 'agency_id'
  gtfs <- copy_gtfs_without_field(gtfs, "agency", "agency_id")
  result <- remove_unused_ids(gtfs)
  expect_true("agency001" %chin% result$translations$record_id)
})
