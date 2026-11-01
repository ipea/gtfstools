spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")

tester <- function(gtfs = wrap_gtfs) fix_overnight_times(gtfs = gtfs)

# creates a feed with one trip per element of 'times', a named list with the
# arrival and departure times of each trip (departures default to arrivals)

synthetic_feed <- function(times) {
  stop_times <- data.table::rbindlist(
    l = lapply(
      X = names(x = times),
      FUN = function(id) {
        arr <- times[[id]]$arr
        dep <- times[[id]]$dep
        if (is.null(x = dep)) dep <- arr
        data.table::data.table(
          trip_id = id,
          arrival_time = arr,
          departure_time = dep,
          stop_id = paste0("s", seq_along(along.with = arr)),
          stop_sequence = seq_along(along.with = arr)
        )
      }
    )
  )

  feed <- list(
    trips = data.table::data.table(trip_id = names(x = times), route_id = "r1"),
    stop_times = stop_times
  )

  return(value = gtfsio::new_gtfs(x = feed, subclass = "dt_gtfs"))
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

wrap_gtfs <- synthetic_feed(times = wrap_times)
wrap_gtfs$frequencies <- data.table::data.table(
  trip_id = "correct",
  start_time = c("23:00:00", "05:00:00", "22:00:00", "48:30:00", "25:00:00"),
  end_time = c("01:00:00", "06:00:00", "24:30:00", "00:10:00", "01:00:00"),
  headway_secs = 600L
)

# trips whose times still go back after the fix, which raise a warning

warn_gtfs <- synthetic_feed(
  times = list(
    small_back = list(arr = c("08:00:00", "08:05:00", "08:04:00")),
    exactly_12h = list(arr = c("20:00:00", "08:00:00")),
    back_after_fix = list(arr = c("24:30:00", "00:20:00"))
  )
)

trip_times <- function(gtfs, id) {
  st <- gtfs$stop_times[trip_id == id]
  return(value = list(arr = st$arrival_time, dep = st$departure_time))
}

expect_trip_times <- function(gtfs, id, expected) {
  if (is.null(x = expected$dep)) expected$dep <- expected$arr
  expect_identical(
    object = trip_times(gtfs = gtfs, id = id),
    expected = expected[c("arr", "dep")]
  )
}

# tests ---

test_that(desc = "raises error due to incorrect input types", code = {
  expect_error(object = tester(gtfs = unclass(x = wrap_gtfs)))

  no_arrival <- copy_gtfs_without_field(
    gtfs = wrap_gtfs,
    file = "stop_times",
    field = "arrival_time"
  )
  expect_error(object = tester(gtfs = no_arrival))

  bad_sequence <- copy_gtfs_diff_field_class(
    gtfs = wrap_gtfs,
    file = "stop_times",
    field = "stop_sequence",
    class = "character"
  )
  expect_error(object = tester(gtfs = bad_sequence))

  bad_end <- copy_gtfs_diff_field_class(
    gtfs = wrap_gtfs,
    file = "frequencies",
    field = "end_time",
    class = "factor"
  )
  expect_error(object = tester(gtfs = bad_end))

  expect_error(
    object = tester(
      gtfs = copy_gtfs_without_file(gtfs = wrap_gtfs, file = "stop_times")
    )
  )
})

test_that(desc = "results in a dt_gtfs object", code = {
  result <- tester()
  expect_s3_class(object = result, class = c("dt_gtfs", "gtfs", "list"))
  for (table in names(x = result)) {
    expect_s3_class(object = result[[table]], class = "data.table")
  }
})

test_that(desc = "moves the times after midnight one day later", code = {
  result <- expect_silent(object = tester())

  for (id in names(x = expected_times)) {
    expect_trip_times(gtfs = result, id = id, expected = expected_times[[id]])
  }

  # only the time columns change

  expect_identical(
    object = result$stop_times[, .(trip_id, stop_id, stop_sequence)],
    expected = wrap_gtfs$stop_times[, .(trip_id, stop_id, stop_sequence)]
  )
  expect_identical(object = result$trips, expected = wrap_gtfs$trips)
})

test_that(
  desc = "leaves rows without trip_id or stop_sequence unchanged",
  code = {
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

    result <- tester(gtfs = gtfs)
    expect_identical(
      object = result$stop_times[
        is.na(x = trip_id) | is.na(x = stop_sequence),
        arrival_time
      ],
      expected = c("00:05:00", "00:05:00")
    )
    expect_trip_times(
      gtfs = result,
      id = "arrival",
      expected = list(arr = c("23:00:00", "23:50:00", "24:10:00", "00:05:00"))
    )
  }
)

test_that(desc = "warns about times that still go back", code = {
  expect_warning(
    object = result <- tester(gtfs = warn_gtfs),
    class = "gtfstools_backwards_times"
  )

  expect_trip_times(
    gtfs = result,
    id = "small_back",
    expected = list(arr = c("08:00:00", "08:05:00", "08:04:00"))
  )
  expect_trip_times(
    gtfs = result,
    id = "exactly_12h",
    expected = list(arr = c("20:00:00", "08:00:00"))
  )
  expect_trip_times(
    gtfs = result,
    id = "back_after_fix",
    expected = list(arr = c("24:30:00", "24:20:00"))
  )

  # every trip is named in the warning

  warning_msg <- tryCatch(
    expr = tester(gtfs = warn_gtfs),
    warning = function(w) conditionMessage(c = w)
  )
  for (id in c("small_back", "exactly_12h", "back_after_fix")) {
    expect_match(object = warning_msg, regexp = id, fixed = TRUE)
  }
})

test_that(
  desc = "fixes end times earlier than start times in frequencies",
  code = {
    result <- tester()
    expect_identical(
      object = result$frequencies$end_time,
      expected = c("25:00:00", "06:00:00", "24:30:00", "72:10:00", "49:00:00")
    )
    expect_identical(
      object = result$frequencies$start_time,
      expected = wrap_gtfs$frequencies$start_time
    )

    no_frequencies <- copy_gtfs_without_file(
      gtfs = wrap_gtfs,
      file = "frequencies"
    )
    result <- tester(gtfs = no_frequencies)
    expect_null(object = result$frequencies)
    expect_trip_times(
      gtfs = result,
      id = "arrival",
      expected = expected_times$arrival
    )
  }
)

test_that(desc = "updates existing _secs columns", code = {
  gtfs <- convert_time_to_seconds(gtfs = wrap_gtfs)
  result <- tester(gtfs = gtfs)

  expect_identical(
    object = result$stop_times$arrival_time_secs,
    expected = string_to_seconds(string = result$stop_times$arrival_time)
  )
  expect_identical(
    object = result$stop_times$departure_time_secs,
    expected = string_to_seconds(string = result$stop_times$departure_time)
  )
  expect_identical(
    object = result$frequencies$end_time_secs,
    expected = string_to_seconds(string = result$frequencies$end_time)
  )
})

test_that(desc = "raises an error when a fixed time is out of range", code = {
  gtfs <- synthetic_feed(
    times = list(late = list(arr = c("9999:00:00", "00:10:00")))
  )
  expect_error(
    object = tester(gtfs = gtfs),
    class = "gtfstools_time_out_of_range"
  )

  gtfs <- wrap_gtfs
  gtfs$frequencies <- data.table::data.table(
    trip_id = "correct",
    start_time = "9999:00:00",
    end_time = "9990:00:00",
    headway_secs = 600L
  )
  expect_error(
    object = tester(gtfs = gtfs),
    class = "gtfstools_time_out_of_range"
  )
})

test_that(desc = "doesn't change given gtfs", code = {
  original_gtfs <- gtfsio::new_gtfs(
    x = lapply(X = wrap_gtfs, FUN = data.table::copy),
    subclass = "dt_gtfs"
  )
  gtfs <- gtfsio::new_gtfs(
    x = lapply(X = wrap_gtfs, FUN = data.table::copy),
    subclass = "dt_gtfs"
  )
  expect_identical(object = original_gtfs, expected = gtfs)

  result <- tester(gtfs = gtfs)
  expect_false(object = identical(x = result$stop_times, y = gtfs$stop_times))
  expect_false(object = identical(x = result$frequencies, y = gtfs$frequencies))
  expect_equal(object = original_gtfs, expected = gtfs, ignore_attr = TRUE)

  original_gtfs <- read_gtfs(path = poa_path)
  gtfs <- read_gtfs(path = poa_path)
  expect_identical(object = original_gtfs, expected = gtfs)

  result <- tester(gtfs = gtfs)
  expect_false(object = identical(x = result$stop_times, y = gtfs$stop_times))
  expect_equal(object = original_gtfs, expected = gtfs, ignore_attr = TRUE)
})

test_that(
  desc = "returns feeds without times after midnight unchanged",
  code = {
    spo_gtfs <- read_gtfs(path = spo_path)
    result <- expect_silent(object = tester(gtfs = spo_gtfs))
    expect_identical(object = result, expected = spo_gtfs)
  }
)

test_that(desc = "fixes the trips of poa that run past midnight", code = {
  poa_gtfs <- read_gtfs(path = poa_path)
  result <- expect_silent(object = tester(gtfs = poa_gtfs))

  changed <- result$stop_times$arrival_time != poa_gtfs$stop_times$arrival_time
  expect_length(object = unique(x = result$stop_times$trip_id[changed]), n = 10)

  expect_trip_times(
    gtfs = result,
    id = "T2-1@1#2310",
    expected = list(
      arr = c("23:10:00", rep(x = "", 60), "24:02:00"),
      dep = c("23:10:00", rep(x = "", 60), "24:02:00")
    )
  )
})

test_that(desc = "the internal fix can be restricted to some trips", code = {
  result <- fix_overnight_stop_times(gtfs = wrap_gtfs, trip_id = "arrival")
  expect_trip_times(
    gtfs = result,
    id = "arrival",
    expected = expected_times$arrival
  )
  expect_trip_times(
    gtfs = result,
    id = "arr_dep",
    expected = wrap_times$arr_dep
  )

  # with shuffled rows and an unknown id, the selected trips are fixed as when
  # every trip is fixed, and the others are left unchanged

  shuffled_gtfs <- wrap_gtfs
  shuffled_gtfs$stop_times <- wrap_gtfs$stop_times[
    rev(x = seq_len(length.out = nrow(x = wrap_gtfs$stop_times)))
  ]
  selected <- c("one_time", "double_wrap", "unknown")
  result <- fix_overnight_stop_times(gtfs = shuffled_gtfs, trip_id = selected)
  for (id in c("one_time", "double_wrap")) {
    expect_trip_times(
      gtfs = result,
      id = id,
      expected = lapply(X = expected_times[[id]], FUN = rev)
    )
  }
  expect_identical(
    object = result$stop_times[!trip_id %chin% selected],
    expected = shuffled_gtfs$stop_times[!trip_id %chin% selected]
  )

  expect_identical(
    object = fix_overnight_stop_times(
      gtfs = wrap_gtfs,
      trip_id = character(length = 0)
    ),
    expected = wrap_gtfs
  )
})

test_that(desc = "nested calls don't fix the times again", code = {
  poa_gtfs <- read_gtfs(path = poa_path)

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
        changes <- real_fix(
          gtfs = gtfs,
          trip_id = trip_id,
          warn = FALSE,
          detect_only = TRUE
        )
        if (isTRUE(x = changes)) n_fixes <<- n_fixes + 1
      }
      real_fix(
        gtfs = gtfs,
        trip_id = trip_id,
        warn = warn,
        by_reference = by_reference,
        detect_only = detect_only
      )
    }
  )
  count_fixes <- function(expr) {
    n_fixes <<- 0
    force(x = expr)
    return(value = n_fixes)
  }

  expect_identical(
    object = count_fixes(expr = fix_gtfs(gtfs = poa_gtfs)),
    expected = 1
  )
  expect_identical(
    object = count_fixes(
      expr = get_trip_speed(gtfs = poa_gtfs, from = "07:00:00", to = "09:00:00")
    ),
    expected = 1
  )
  expect_identical(
    object = count_fixes(
      expr = suppressWarnings(
        expr = build_graph(gtfs = poa_gtfs, from = "07:00:00", to = "08:00:00")
      )
    ),
    expected = 1
  )
  expect_identical(
    object = count_fixes(
      expr = get_stop_frequency(
        gtfs = poa_gtfs,
        from = "07:00:00",
        to = "08:00:00"
      )
    ),
    expected = 1
  )
  if (report_deps_available()) {
    expect_identical(
      object = count_fixes(
        expr = get_summary(
          gtfs = poa_gtfs,
          output_path = tempfile(pattern = "get_summary"),
          html_preview = FALSE
        )
      ),
      expected = 1
    )
  }

  by_reference_gtfs <- read_gtfs(path = poa_path)
  expect_identical(
    object = count_fixes(
      expr = set_dwell_time(
        gtfs = by_reference_gtfs,
        dwell_time = 30,
        by_reference = TRUE
      )
    ),
    expected = 1
  )

  # a function called by the user while a call is in progress (e.g. in a
  # calling handler) fixes the times of its own feed

  gtfs <- overnight_feed()
  duration <- NULL
  withCallingHandlers(
    expr = get_trip_duration(gtfs = gtfs, trip_id = c("W", "unknown")),
    warning = function(w) {
      duration <<- get_trip_duration(gtfs = gtfs, trip_id = "W")$duration
      invokeRestart(r = "muffleWarning")
    }
  )
  expect_equal(object = duration, expected = 45)

  gtfs <- overnight_feed()
  gtfs$frequencies[, `:=`(start_time = "9999:00:00", end_time = "9990:00:00")]
  expect_error(
    object = get_route_frequency(
      gtfs = gtfs,
      from = "23:00:00",
      to = "24:00:00"
    ),
    class = "gtfstools_time_out_of_range"
  )
})

test_that(
  desc = "has_overnight_trips() detects the times that would be fixed",
  code = {
    expect_true(object = has_overnight_trips(gtfs = read_gtfs(path = poa_path)))
    expect_true(object = has_overnight_trips(gtfs = wrap_gtfs))
    expect_true(object = has_overnight_trips(gtfs = overnight_feed()))

    # feeds without them, or whose times were already fixed

    expect_false(
      object = has_overnight_trips(gtfs = read_gtfs(path = spo_path))
    )
    expect_false(
      object = has_overnight_trips(
        gtfs = fix_overnight_times(gtfs = read_gtfs(path = poa_path))
      )
    )
    expect_false(
      object = has_overnight_trips(
        gtfs = fix_overnight_times(gtfs = overnight_feed())
      )
    )

    # times that go back by 12 hours or less are not fixed, so they don't count

    small_steps <- synthetic_feed(
      times = list(
        small_back = list(arr = c("08:00:00", "08:05:00", "08:04:00")),
        exactly_12h = list(arr = c("20:00:00", "08:00:00"))
      )
    )
    expect_silent(object = result <- has_overnight_trips(gtfs = small_steps))
    expect_false(object = result)

    # only frequencies entries that end before they start

    gtfs <- fix_overnight_times(gtfs = overnight_feed())
    gtfs$frequencies$end_time <- "01:00:00"
    expect_true(object = has_overnight_trips(gtfs = gtfs))

    # tables that can't be checked are skipped

    no_sequence <- copy_gtfs_without_field(
      gtfs = overnight_feed(),
      file = "stop_times",
      field = "stop_sequence"
    )
    no_sequence$frequencies <- NULL
    expect_false(object = has_overnight_trips(gtfs = no_sequence))
  }
)

test_that(
  desc = "warns about times that go back in feeds without times to fix",
  code = {
    # the feed has no times after midnight to fix, but its times that go back
    # by 12 hours or less, and its malformed times, are still reported

    small_back <- synthetic_feed(
      times = list(
        small_back = list(arr = c("08:00:00", "08:05:00", "08:04:00"))
      )
    )
    expect_false(object = has_overnight_trips(gtfs = small_back))
    expect_warning(
      object = result <- tester(gtfs = small_back),
      class = "gtfstools_backwards_times"
    )
    expect_identical(
      object = result$stop_times,
      expected = small_back$stop_times
    )

    malformed <- synthetic_feed(
      times = list(
        malformed = list(
          arr = c("08:00:00", "ab:cd", "08:10:00"),
          dep = c("08:00:00", "08:05:00", "08:10:00")
        )
      )
    )
    expect_warning(
      object = tester(gtfs = malformed),
      class = "gtfstools_malformed_time"
    )
  }
)
