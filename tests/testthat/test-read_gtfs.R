# fix this later - necessary to conditionally run tests that require {zip}
if (requireNamespace("zip", quietly = TRUE)) {

# setup -------------------------------------------------------------------


data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs_url  <- "https://github.com/ipeaGIT/gtfstools/raw/main/inst/extdata/spo_gtfs.zip"

gtfs <- read_gtfs(data_path)

# create gtfs with empty table

et_temp_file <- tempfile(pattern = "gtfs", fileext = ".zip")
on.exit(file.remove(et_temp_file))

et_gtfs <- gtfs
et_gtfs$trips <- et_gtfs$trips[trip_id == "def_no_trip"]
write_gtfs(et_gtfs, et_temp_file)
et_gtfs <- read_gtfs(et_temp_file)

# create gtfs with empty file

ef_temp_file <- tempfile(pattern = "gtfs", fileext = ".zip")
on.exit(file.remove(ef_temp_file), add = TRUE)

ef_temp_dir <- file.path(tempdir(), "test_ef_gtfsdir")
on.exit(unlink(ef_temp_dir, recursive = TRUE), add = TRUE)

zip::unzip(data_path, exdir = ef_temp_dir, overwrite = TRUE)
file.remove(file.path(ef_temp_dir, "trips.txt"))
file.create(file.path(ef_temp_dir, "trips.txt"))
zip::zipr(ef_temp_file, file.path(ef_temp_dir, list.files(ef_temp_dir)))
suppressWarnings(ef_gtfs <- read_gtfs(ef_temp_file))

# create gtfs with extra file

ext_temp_file <- tempfile(pattern = "gtfs", fileext = ".zip")
on.exit(file.remove(ext_temp_file), add = TRUE)

ext_temp_dir <- file.path(tempdir(), "test_ext_gtfsdir")
on.exit(unlink(ext_temp_dir, recursive = TRUE), add = TRUE)

zip::unzip(data_path, exdir = ext_temp_dir, overwrite = TRUE)
calendar_txt <- file.path(ext_temp_dir, "calendar.txt")
calendar_extra_txt <- file.path(ext_temp_dir, "calendar_extra.txt")
file.copy(from = calendar_txt, to = calendar_extra_txt)
zip::zipr(ext_temp_file, file.path(ext_temp_dir, list.files(ext_temp_dir)))
ext_gtfs <- read_gtfs(ext_temp_file)

# create gtfs with file that results in parsing failure

pf_temp_file <- tempfile(pattern = "gtfs", fileext = ".zip")
on.exit(file.remove(pf_temp_file), add = TRUE)

pf_temp_dir <- file.path(tempdir(), "test_pf_gtfsdir")
on.exit(unlink(pf_temp_dir, recursive = TRUE), add = TRUE)

zip::unzip(data_path, exdir = pf_temp_dir, overwrite = TRUE)
agency_txt <- file.path(pf_temp_dir, "agency.txt")
invisible(file.remove(agency_txt))
invisible(file.create(agency_txt))
writeLines(
  c(
    "agency_id,agency_name,agency_url,agency_timezone,agency_lang,extracol",
    "1,SPTRANS,http://www.sptrans.com.br/?versao=011019,America/Sao_Paulo,pt",
    "1,SPTRANS,http://www.sptrans.com.br/?versao=011019,America/Sao_Paulo,pt"
  ),
  agency_txt
)
zip::zipr(pf_temp_file, file.path(pf_temp_dir, list.files(pf_temp_dir)))
suppressWarnings(pf_gtfs <- read_gtfs(pf_temp_file))


# tests -------------------------------------------------------------------


test_that("raises errors due to incorrect input types", {
  expect_error(read_gtfs(as.factor(data_path)))
  expect_error(read_gtfs(data_path, files = NA))
  expect_error(read_gtfs(data_path, files = as.factor("stop_times")))
  expect_error(read_gtfs(data_path, fields = NA))
  expect_error(read_gtfs(data_path, skip = as.factor("stop_times")))
  expect_error(read_gtfs(data_path, skip = NA))
  expect_error(read_gtfs(data_path, quiet = "TRUE"))
  expect_error(read_gtfs(data_path, quiet = NA))
  expect_error(read_gtfs(data_path, quiet = c(TRUE, TRUE)))
  expect_error(read_gtfs(data_path, encoding = as.factor("unknown")))
  expect_error(read_gtfs(data_path, encoding = "wrong_encoding"))
  expect_error(read_gtfs(data_path, encoding = c("unknown", "UTF-8")))
})

test_that("output messages adequately", {
  # this is more thoroughly checked on {gtfsio}, just some sanity checks to make
  # sure the arguments are passed correctly
  expect_silent(read_gtfs(data_path))
  suppressMessages({
    expect_message(read_gtfs(data_path, quiet = FALSE))
  })
})

test_that("results in a dt_gtfs object", {

  # a dt_gtfs object is a list with "dt_gtfs" and "gtfs" classes

  dt_gtfs_class <- c("dt_gtfs", "gtfs")

  expect_s3_class(gtfs, dt_gtfs_class)
  expect_s3_class(et_gtfs, dt_gtfs_class)
  expect_s3_class(ef_gtfs, dt_gtfs_class)
  expect_s3_class(ext_gtfs, dt_gtfs_class)
  expect_s3_class(pf_gtfs, dt_gtfs_class)

  expect_type(gtfs, "list")
  expect_type(et_gtfs, "list")
  expect_type(ef_gtfs, "list")
  expect_type(ext_gtfs, "list")
  expect_type(pf_gtfs, "list")

  # all objects within the objects are data.tables, even if they originally are
  # empty tables/files

  invisible(lapply(gtfs, expect_s3_class, "data.table"))
  invisible(lapply(et_gtfs, expect_s3_class, "data.table"))
  invisible(lapply(ef_gtfs, expect_s3_class, "data.table"))
  invisible(lapply(ext_gtfs, expect_s3_class, "data.table"))
  invisible(lapply(pf_gtfs, expect_s3_class, "data.table"))

})

test_that("reads expected files and fields", {
  # this is more thoroughly checked on {gtfsio}

  files_in_zip <- sub(".txt", "", zip::zip_list(data_path)$filename)
  expect_equal(names(gtfs), files_in_zip)

  one_file_gtfs <- read_gtfs(data_path, "agency")
  expect_equal(names(one_file_gtfs), "agency")

  all_but_one_gtfs <- read_gtfs(data_path, skip = "agency")
  expect_equal(
    names(all_but_one_gtfs),
    setdiff(files_in_zip, "agency")
  )

  agency_id_gtfs <- read_gtfs(data_path, fields = list(agency = "agency_id"))
  expect_equal(names(agency_id_gtfs), files_in_zip)
  expect_equal(names(agency_id_gtfs$agency), "agency_id")
})

test_that("date fields are converted to Date objects", {
  ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
  ggl_gtfs <- read_gtfs(ggl_path)

  expect_s3_class(ggl_gtfs$calendar$start_date, "Date")
  expect_s3_class(ggl_gtfs$calendar$end_date, "Date")
  expect_s3_class(ggl_gtfs$calendar_dates$date, "Date")

  # and that other than that the rest remains unaltered

  ggl_gtfs$calendar[, start_date := date_to_integer(start_date)]
  ggl_gtfs$calendar[, end_date := date_to_integer(end_date)]
  ggl_gtfs$calendar_dates[, date := date_to_integer(date)]

  unconverted_gtfs <- gtfsio::import_gtfs(ggl_path)
  unconverted_gtfs$routes[
    ,
    route_desc := gsub("\"\"", "\"", route_desc, fixed = TRUE)
  ]
  expect_identical(unclass(ggl_gtfs), unclass(unconverted_gtfs))
})

}
