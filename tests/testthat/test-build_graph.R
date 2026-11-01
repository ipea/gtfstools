spo_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
ber_path <- system.file("extdata/ber_gtfs.zip", package = "gtfstools")
ggl_path <- system.file("extdata/ggl_gtfs.zip", package = "gtfstools")
poa_path <- system.file("extdata/poa_gtfs.zip", package = "gtfstools")
spo_gtfs <- read_gtfs(spo_path)

tester <- function(gtfs = spo_gtfs,
                   from = "07:00:00",
                   to = "08:00:00",
                   format = "gmns",
                   max_walk_dist = 300,
                   walk_speed = 5) {
  build_graph(gtfs, from, to, format, max_walk_dist, walk_speed)
}

# distances along a meridian, in degrees of latitude, with the earth radius
# used by the distance kernel

meters_to_degrees <- function(meters) meters / 6371010 * 180 / pi

new_feed <- function(...) {
  tables <- lapply(list(...), data.table::as.data.table)
  gtfsio::new_gtfs(tables, "dt_gtfs")
}

# stops along a meridian (the default positions are A at 0 m, B at 200 m, C
# at 1000 m and D at 1500 m)

new_stops <- function(stop_id = c("A", "B", "C", "D"),
                      meters = c(0, 200, 1000, 1500)) {
  data.table::data.table(
    stop_id = stop_id,
    stop_name = stop_id,
    stop_lat = meters_to_degrees(meters),
    stop_lon = 0
  )
}

new_stop_times <- function(trip_id, stop_id, arrival_time,
                           departure_time = arrival_time) {
  data.table::data.table(
    trip_id = trip_id,
    stop_id = stop_id,
    stop_sequence = seq_along(stop_id),
    arrival_time = arrival_time,
    departure_time = departure_time
  )
}

# the core feed: R1 (direction 0) has two full trips from A to D, with a
# dwell at B in T1, a short-turn from A to C and a trip departing before 7am,
# and R2 (direction 1) has a trip from D to C. stop B is listed twice in
# 'stops', and only its first entry is used

core_feed <- function() {
  stops <- rbind(
    new_stops(),
    data.table::data.table(
      stop_id = "B",
      stop_name = "B dup",
      stop_lat = meters_to_degrees(5000),
      stop_lon = 0
    )
  )

  stop_times <- rbind(
    new_stop_times(
      "T1",
      c("A", "B", "C", "D"),
      c("07:00:00", "07:02:00", "07:06:00", "07:10:00"),
      c("07:00:00", "07:03:00", "07:06:00", "07:10:00")
    ),
    new_stop_times(
      "T2",
      c("A", "B", "C", "D"),
      c("07:30:00", "07:32:00", "07:36:00", "07:40:00")
    ),
    new_stop_times(
      "T3",
      c("A", "B", "C"),
      c("07:15:00", "07:18:00", "07:21:00")
    ),
    new_stop_times(
      "T4",
      c("A", "B", "C", "D"),
      c("06:50:00", "06:52:00", "06:56:00", "07:00:00")
    ),
    new_stop_times(
      "T5",
      c("D", "C"),
      c("07:10:00", "07:14:00")
    )
  )

  new_feed(
    stops = stops,
    trips = data.table::data.table(
      trip_id = paste0("T", 1:5),
      route_id = c("R1", "R1", "R1", "R1", "R2"),
      direction_id = c(0L, 0L, 0L, 0L, 1L)
    ),
    stop_times = stop_times
  )
}

na_int <- NA_integer_
na_chr <- NA_character_

# tests -------------------------------------------------------------------

test_that("raises errors due to incorrect input types/value", {
  expect_error(tester(unclass(spo_gtfs)))
  expect_error(tester(from = "7:00:00"))
  expect_error(tester(to = 8))
  expect_error(
    tester(from = "08:00:00", to = "07:00:00"),
    class = "gtfstools_invalid_time_of_day"
  )
  expect_error(
    tester(from = "08:00:00", to = "08:00:00"),
    class = "gtfstools_invalid_time_of_day"
  )
  expect_error(tester(format = "sf"))
  expect_error(tester(format = c("gmns", "igraph")))
  expect_error(tester(max_walk_dist = -1))
  expect_error(tester(max_walk_dist = Inf))
  expect_error(tester(walk_speed = 0), class = "gtfstools_invalid_speed")
  expect_error(tester(walk_speed = -5), class = "gtfstools_invalid_speed")
  expect_error(tester(walk_speed = "5"))

  missing_fields <- list(
    c("stops", "stop_lat"),
    c("trips", "route_id"),
    c("stop_times", "arrival_time")
  )
  for (field in missing_fields) {
    no_field_gtfs <- copy_gtfs_without_field(spo_gtfs, field[1], field[2])
    expect_error(tester(no_field_gtfs), class = "missing_required_field")
  }

  wrong_class_fields <- list(
    c("stops", "stop_id"),
    c("trips", "trip_id"),
    c("stop_times", "departure_time")
  )
  for (field in wrong_class_fields) {
    factor_gtfs <- copy_gtfs_diff_field_class(
      spo_gtfs,
      field[1],
      field[2],
      "factor"
    )
    expect_error(tester(factor_gtfs), class = "wrong_class_field")
  }
})

test_that("results in a list of gmns tables", {
  graph <- tester()
  expect_type(graph, "list")
  expect_identical(names(graph), c("node", "link", "config"))
  expect_s3_class(graph$node, "data.table")
  expect_s3_class(graph$link, "data.table")
  expect_s3_class(graph$config, "data.table")

  empty <- empty_service_network()
  expect_identical(lapply(graph$node, class), lapply(empty$node, class))
  expect_identical(lapply(graph$link, class), lapply(empty$link, class))

  expect_identical(
    graph$config,
    data.table::data.table(
      short_length = "m",
      long_length = "m",
      speed = "km/h",
      crs = "EPSG:4326",
      version_number = 0.96,
      id_type = "integer",
      from = "07:00:00",
      to = "08:00:00"
    )
  )
})

test_that("builds the expected network", {
  graph <- tester(core_feed())

  stop_lat <- meters_to_degrees(c(0, 200, 1000, 1500))
  expected_node <- data.table::data.table(
    node_id = 1:10,
    x_coord = 0,
    y_coord = stop_lat[c(1:4, 1, 2, 3, 3, 4, 4)],
    node_type = rep(c("stop", "service"), c(4, 6)),
    parent_node_id = c(rep(na_int, 4), 1L, 2L, 3L, 3L, 4L, 4L),
    stop_id = c("A", "B", "C", "D", "A", "B", "C", "C", "D", "D"),
    stop_name = c("A", "B", "C", "D", "A", "B", "C", "C", "D", "D"),
    route_id = c(rep(na_chr, 4), "R1", "R1", "R1", "R2", "R1", "R2"),
    direction_id = c(rep(na_int, 4), 0L, 0L, 0L, 1L, 0L, 1L),
    inferred_direction = na_int,
    visit = c(rep(na_int, 4), rep(1L, 6))
  )
  expect_equal(graph$node, expected_node)

  # in-vehicle times are the mean of the trips' running times (without the
  # dwell at B in T1): (2 + 2 + 3) / 3 from A to B and (3 + 4 + 3) / 3 from B
  # to C. the waits are half the headway of the departures between 7am and
  # 8am, and the transfer between A and B takes 200 m at 5 km/h

  in_vehicle_length <- c(200, 800, 500, 500)
  in_vehicle_time <- c(7 / 3, 10 / 3, 4, 4)
  expected_link <- data.table::data.table(
    link_id = 1:16,
    from_node_id = c(5L, 6L, 7L, 10L, 1:4, 5:10, 1L, 2L),
    to_node_id = c(6L, 7L, 9L, 8L, 5L, 6L, 7L, 10L, 1:3, 3L, 4L, 4L, 2L, 1L),
    directed = TRUE,
    length = c(in_vehicle_length, rep(0, 10), 200, 200),
    free_speed = c(
      in_vehicle_length / 1000 / (in_vehicle_time / 60),
      rep(NA, 10),
      5,
      5
    ),
    link_type = rep(
      c("in_vehicle", "boarding", "alighting", "transfer"),
      c(4, 4, 6, 2)
    ),
    travel_time = c(in_vehicle_time, 10, 10, 15, 30, rep(0, 6), 2.4, 2.4),
    departures = c(3L, 3L, 2L, 1L, 3L, 3L, 2L, 1L, rep(na_int, 8)),
    route_id = c(
      "R1", "R1", "R1", "R2",
      "R1", "R1", "R1", "R2",
      "R1", "R1", "R1", "R2", "R1", "R2",
      na_chr, na_chr
    ),
    direction_id = c(
      0L, 0L, 0L, 1L,
      0L, 0L, 0L, 1L,
      0L, 0L, 0L, 1L, 0L, 1L,
      na_int, na_int
    ),
    inferred_direction = na_int
  )
  expect_equal(graph$link, expected_link)
})

test_that("separates the visits of trips that visit a stop twice", {
  # the trip goes from A to D and back to B before heading to E, so it can't
  # take a shortcut from its first visit to B to E

  stops <- new_stops(
    c("A", "B", "C", "D", "E"),
    c(0, 1000, 2000, 3000, 1000)
  )
  stops[stop_id == "E", stop_lon := meters_to_degrees(1000)]
  gtfs <- new_feed(
    stops = stops,
    trips = data.table::data.table(
      trip_id = "L1",
      route_id = "R1",
      direction_id = 0L
    ),
    stop_times = new_stop_times(
      "L1",
      c("A", "B", "C", "D", "C", "B", "E"),
      sprintf("07:%02d:00", seq(0, 12, by = 2))
    )
  )

  graph <- tester(gtfs, max_walk_dist = 0)
  services <- graph$node[node_type == "service"]
  expect_identical(services[stop_id == "B", visit], 1:2)
  expect_identical(services[stop_id == "C", visit], 1:2)
  expect_identical(services[stop_id == "A", visit], 1L)

  skip_if_not_installed("igraph")

  igraph_graph <- tester(gtfs, format = "igraph", max_walk_dist = 0)
  travel_time <- igraph::distances(
    igraph_graph,
    v = "1",
    to = "5",
    mode = "out",
    weights = igraph::E(igraph_graph)$travel_time
  )

  # the wait at A (half of 60 minutes) plus the 12 minutes of the whole trip

  expect_equal(as.vector(travel_time), 30 + 12)
})

test_that("infers the direction of trips without direction_id", {
  # no bundled feed both lacks direction_id and has trips running in both
  # directions, so this is the only test of the inferred directions. N1 and
  # N3 share the pair A -> B, so they are in the same direction, while N2 runs
  # the other way

  gtfs <- new_feed(
    stops = new_stops(c("A", "B", "C"), c(0, 1000, 2000)),
    trips = data.table::data.table(
      trip_id = c("N1", "N2", "N3"),
      route_id = "R1"
    ),
    stop_times = rbind(
      new_stop_times(
        "N1",
        c("A", "B", "C"),
        c("07:00:00", "07:05:00", "07:10:00")
      ),
      new_stop_times(
        "N2",
        c("C", "B", "A"),
        c("07:00:00", "07:05:00", "07:10:00")
      ),
      new_stop_times("N3", c("A", "B"), c("07:20:00", "07:25:00"))
    )
  )

  graph <- tester(gtfs, max_walk_dist = 0)
  services <- graph$node[node_type == "service"]
  expect_true(all(is.na(services$direction_id)))
  expect_identical(services$stop_id, c("A", "A", "B", "B", "C", "C"))
  expect_identical(services$inferred_direction, c(1L, 2L, 1L, 2L, 1L, 2L))

  # at B, each direction has one departure, and so a wait of 30 minutes. A has
  # two departures in direction 1 (N1 and N3)

  boarding <- graph$link[link_type == "boarding"]
  boarding[, stop_id := graph$node$stop_id[to_node_id]]
  expect_identical(boarding$stop_id, c("A", "B", "B", "C"))
  expect_identical(boarding$inferred_direction, c(1L, 1L, 2L, 2L))
  expect_identical(boarding$departures, c(2L, 1L, 1L, 1L))
  expect_equal(boarding$travel_time, c(15, 30, 30, 30))

  # a blank direction_id is treated as a missing field

  na_direction_gtfs <- new_feed(
    stops = gtfs$stops,
    trips = data.table::copy(gtfs$trips)[, direction_id := NA_integer_],
    stop_times = gtfs$stop_times
  )
  expect_identical(tester(na_direction_gtfs, max_walk_dist = 0), graph)
})

test_that("counts the departures generated from 'frequencies'", {
  gtfs <- new_feed(
    stops = new_stops(c("A", "B"), c(0, 1000)),
    trips = data.table::data.table(
      trip_id = c("F1", "F2"),
      route_id = "R1",
      direction_id = 0L
    ),
    stop_times = new_stop_times("F1", c("A", "B"), c("06:00:00", "06:05:00")),
    frequencies = data.table::data.table(
      trip_id = c("F1", "F2"),
      start_time = "07:00:00",
      end_time = "08:00:00",
      headway_secs = 900L
    )
  )

  # F2 has no stop_times, so it is dropped without a warning

  expect_no_warning(graph <- tester(gtfs, max_walk_dist = 0))

  link <- graph$link
  expect_identical(link[link_type == "in_vehicle", departures], 4L)
  expect_equal(link[link_type == "in_vehicle", travel_time], 5)
  expect_identical(link[link_type == "boarding", departures], 4L)
  expect_equal(link[link_type == "boarding", travel_time], 60 / 4 / 2)
})

test_that("handles times after midnight and decreasing times", {
  gtfs <- new_feed(
    stops = new_stops(c("A", "B"), c(0, 1000)),
    trips = data.table::data.table(
      trip_id = c("P1", "W1", "D1"),
      route_id = c("R1", "R2", "R3"),
      direction_id = 0L
    ),
    stop_times = rbind(
      new_stop_times("P1", c("A", "B"), c("24:30:00", "24:35:00")),
      new_stop_times("W1", c("A", "B"), c("23:58:00", "00:02:00")),
      new_stop_times("D1", c("A", "B"), c("08:02:00", "07:58:00"))
    )
  )

  late_graph <- tester(gtfs, from = "24:00:00", to = "25:00:00")
  in_vehicle <- late_graph$link[link_type == "in_vehicle"]
  expect_identical(in_vehicle$route_id, "R1")
  expect_equal(in_vehicle$travel_time, 5)

  # W1 is written going back to 00:02 after midnight, which is fixed to
  # 24:02 first, so it departs at 23:58 and runs at night

  night_graph <- tester(gtfs, from = "23:00:00", to = "24:00:00")
  in_vehicle <- night_graph$link[link_type == "in_vehicle"]
  expect_identical(in_vehicle$route_id, "R2")
  expect_equal(in_vehicle$travel_time, 4)

  early_graph <- tester(gtfs, from = "00:00:00", to = "01:00:00")
  expect_false("R2" %chin% early_graph$link$route_id)

  # D1 goes back by less than 12 hours, so it departs at its earliest time
  # and its segment has no travel time

  expect_warning(
    day_graph <- tester(gtfs, from = "07:00:00", to = "09:00:00"),
    class = "gtfstools_links_without_travel_time"
  )
  in_vehicle <- day_graph$link[link_type == "in_vehicle"]
  expect_identical(in_vehicle$route_id, "R3")
  expect_identical(in_vehicle$travel_time, NA_real_)
  expect_identical(in_vehicle$free_speed, NA_real_)

  # in 'frequencies', an end time earlier than the start time is fixed too,
  # so P1 departs every 10 minutes from 23:00:00 until 25:00:00

  gtfs$frequencies <- data.table::data.table(
    trip_id = "P1",
    start_time = "23:00:00",
    end_time = "01:00:00",
    headway_secs = 600L
  )
  night_graph <- tester(gtfs, from = "23:00:00", to = "24:00:00")
  in_vehicle <- night_graph$link[link_type == "in_vehicle" & route_id == "R1"]
  expect_identical(in_vehicle$departures, 6L)
})

test_that("uses the first entry of duplicated trip_ids", {
  gtfs <- core_feed()
  gtfs$trips <- rbind(
    gtfs$trips,
    data.table::data.table(trip_id = "T1", route_id = "R9", direction_id = 1L)
  )

  graph <- tester(gtfs)
  expect_false("R9" %chin% graph$node$route_id)
  expect_equal(graph, tester(core_feed()))
})

test_that("merges consecutive entries at the same stop", {
  gtfs <- new_feed(
    stops = new_stops(c("A", "B", "C"), c(0, 1000, 2000)),
    trips = data.table::data.table(
      trip_id = "T1",
      route_id = "R1",
      direction_id = 0L
    ),
    stop_times = new_stop_times(
      "T1",
      c("A", "B", "B", "C"),
      c("07:00:00", "07:02:00", "07:03:00", "07:06:00"),
      c("07:00:00", "07:02:00", "07:04:00", "07:06:00")
    )
  )

  graph <- tester(gtfs, max_walk_dist = 0)
  link <- graph$link
  expect_false(any(link$from_node_id == link$to_node_id))
  expect_identical(graph$node[node_type == "service", visit], rep(1L, 3))

  # the visit to B arrives at 07:02 and departs at 07:04, and B has a single
  # departure

  expect_equal(link[link_type == "in_vehicle", travel_time], c(2, 2))
  expect_identical(link[link_type == "boarding", departures], c(1L, 1L))
})

test_that("counts the same departures as get_stop_frequency()", {
  # over a whole day, every trip departs within the time of day, so the
  # departures of each boarding link are the departures of its route and
  # direction from its stop. this holds for spo and ber because they have no
  # blank departure times (which get_stop_frequency() doesn't count), and no
  # stops visited twice by a trip

  for (path in c(spo_path, ber_path)) {
    gtfs <- read_gtfs(path)
    expect_false(any(is_blank_time(gtfs$stop_times$departure_time)))

    graph <- tester(gtfs, from = "00:00:00", to = "47:59:59")
    expect_true(all(graph$node$visit %in% c(NA, 1L)))

    boarding <- graph$link[link_type == "boarding"]
    boarding[, stop_id := graph$node$stop_id[to_node_id]]
    boarding <- boarding[
      ,
      .(departures = sum(departures)),
      keyby = c("stop_id", "route_id", "direction_id")
    ]

    stop_frequency <- get_stop_frequency(
      gtfs,
      by_route = TRUE,
      from = "00:00:00",
      to = "47:59:59"
    )
    stop_frequency <- stop_frequency[
      ,
      .(departures = sum(departures)),
      keyby = c("stop_id", "route_id", "direction_id")
    ]

    expect_gt(nrow(boarding), 0)
    expect_equal(boarding, stop_frequency, ignore_attr = TRUE)
  }
})

test_that("results in consistent networks with other feeds", {
  graphs <- list(
    spo = tester(),
    ber = tester(read_gtfs(ber_path)),
    ggl = suppressWarnings(tester(read_gtfs(ggl_path), to = "23:00:00"))
  )

  for (graph in graphs) {
    node <- graph$node
    link <- graph$link
    expect_gt(nrow(link), 0)

    expect_identical(node$node_id, seq_len(nrow(node)))
    expect_identical(link$link_id, seq_len(nrow(link)))
    expect_true(all(c(link$from_node_id, link$to_node_id) %in% node$node_id))

    is_service <- node$node_type == "service"
    alighting <- link[link_type == "alighting"]
    expect_identical(alighting$from_node_id, node$node_id[is_service])
    expect_identical(
      alighting$to_node_id,
      node$parent_node_id[alighting$from_node_id]
    )

    # each transfer link has a reverse link, in the second half of the table

    transfer <- link[link_type == "transfer"]
    half <- nrow(transfer) / 2
    reverse <- c(seq_len(half) + half, seq_len(half))
    expect_true(all(transfer$length <= 300))
    expect_identical(transfer$from_node_id, transfer$to_node_id[reverse])
    expect_identical(transfer$to_node_id, transfer$from_node_id[reverse])
    expect_true(all(node$node_type[transfer$from_node_id] == "stop"))
  }

  expect_gt(nrow(graphs$spo$link[link_type == "transfer"]), 0)
})

test_that("warns about stops without coordinates and untimed links", {
  # the stops of ggl's trips are not listed in 'stops', and its trips have
  # blank intermediate times

  ggl_gtfs <- read_gtfs(ggl_path)
  expect_warning(
    expect_warning(
      graph <- tester(ggl_gtfs, to = "23:00:00"),
      class = "gtfstools_stops_without_coordinates"
    ),
    class = "gtfstools_links_without_travel_time"
  )

  stop_nodes <- graph$node[node_type == "stop"]
  expect_true(all(is.na(stop_nodes$x_coord) & is.na(stop_nodes$y_coord)))
  expect_identical(nrow(graph$link[link_type == "transfer"]), 0L)
  expect_true(all(is.na(graph$link[link_type == "in_vehicle", length])))

  poa_gtfs <- read_gtfs(poa_path)
  expect_warning(
    tester(poa_gtfs),
    class = "gtfstools_links_without_travel_time"
  )
})

test_that("results in empty networks when no trip departs", {
  graph <- tester(from = "03:00:00", to = "03:00:01")
  empty <- empty_service_network()
  expect_identical(graph$node, empty$node)
  expect_identical(graph$link, empty$link)

  skip_if_not_installed("tidygraph")

  igraph_graph <- tester(from = "03:00:00", to = "03:00:01", format = "igraph")
  expect_equal(igraph::vcount(igraph_graph), 0)
  expect_equal(igraph::ecount(igraph_graph), 0)

  tidygraph_graph <- tester(
    from = "03:00:00",
    to = "03:00:01",
    format = "tidygraph"
  )
  expect_equal(igraph::vcount(tidygraph_graph), 0)
})

test_that("results in igraph and tidygraph graphs", {
  skip_if_not_installed("igraph")

  graph <- tester()
  igraph_graph <- tester(format = "igraph")
  expect_s3_class(igraph_graph, "igraph")
  expect_true(igraph::is_directed(igraph_graph))
  expect_equal(igraph::vcount(igraph_graph), nrow(graph$node))
  expect_equal(igraph::ecount(igraph_graph), nrow(graph$link))
  expect_identical(
    igraph::V(igraph_graph)$name,
    as.character(graph$node$node_id)
  )
  expect_identical(igraph::V(igraph_graph)$stop_name, graph$node$stop_name)
  expect_equal(igraph::E(igraph_graph)$travel_time, graph$link$travel_time)

  edges <- igraph::as_edgelist(igraph_graph)
  expect_identical(edges[, 1], as.character(graph$link$from_node_id))
  expect_identical(edges[, 2], as.character(graph$link$to_node_id))

  skip_if_not_installed("tidygraph")

  tidygraph_graph <- tester(format = "tidygraph")
  expect_s3_class(tidygraph_graph, "tbl_graph")
  expect_equal(igraph::vcount(tidygraph_graph), nrow(graph$node))
  expect_equal(igraph::ecount(tidygraph_graph), nrow(graph$link))
  expect_identical(
    igraph::V(tidygraph_graph)$name,
    as.character(graph$node$node_id)
  )
})

test_that("handles the optional direction_id and stop_name fields", {
  no_name_gtfs <- copy_gtfs_without_field(spo_gtfs, "stops", "stop_name")
  graph <- tester(no_name_gtfs)
  expect_true(all(is.na(graph$node$stop_name)))
  expect_identical(graph$link, tester()$link)

  optional_fields <- list(c("trips", "direction_id"), c("stops", "stop_name"))
  for (field in optional_fields) {
    factor_gtfs <- copy_gtfs_diff_field_class(
      spo_gtfs,
      field[1],
      field[2],
      "factor"
    )
    expect_error(tester(factor_gtfs), class = "wrong_class_field")
  }
})

test_that("merged visits take the first and the last known times", {
  gtfs <- new_feed(
    stops = new_stops(c("A", "B", "C"), c(0, 1000, 2000)),
    trips = data.table::data.table(
      trip_id = "T1",
      route_id = "R1",
      direction_id = 0L
    ),
    stop_times = new_stop_times(
      "T1",
      c("A", "B", "B", "C"),
      c("07:00:00", "", "07:03:30", "07:06:00"),
      c("07:00:00", "07:03:00", "", "07:06:00")
    )
  )

  # the visit to B arrives at 07:03, the departure of its first entry, and
  # departs at 07:03:30, the arrival of its second entry

  expect_no_warning(graph <- tester(gtfs, max_walk_dist = 0))
  expect_equal(
    graph$link[link_type == "in_vehicle", travel_time],
    c(3, 2.5)
  )
})

test_that("doesn't error with missing ids", {
  gtfs <- new_feed(
    stops = new_stops(c("A", "B"), c(0, 1000)),
    trips = data.table::data.table(
      trip_id = c("T1", NA),
      route_id = "R1",
      direction_id = 0L
    ),
    stop_times = rbind(
      new_stop_times(
        "T1",
        c("A", NA, "B"),
        c("07:00:00", "07:02:00", "07:04:00")
      ),
      new_stop_times(NA_character_, c("A", "B"), c("07:10:00", "07:14:00"))
    )
  )

  # the stop without id has no coordinates, and the trip without id is not
  # included

  expect_warning(
    graph <- tester(gtfs, max_walk_dist = 0),
    class = "gtfstools_stops_without_coordinates"
  )
  expect_identical(nrow(graph$link[link_type == "in_vehicle"]), 2L)
  expect_identical(graph$link[link_type == "boarding", departures], c(1L, 1L))
})

test_that("infers the direction of long chains of trips", {
  # each trip shares a pair of stops with the next one, so all of them are in
  # the same direction. the trips are numbered in zigzag order along the
  # chain (1, 200, 2, 199, ...), which takes a pass per trip without hooking

  n_trips <- 200L
  stop_ids <- sprintf("S%03d", seq_len(n_trips + 2L))
  half <- n_trips / 2L
  zigzag <- as.vector(rbind(seq_len(half), rev(seq_len(half)) + half))
  trip_ids <- sprintf("T%03d", zigzag)
  stop_times <- data.table::rbindlist(
    lapply(
      seq_len(n_trips),
      function(i) {
        new_stop_times(
          trip_ids[i],
          stop_ids[i + 0:2],
          c("07:00:00", "07:01:00", "07:02:00")
        )
      }
    )
  )

  gtfs <- new_feed(
    stops = new_stops(stop_ids, seq_along(stop_ids) * 1000),
    trips = data.table::data.table(trip_id = trip_ids, route_id = "R1"),
    stop_times = stop_times
  )

  graph <- tester(gtfs, max_walk_dist = 0)
  services <- graph$node[node_type == "service"]
  expect_identical(nrow(services), n_trips + 2L)
  expect_identical(unique(services$inferred_direction), 1L)
})

test_that("warns when transfer links may use a lot of memory", {
  local_mocked_bindings(max_stop_pairs_without_warning = function() 10)
  expect_warning(tester(), class = "gtfstools_many_stops_warning")
})

test_that("doesn't change given gtfs", {
  original_gtfs <- read_gtfs(spo_path)
  gtfs <- read_gtfs(spo_path)
  expect_identical(original_gtfs, gtfs)

  graph <- tester(gtfs)
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  gtfs <- core_feed()
  original_gtfs <- core_feed()
  graph <- tester(gtfs)
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)

  # the directions of trips without direction_id are inferred

  gtfs <- copy_gtfs_without_field(read_gtfs(spo_path), "trips", "direction_id")
  original_gtfs <- copy_gtfs_without_field(
    read_gtfs(spo_path),
    "trips",
    "direction_id"
  )
  graph <- tester(gtfs)
  expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)
})
