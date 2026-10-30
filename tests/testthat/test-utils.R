data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
no_class_gtfs <- unclass(gtfs)


# string_to_seconds -------------------------------------------------------


test_that("raises errors due to incorrect input types", {
  expect_error(string_to_seconds(factor("25:00:00")))
  expect_error(string_to_seconds(NULL))
})

test_that("outputs NA if empty string or NA is given", {
  expect_identical(string_to_seconds(""), NA_integer_)
  expect_identical(string_to_seconds(NA_character_), NA_integer_)
})

test_that("calculates seconds adequately", {
  expect_identical(string_to_seconds("00:00:00"), 0L)
  expect_identical(string_to_seconds("25:00:00"), 90000L)
  expect_identical(string_to_seconds("01:01:01"), 3661L)
  expect_identical(
    string_to_seconds(
      c(" 07:05:09 ", "\t07:05:09\r\n", "7:05:09", "000000001:00:00",
        "596523:14:07")
    ),
    c(25509L, 25509L, 25509L, 3600L, .Machine$integer.max)
  )
})

test_that("handles repeated values and counts malformed strings per row", {
  string <- c("abc", "08:00:00", "", "abc", NA, "08:00:00", " ", "NA")
  expect_warning(
    result <- string_to_seconds(string),
    regexp = "^2 malformed time strings",
    class = "gtfstools_malformed_time"
  )
  expect_identical(result, c(NA, 28800L, NA, NA, NA, 28800L, NA, NA))

  malformed <- c(
    "596523:14:08", "1234567890:00:00", "08:60:00", "08:00:60", "08:0:00",
    "08:00", "08:00:00:00", ":00:00", "08 :00:00", "08:00:00 x", "08:00:00\f"
  )
  expect_warning(
    result <- string_to_seconds(malformed),
    regexp = "^11 malformed time strings",
    class = "gtfstools_malformed_time"
  )
  expect_identical(result, rep(NA_integer_, 11))

  # non-ASCII strings marked as "bytes" can't be translated to UTF-8, but are
  # just malformed times

  bytes_string <- rawToChar(c(charToRaw("08:00:00"), as.raw(0xff)))
  Encoding(bytes_string) <- "bytes"
  expect_warning(
    result <- string_to_seconds(c("08:00:00", bytes_string)),
    regexp = "^1 malformed time string",
    class = "gtfstools_malformed_time"
  )
  expect_identical(result, c(28800L, NA))

  expect_identical(string_to_seconds(character(0)), integer(0))
})


# seconds_to_string -------------------------------------------------------


test_that("raises errors due to incorrect input types", {
  expect_error(seconds_to_string(1000))
  expect_error(seconds_to_string("1000"))
  expect_error(seconds_to_string(-1000))
})

test_that("outputs '' if NA is given", {
  expect_equal(seconds_to_string(NA_integer_), "")
})

test_that("generates strings correctly", {
  expect_identical(seconds_to_string(0L), "00:00:00")
  expect_identical(seconds_to_string(90000L), "25:00:00")
  expect_identical(seconds_to_string(3661L), "01:01:01")
})

test_that("handles repeated values", {
  expect_identical(
    seconds_to_string(c(3661L, NA, 3661L, 0L, NA)),
    c("01:01:01", "", "01:01:01", "00:00:00", "")
  )
  expect_identical(seconds_to_string(integer(0)), character(0))
})


# copy_gtfs_without_file --------------------------------------------------


test_that("raises errors due to incorrect input types", {
  expect_error(copy_gtfs_without_file(no_class_gtfs, "shapes"))
  expect_error(copy_gtfs_without_file(gtfs, as.factor("shapes")))
})

test_that("raises errors if non-existent file is given", {
  expect_error(copy_gtfs_without_file(gtfs, "non-existent file"))
})

test_that("outputs a gtfs without given file", {
  gtfs_copy <- copy_gtfs_without_file(gtfs, "shapes")
  expect_s3_class(gtfs_copy, "dt_gtfs")
  expect_identical(names(gtfs_copy), names(gtfs)[names(gtfs) != "shapes"])
})


# copy_gtfs_without_field -------------------------------------------------


test_that("raises errors due to incorrect input types", {
  expect_error(copy_gtfs_without_file(no_class_gtfs, "shapes", "shape_id"))
  expect_error(copy_gtfs_without_file(gtfs, as.factor("shapes"), "shape_id"))
  expect_error(copy_gtfs_without_file(gtfs, "shapes", as.factor("shape_id")))
})

test_that("raises errors if non-existent file/field is given", {
  expect_error(copy_gtfs_without_file(gtfs, "non-existent file", "shape_id"))
  expect_error(copy_gtfs_without_file(gtfs, "shapes", "non-existent field"))
})

test_that("outputs a gtfs without the given field", {
  gtfs_copy <- copy_gtfs_without_field(gtfs, "shapes", "shape_id")
  expect_s3_class(gtfs_copy, "dt_gtfs")
  expect_identical(
    names(gtfs_copy$shapes),
    names(gtfs$shapes)[names(gtfs$shapes) != "shape_id"]
  )
})

test_that("outputs doesn't change original file", {
  shapes_before <- data.table::copy(gtfs$shapes)
  gtfs_copy <- copy_gtfs_without_field(gtfs, "shapes", "shape_id")
  shapes_after <- data.table::copy(gtfs$shapes)
  expect_identical(shapes_before, shapes_after)
})


# copy_gtfs_diff_field_class ----------------------------------------------


test_that("raises errors due to incorrect input types", {
  expect_error(
    copy_gtfs_diff_field_class(no_class_gtfs, "stops", "stop_id", "factor")
  )
  expect_error(
    copy_gtfs_diff_field_class(gtfs, as.factor("stops"), "stop_id", "factor")
  )
  expect_error(
    copy_gtfs_diff_field_class(gtfs, "stops", as.factor("stop_id"), "factor")
  )
  expect_error(
    copy_gtfs_diff_field_class(gtfs, "stops", "stop_id", as.factor("factor"))
  )
})

test_that("raises errors if non-existent file/field is given", {
  expect_error(
    copy_gtfs_diff_field_class(gtfs, "wrong_file", "stop_id", "factor")
  )
  expect_error(
    copy_gtfs_diff_field_class(gtfs, "stops", "wrong_field", "factor")
  )
})

test_that("outputs a gtfs with field of desired class", {

  # converting to factor

  gtfs_copy <- copy_gtfs_diff_field_class(gtfs, "stops", "stop_id", "factor")
  expect_s3_class(gtfs_copy, "dt_gtfs")
  expect_vector(gtfs$stops$stop_id, character(0))
  expect_s3_class(gtfs_copy$stops$stop_id, "factor")

  # and to character

  gtfs_copy <- copy_gtfs_diff_field_class(
    gtfs,
    "stops",
    "stop_lat",
    "character"
  )
  expect_s3_class(gtfs_copy, "dt_gtfs")
  expect_vector(gtfs$stops$stop_lat, numeric(0))
  expect_vector(gtfs_copy$stops$stop_lat, character(0))

})

test_that("function call doesn't change original file", {
  stops_before <- data.table::copy(gtfs$stops)
  gtfs_copy <- copy_gtfs_diff_field_class(gtfs, "stops", "stop_id", "factor")
  stops_after <- data.table::copy(gtfs$stops)
  expect_identical(stops_before, stops_after)
})

# assert_and_assign_gtfs_object -------------------------------------------

test_that("raises error if input is not an gtfs object", {
  expect_error(assert_and_assign_gtfs_object(unclass(gtfs)))
})

test_that("always returns a dt_gtfs object", {
  result <- assert_and_assign_gtfs_object(gtfs)
  expect_s3_class(result, "dt_gtfs")

  gtfsio_gtfs <- gtfsio::import_gtfs(data_path)
  result <- assert_and_assign_gtfs_object(gtfsio_gtfs)
  expect_s3_class(result, "dt_gtfs")
})

test_that("converts tables that lost the data.table class back (#130)", {
  df_gtfs <- read_gtfs(data_path)
  df_gtfs$stop_times <- as.data.frame(df_gtfs$stop_times)

  result <- assert_and_assign_gtfs_object(df_gtfs)
  expect_true(data.table::is.data.table(result$stop_times))
  expect_identical(result$stop_times, gtfs$stop_times)

  result <- assert_and_assign_gtfs_object(df_gtfs, by_reference = FALSE)
  expect_true(data.table::is.data.table(result$stop_times))

  # the input is not modified
  expect_identical(class(df_gtfs$stop_times), "data.frame")
})

test_that("by_reference = TRUE refuses tables that are not data.tables", {
  df_gtfs <- read_gtfs(data_path)
  df_gtfs$stop_times <- as.data.frame(df_gtfs$stop_times)

  expect_error(
    assert_and_assign_gtfs_object(df_gtfs, by_reference = TRUE),
    class = "gtfstools_not_data_table_error"
  )

  # the error names the offending tables

  df_gtfs$trips <- as.data.frame(df_gtfs$trips)
  expect_error(
    assert_and_assign_gtfs_object(df_gtfs, by_reference = TRUE),
    "stop_times[[:space:]]+and[[:space:]]+trips[[:space:]]+are[[:space:]]+not",
    class = "gtfstools_not_data_table_error"
  )

  # every exported function with by_reference passes it on to the helper

  df_gtfs <- read_gtfs(data_path)
  df_gtfs$stop_times <- as.data.frame(df_gtfs$stop_times)

  calls <- list(
    quote(set_trip_speed(df_gtfs, speed = 20, by_reference = TRUE)),
    quote(set_route_speed(df_gtfs, speed = 20, by_reference = TRUE)),
    quote(set_dwell_time(df_gtfs, dwell_time = 30, by_reference = TRUE)),
    quote(
      set_min_dwell_time(df_gtfs, min_dwell_time = 30, by_reference = TRUE)
    ),
    quote(convert_time_to_seconds(df_gtfs, by_reference = TRUE))
  )
  for (cl in calls) {
    expect_error(eval(cl), class = "gtfstools_not_data_table_error")
  }
  expect_identical(class(df_gtfs$stop_times), "data.frame")
})



# warn_missing_ids --------------------------------------------------------


test_that("warn_missing_ids() warns about missing ids for its caller", {
  f <- function(x) warn_missing_ids(x, c("a", "b"), "tbl", "x_id")

  expect_silent(f("a"))
  expect_silent(f(character(0)))
  expect_identical(f("a"), character(0))

  w <- tryCatch(f(c("a", "c", "c")), warning = function(w) w)
  expect_identical(
    conditionMessage(w),
    "'tbl' doesn't contain the following x_id(s): 'c', 'c'"
  )
  expect_identical(conditionCall(w), quote(f(c("a", "c", "c"))))

  expect_invisible(suppressWarnings(result <- f(c("a", "c", "c"))))
  expect_identical(result, c("c", "c"))
})



# warn_invalid_ids --------------------------------------------------------


test_that("warn_invalid_ids() warns about the distinct missing ids with cli", {
  f <- function(x) warn_invalid_ids(x, c("a", "b"), "trips", "route_id")

  expect_silent(f("a"))
  expect_silent(f(character(0)))
  expect_silent(f(NULL))
  expect_identical(f("a"), character(0))

  # the expected messages pin the rendering (singular and plural) that the
  # users of the callers see

  w <- tryCatch(f("c"), warning = function(w) w)
  expect_s3_class(w, "gtfstools_invalid_route_id")
  expect_identical(
    conditionMessage(w),
    "'trips' doesn't contain the following route_id: \"c\"."
  )

  w <- tryCatch(f(c("a", "c", "d", "c")), warning = function(w) w)
  expect_identical(
    conditionMessage(w),
    "'trips' doesn't contain the following route_ids: \"c\" and \"d\"."
  )

  g <- function(x) warn_invalid_ids(x, "t1", "stop_times", "trip_id")
  expect_warning(g("t2"), class = "gtfstools_invalid_trip_id")

  expect_invisible(suppressWarnings(result <- f(c("a", "c", "c"))))
  expect_identical(result, "c")
})



# refresh_secs_columns ----------------------------------------------------


test_that("refresh_secs_columns() syncs existing *_secs columns by reference", {
  dt <- data.table::data.table(
    departure_time = c("00:00:10", "00:01:00", "00:02:00"),
    arrival_time = c("00:00:05", "00:00:50", "00:01:50"),
    departure_time_secs = 0L
  )

  # only the given rows are refreshed, and only the columns that exist

  refresh_secs_columns(dt, c("departure_time", "arrival_time"), 2:3)
  expect_identical(dt$departure_time_secs, c(0L, 60L, 120L))
  expect_false("arrival_time_secs" %in% names(dt))

  # NULL rows means all rows, and an empty selection is a silent no-op

  refresh_secs_columns(dt, "departure_time")
  expect_identical(dt$departure_time_secs, c(10L, 60L, 120L))

  expect_silent(refresh_secs_columns(dt, "departure_time", integer(0)))
  expect_identical(dt$departure_time_secs, c(10L, 60L, 120L))

  expect_invisible(result <- refresh_secs_columns(dt, "departure_time"))
  expect_identical(result, dt)
})



# time_secs ---------------------------------------------------------------


test_that("time_secs() uses an existing _secs column as-is or converts", {
  dt <- data.table::data.table(
    departure_time = c("00:00:10", "00:01:00"),
    arrival_time = c("00:00:05", NA),
    departure_time_secs = c(10.5, 60)
  )
  expect_identical(time_secs(dt, "departure_time"), dt$departure_time_secs)
  expect_identical(time_secs(dt, "arrival_time"), c(5L, NA))
  expect_identical(time_secs(dt[0], "arrival_time"), integer(0))

  dt[, departure_time_secs := c(10L, 60L)]
  expect_identical(time_secs(dt, "departure_time"), c(10L, 60L))
})



# first_departure_per_trip ------------------------------------------------


test_that("first_departure_per_trip() ignores missing departures", {
  trip_id <- c("b", "a", "a", "c", "b")
  secs <- c(NA, 30L, 10L, NA, 5L)
  expected <- data.table::data.table(
    trip_id = c("a", "b"),
    departure_secs = c(10L, 5L)
  )

  # trips without any departure are left out, and the others are listed in
  # the order of first appearance of their timed rows

  expect_identical(first_departure_per_trip(trip_id, secs), expected)
  expect_identical(
    first_departure_per_trip(character(0), integer(0)),
    expected[0]
  )
  expect_identical(first_departure_per_trip("c", NA_integer_), expected[0])

  # the same without data.table's GForce optimisation of min()

  old_options <- options(datatable.optimize = 0L)
  on.exit(options(old_options), add = TRUE)
  expect_identical(first_departure_per_trip(trip_id, secs), expected)
})
