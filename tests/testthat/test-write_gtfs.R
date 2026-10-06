# fix this later - necessary to conditionally run tests that require {zip}
if (requireNamespace("zip", quietly = TRUE)) {

# setup -------------------------------------------------------------------


data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)
gtfs$extra_file <- gtfs$agency

no_stop_times_gtfs <- gtfs
no_stop_times_gtfs$stop_times <- NULL

temp_file <- tempfile(pattern = "gtfs", fileext = ".zip")

specified_files <- c(
  "agency", "stops", "routes", "trips", "stop_times", "calendar",
  "calendar_dates", "fare_attributes", "fare_rules", "shapes", "frequencies",
  "transfers", "pathways", "levels", "feed_info", "translations", "attributions"
)

required_files <- c(
  "agency", "stops", "routes", "trips", "stop_times", "calendar"
)

optional_files <- setdiff(specified_files, required_files)


# tests -------------------------------------------------------------------


test_that("raises errors due to incorrect input types", {
  no_class_gtfs <- gtfs
  attr(no_class_gtfs, "class") <- NULL
  expect_error(write_gtfs(no_class_gtfs, temp_file))
  expect_error(write_gtfs(gtfs))
  expect_error(write_gtfs(gtfs, as.factor(temp_file)))
  expect_error(write_gtfs(gtfs, tempfile(pattern = "gtfs")))
  expect_error(write_gtfs(gtfs, temp_file, files = as.factor("agency")))
  expect_error(write_gtfs(gtfs, temp_file, standard_only = "TRUE"))
  expect_error(write_gtfs(gtfs, temp_file, standard_only = NA))
  expect_error(write_gtfs(gtfs, temp_file, standard_only = c(TRUE, TRUE)))
  expect_error(write_gtfs(gtfs, temp_file, as_dir = "TRUE"))
  expect_error(write_gtfs(gtfs, temp_file, as_dir = NA))
  expect_error(write_gtfs(gtfs, temp_file, as_dir = c(TRUE, TRUE)))
  expect_error(write_gtfs(gtfs, temp_file, overwrite = "TRUE"))
  expect_error(write_gtfs(gtfs, temp_file, overwrite = NA))
  expect_error(write_gtfs(gtfs, temp_file, overwrite = c(TRUE, TRUE)))
  expect_error(write_gtfs(gtfs, temp_file, quiet = "TRUE"))
  expect_error(write_gtfs(gtfs, temp_file, quiet = NA))
  expect_error(write_gtfs(gtfs, temp_file, quiet = c(TRUE, TRUE)))
  expect_error(write_gtfs(gtfs, temp_file, compression_level = "6"))
  expect_error(write_gtfs(gtfs, temp_file, compression_level = NA))
  expect_error(write_gtfs(gtfs, temp_file, compression_level = 0))
  expect_error(write_gtfs(gtfs, temp_file, compression_level = 10))
  expect_error(write_gtfs(gtfs, temp_file, compression_level = 1.5))
  expect_error(write_gtfs(gtfs, temp_file, compression_level = c(1, 9)))
})

test_that("writes the same content regardless of compression_level", {
  write_gtfs(gtfs, temp_file)
  written_default <- read_gtfs(temp_file)

  for (level in list(1, 6L, 9)) {
    write_gtfs(gtfs, temp_file, compression_level = level)
    expect_identical(read_gtfs(temp_file), written_default)
  }
})

test_that("raises an errors if file exists and should not be overwritten", {
  invisible(file.create(temp_file))
  expect_error(write_gtfs(gtfs, temp_file, overwrite = FALSE))
})

test_that("outputs a .zip file and invisibly returns the provided gtfs", {
  unlink(temp_file)
  expect_false(file.exists(temp_file))
  expect_identical(write_gtfs(gtfs, temp_file), gtfs)
  expect_true(file.exists(temp_file))
})

test_that("output messages adequately", {
  expect_silent(write_gtfs(gtfs, temp_file))

  suppressMessages(
    expect_message(write_gtfs(gtfs, temp_file, quiet = FALSE))
  )
})

test_that("outputs a gtfs with the desired files", {

  # check if all items are written by default

  write_gtfs(gtfs, temp_file)
  files_in_gtfs <- zip::zip_list(temp_file)$filename
  expect_equal(length(files_in_gtfs), length(names(gtfs)))

  # check if you can control which files are written with 'files'

  write_gtfs(gtfs, temp_file, files = "stop_times")
  files_in_gtfs <- zip::zip_list(temp_file)$filename
  expect_equal(files_in_gtfs, "stop_times.txt")

  # check if extra file is not written when standard_only = TRUE

  write_gtfs(gtfs, temp_file, standard_only = TRUE)
  files_in_gtfs <- zip::zip_list(temp_file)$filename
  expect_equal(
    setdiff(names(gtfs), sub(".txt", "", files_in_gtfs)),
    "extra_file"
  )

})

test_that("writes dates as YYYYMMDD", {

  write_gtfs(gtfs, temp_file)

  temp_dir <- tempdir()
  zip::unzip(
    temp_file,
    files = "calendar.txt",
    exdir = temp_dir,
    overwrite = TRUE
  )

  written_calendar_path <- file.path(temp_dir, "calendar.txt")
  written_calendar      <- data.table::fread(
    written_calendar_path,
    colClasses = "character"
  )

  expect_equal(
    sum(grepl("\\d{8}", written_calendar$start_date)),
    length(written_calendar$start_date)
  )

  expect_equal(
    sum(grepl("\\d{8}", written_calendar$end_date)),
    length(written_calendar$start_date)
  )

  # perhaps a more complete text, check if the gtfs written by write_gtfs() is
  # identical to the original one
  # broken due to {data.table} bug
  # https://github.com/Rdatatable/data.table/issues/5088

  ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
  original_ggl_gtfs <- gtfsio::import_gtfs(ggl_path)

  ggl_gtfs <- read_gtfs(ggl_path)
  write_gtfs(ggl_gtfs, temp_file)

  written_ggl_gtfs <- gtfsio::import_gtfs(temp_file)
  # expect_identical(original_ggl_gtfs, written_ggl_gtfs)

})

}
