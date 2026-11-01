spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")

tester <- function(gtfs = wrap_gtfs) fix_overnight_times(gtfs)

# creates a feed with one trip per element of 'times', a named list with the
# arrival and departure times of each trip (departures default to arrivals)

synthetic_feed <- function(times) {
  stop_times <- data.table::rbindlist(
    lapply(
      names(times),
      function(id) {
        arr <- times[[id]]$arr
        dep <- times[[id]]$dep
        if (is.null(dep)) dep <- arr
        data.table::data.table(
          trip_id = id,
          arrival_time = arr,
          departure_time = dep,
          stop_id = paste0("s", seq_along(arr)),
          stop_sequence = seq_along(arr)
        )
      }
    )
  )

  feed <- list(
    trips = data.table::data.table(trip_id = names(times), route_id = "r1"),
    stop_times = stop_times
  )

  return(gtfsio::new_gtfs(feed, "dt_gtfs"))
}

# trips that run past midnight, with the times they should have after the fix

wrap_times <- list(
  arrival = list(arr = c("23:00:00", "23:50:00", "00:10:00")),
  arr_dep = list(
    arr = c("23:00:00", "23:59:00", "00:20:00"),
    dep = c("23:00:00", "00:01:00", "00:20:00")
  ),
  one_time = list(
    arr = c("23:00:00", "", "00:10:00", ""),
    dep = c("23:00:00", "", "", "00:20:00")
  ),
  leading_blank = list(arr = c("", "23:30:00", "", "00:30:00")),
  mixed_after = list(arr = c("24:30:00", "00:40:00", "24:50:00")),
  forward_gap = list(arr = c("00:10:00", "24:20:00")),
  double_wrap = list(
    arr = c(
      "22:00:00", "00:30:00", "08:00:00", "16:00:00", "23:50:00", "00:10:00"
    )
  ),
  correct = list(arr = c("23:00:00", "24:30:00", "25:10:00")),
  long_trip = list(arr = c("06:00:00", "", "19:30:00")),
  daytime = list(arr = c("08:00:00", "08:30:00", "09:00:00"))
)

expected_times <- list(
  arrival = list(arr = c("23:00:00", "23:50:00", "24:10:00")),
  arr_dep = list(
    arr = c("23:00:00", "23:59:00", "24:20:00"),
    dep = c("23:00:00", "24:01:00", "24:20:00")
  ),
  one_time = list(
    arr = c("23:00:00", "", "24:10:00", ""),
    dep = c("23:00:00", "", "", "24:20:00")
  ),
  leading_blank = list(arr = c("", "23:30:00", "", "24:30:00")),
  mixed_after = list(arr = c("24:30:00", "24:40:00", "24:50:00")),
  double_wrap = list(
    arr = c(
      "22:00:00", "24:30:00", "32:00:00", "40:00:00", "47:50:00", "48:10:00"
    )
  ),
  forward_gap = wrap_times$forward_gap,
  correct = wrap_times$correct,
  long_trip = wrap_times$long_trip,
  daytime = wrap_times$daytime
)

wrap_gtfs <- synthetic_feed(wrap_times)
wrap_gtfs$frequencies <- data.table::data.table(
  trip_id = "correct",
  start_time = c("23:00:00", "05:00:00", "22:00:00", "48:30:00", "25:00:00"),
  end_time = c("01:00:00", "06:00:00", "24:30:00", "00:10:00", "01:00:00"),
  headway_secs = 600L
)

# trips whose times still go back after the fix, which raise a warning

warn_gtfs <- synthetic_feed(
  list(
    small_back = list(arr = c("08:00:00", "08:05:00", "08:04:00")),
    exactly_12h = list(arr = c("20:00:00", "08:00:00")),
    back_after_fix = list(arr = c("24:30:00", "00:20:00"))
  )
)

trip_times <- function(gtfs, id) {
  st <- gtfs$stop_times[trip_id == id]
  return(list(arr = st$arrival_time, dep = st$departure_time))
}

expect_trip_times <- function(gtfs, id, expected) {
  if (is.null(expected$dep)) expected$dep <- expected$arr
  expect_identical(trip_times(gtfs, id), expected[c("arr", "dep")])
}

# tests ---

test_that("raises error due to incorrect input types", {
  expect_error(tester(unclass(wrap_gtfs)))

  no_arrival <- copy_gtfs_without_field(wrap_gtfs, "stop_times", "arrival_time")
  expect_error(tester(no_arrival))

  bad_sequence <- copy_gtfs_diff_field_class(
    wrap_gtfs,
    "stop_times",
    "stop_sequence",
    "character"
  )
  expect_error(tester(bad_sequence))

  bad_end <- copy_gtfs_diff_field_class(
    wrap_gtfs,
    "frequencies",
    "end_time",
    "factor"
  )
  expect_error(tester(bad_end))

  expect_error(tester(copy_gtfs_without_file(wrap_gtfs, "stop_times")))
})

test_that("results in a dt_gtfs object", {
  result <- tester()
  expect_s3_class(result, c("dt_gtfs", "gtfs", "list"))
  for (table in names(result)) {
    expect_s3_class(result[[table]], "data.table")
  }
})

test_that("moves the times after midnight one day later", {
  result <- expect_silent(tester())

  for (id in names(expected_times)) {
    expect_trip_times(result, id, expected_times[[id]])
  }

  # only the time columns change

  expect_identical(
    result$stop_times[, .(trip_id, stop_id, stop_sequence)],
    wrap_gtfs$stop_times[, .(trip_id, stop_id, stop_sequence)]
  )
  expect_identical(result$trips, wrap_gtfs$trips)
})

test_that("leaves rows without trip_id or stop_sequence unchanged", {
  gtfs <- wrap_gtfs
  gtfs$stop_times <- rbind(
    wrap_gtfs$stop_times,
    data.table::data.table(
      trip_id = c(NA, "arrival"),
      arrival_time = "00:05:00",
      departure_time = "00:05:00",
      stop_id = "s1",
      stop_sequence = c(10L, NA)
    )
  )

  result <- tester(gtfs)
  expect_identical(
    result$stop_times[is.na(trip_id) | is.na(stop_sequence), arrival_time],
    c("00:05:00", "00:05:00")
  )
  expect_trip_times(
    result,
    "arrival",
    list(arr = c("23:00:00", "23:50:00", "24:10:00", "00:05:00"))
  )
})

test_that("warns about times that still go back", {
  expect_warning(
    result <- tester(warn_gtfs),
    class = "gtfstools_backwards_times"
  )

  expect_trip_times(
    result,
    "small_back",
    list(arr = c("08:00:00", "08:05:00", "08:04:00"))
  )
  expect_trip_times(
    result,
    "exactly_12h",
    list(arr = c("20:00:00", "08:00:00"))
  )
  expect_trip_times(
    result,
    "back_after_fix",
    list(arr = c("24:30:00", "24:20:00"))
  )

  # every trip is named in the warning

  warning_msg <- tryCatch(
    tester(warn_gtfs),
    warning = function(w) conditionMessage(w)
  )
  for (id in c("small_back", "exactly_12h", "back_after_fix")) {
    expect_match(warning_msg, id, fixed = TRUE)
  }
})

test_that("fixes end times earlier than start times in frequencies", {
  result <- tester()
  expect_identical(
    result$frequencies$end_time,
    c("25:00:00", "06:00:00", "24:30:00", "72:10:00", "49:00:00")
  )
  expect_identical(
    result$frequencies$start_time,
    wrap_gtfs$frequencies$start_time
  )

  no_frequencies <- copy_gtfs_without_file(wrap_gtfs, "frequencies")
  result <- tester(no_frequencies)
  expect_null(result$frequencies)
  expect_trip_times(result, "arrival", expected_times$arrival)
})

test_that("updates existing _secs columns", {
  gtfs <- convert_time_to_seconds(wrap_gtfs)
  result <- tester(gtfs)

  expect_identical(
    result$stop_times$arrival_time_secs,
    string_to_seconds(result$stop_times$arrival_time)
  )
  expect_identical(
    result$stop_times$departure_time_secs,
    string_to_seconds(result$stop_times$departure_time)
  )
  expect_identical(
    result$frequencies$end_time_secs,
    string_to_seconds(result$frequencies$end_time)
  )
})

test_that("raises an error when a fixed time is out of range", {
  gtfs <- synthetic_feed(list(late = list(arr = c("9999:00:00", "00:10:00"))))
  expect_error(tester(gtfs), class = "gtfstools_time_out_of_range")

  gtfs <- wrap_gtfs
  gtfs$frequencies <- data.table::data.table(
    trip_id = "correct",
    start_time = "9999:00:00",
    end_time = "9990:00:00",
    headway_secs = 600L
  )
  expect_error(tester(gtfs), class = "gtfstools_time_out_of_range")
})

test_that("doesn't change given gtfs", {
  original_gtfs <- gtfsio::new_gtfs(
    lapply(wrap_gtfs, data.table::copy),
    "dt_gtfs"
  )
  gtfs <- gtfsio::new_gtfs(lapply(wrap_gtfs, data.table::copy), "dt_gtfs")
  expect_identical(original_gtfs, gtfs)

  result <- tester(gtfs)
  expect_false(identical(result$stop_times, gtfs$stop_times))
  expect_false(identical(result$frequencies, gtfs$frequencies))
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  original_gtfs <- read_gtfs(poa_path)
  gtfs <- read_gtfs(poa_path)
  expect_identical(original_gtfs, gtfs)

  result <- tester(gtfs)
  expect_false(identical(result$stop_times, gtfs$stop_times))
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})

test_that("returns feeds without times after midnight unchanged", {
  spo_gtfs <- read_gtfs(spo_path)
  result <- expect_silent(tester(spo_gtfs))
  expect_identical(result, spo_gtfs)
})

test_that("fixes the trips of poa that run past midnight", {
  poa_gtfs <- read_gtfs(poa_path)
  result <- expect_silent(tester(poa_gtfs))

  changed <- result$stop_times$arrival_time != poa_gtfs$stop_times$arrival_time
  expect_length(unique(result$stop_times$trip_id[changed]), 10)

  expect_trip_times(
    result,
    "T2-1@1#2310",
    list(
      arr = c("23:10:00", rep("", 60), "24:02:00"),
      dep = c("23:10:00", rep("", 60), "24:02:00")
    )
  )
})

test_that("the internal fix can be restricted to some trips", {
  result <- fix_overnight_stop_times(wrap_gtfs, trip_id = "arrival")
  expect_trip_times(result, "arrival", expected_times$arrival)
  expect_trip_times(result, "arr_dep", wrap_times$arr_dep)

  # with shuffled rows and an unknown id, the selected trips are fixed as when
  # every trip is fixed, and the others are left unchanged

  shuffled_gtfs <- wrap_gtfs
  shuffled_gtfs$stop_times <- wrap_gtfs$stop_times[
    rev(seq_len(nrow(wrap_gtfs$stop_times)))
  ]
  selected <- c("one_time", "double_wrap", "unknown")
  result <- fix_overnight_stop_times(shuffled_gtfs, trip_id = selected)
  for (id in c("one_time", "double_wrap")) {
    expect_trip_times(result, id, lapply(expected_times[[id]], rev))
  }
  expect_identical(
    result$stop_times[!trip_id %chin% selected],
    shuffled_gtfs$stop_times[!trip_id %chin% selected]
  )

  expect_identical(
    fix_overnight_stop_times(wrap_gtfs, trip_id = character(0)),
    wrap_gtfs
  )
})

test_that("nested calls don't fix the times again", {
  poa_gtfs <- read_gtfs(poa_path)

  # only the runs that change some time are counted, which is checked before
  # each run, since tables fixed by reference look the same afterwards

  n_fixes <- 0
  real_fix <- fix_overnight_stop_times
  local_mocked_bindings(
    fix_overnight_stop_times = function(
      gtfs,
      trip_id = NULL,
      warn = TRUE,
      by_reference = FALSE,
      detect_only = FALSE
    ) {
      if (!detect_only) {
        changes <- real_fix(gtfs, trip_id, warn = FALSE, detect_only = TRUE)
        if (isTRUE(changes)) n_fixes <<- n_fixes + 1
      }
      real_fix(gtfs, trip_id, warn, by_reference, detect_only)
    }
  )
  count_fixes <- function(expr) {
    n_fixes <<- 0
    force(expr)
    return(n_fixes)
  }

  expect_identical(count_fixes(fix_gtfs(poa_gtfs)), 1)
  expect_identical(
    count_fixes(get_trip_speed(poa_gtfs, from = "07:00:00", to = "09:00:00")),
    1
  )
  expect_identical(
    count_fixes(
      suppressWarnings(
        build_graph(poa_gtfs, from = "07:00:00", to = "08:00:00")
      )
    ),
    1
  )
  expect_identical(
    count_fixes(
      get_stop_frequency(poa_gtfs, from = "07:00:00", to = "08:00:00")
    ),
    1
  )
  if (report_deps_available()) {
    expect_identical(
      count_fixes(
        get_summary(
          poa_gtfs,
          output_path = tempfile("get_summary"),
          html_preview = FALSE
        )
      ),
      1
    )
  }

  by_reference_gtfs <- read_gtfs(poa_path)
  expect_identical(
    count_fixes(set_dwell_time(by_reference_gtfs, 30, by_reference = TRUE)),
    1
  )

  # a function called by the user while a call is in progress (e.g. in a
  # calling handler) fixes the times of its own feed

  gtfs <- overnight_feed()
  duration <- NULL
  withCallingHandlers(
    get_trip_duration(gtfs, c("W", "unknown")),
    warning = function(w) {
      duration <<- get_trip_duration(gtfs, "W")$duration
      invokeRestart("muffleWarning")
    }
  )
  expect_equal(duration, 45)

  gtfs <- overnight_feed()
  gtfs$frequencies[, `:=`(start_time = "9999:00:00", end_time = "9990:00:00")]
  expect_error(
    get_route_frequency(gtfs, from = "23:00:00", to = "24:00:00"),
    class = "gtfstools_time_out_of_range"
  )
})

test_that("has_overnight_trips() detects the times that would be fixed", {
  expect_true(has_overnight_trips(read_gtfs(poa_path)))
  expect_true(has_overnight_trips(wrap_gtfs))
  expect_true(has_overnight_trips(overnight_feed()))

  # feeds without them, or whose times were already fixed

  expect_false(has_overnight_trips(read_gtfs(spo_path)))
  expect_false(has_overnight_trips(fix_overnight_times(read_gtfs(poa_path))))
  expect_false(has_overnight_trips(fix_overnight_times(overnight_feed())))

  # times that go back by 12 hours or less are not fixed, so they don't count

  small_steps <- synthetic_feed(
    list(
      small_back = list(arr = c("08:00:00", "08:05:00", "08:04:00")),
      exactly_12h = list(arr = c("20:00:00", "08:00:00"))
    )
  )
  expect_silent(result <- has_overnight_trips(small_steps))
  expect_false(result)

  # only frequencies entries that end before they start

  gtfs <- fix_overnight_times(overnight_feed())
  gtfs$frequencies$end_time <- "01:00:00"
  expect_true(has_overnight_trips(gtfs))

  # tables that can't be checked are skipped

  no_sequence <- copy_gtfs_without_field(
    overnight_feed(),
    "stop_times",
    "stop_sequence"
  )
  no_sequence$frequencies <- NULL
  expect_false(has_overnight_trips(no_sequence))
})

test_that("warns about times that go back in feeds without times to fix", {
  # the feed has no times after midnight to fix, but its times that go back
  # by 12 hours or less, and its malformed times, are still reported

  small_back <- synthetic_feed(
    list(small_back = list(arr = c("08:00:00", "08:05:00", "08:04:00")))
  )
  expect_false(has_overnight_trips(small_back))
  expect_warning(
    result <- tester(small_back),
    class = "gtfstools_backwards_times"
  )
  expect_identical(result$stop_times, small_back$stop_times)

  malformed <- synthetic_feed(
    list(malformed = list(arr = c("08:00:00", "ab:cd", "08:10:00")))
  )
  expect_warning(tester(malformed), class = "gtfstools_malformed_time")
})
