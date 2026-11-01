#' Build a transit network graph
#'
#' Builds a frequency-based transit network from the trips that depart within
#' a time of day, and returns it as a set of tables in the General Modeling
#' Network Specification (GMNS) format or as an `{igraph}` or `{tidygraph}`
#' graph. The network can be used in transit assignment models and in graph
#' analyses, such as finding the shortest travel times between stops.
#'
#' @template gtfs
#' @param from A string. The starting point of the time of day, in the
#'   "HH:MM:SS" format.
#' @param to A string. The ending point of the time of day, in the "HH:MM:SS"
#'   format. Must be later than `from`.
#' @param format A string. The format of the graph: `"gmns"` (the default),
#'   `"igraph"` or `"tidygraph"`. The last two require the packages of the
#'   same name, which the function offers to install in interactive sessions.
#' @param max_walk_dist A number. The maximum great-circle distance, in
#'   meters, between two stops connected by walking transfer links. Defaults
#'   to 300.
#' @param walk_speed A number. The walking speed, in km/h, used to calculate
#'   the travel time of transfer links. Defaults to 5.
#'
#' @return With `format = "gmns"`, a list with the `data.table`s `node`, `link`
#'   and `config`, named after the GMNS files. With `format = "igraph"`, a
#'   directed `igraph` graph, and with `format = "tidygraph"`, a directed
#'   `tbl_graph`. Their vertices and edges have the columns of the `node` and
#'   `link` tables as attributes, and the `name` of each vertex is its
#'   `node_id`, as a string.
#'
#' @section Details:
#' Nodes (`node_type`) are `"stop"` nodes, one per stop visited by the trips,
#' at the stop's coordinates, and `"service"` nodes, one per route and
#' direction at each of its stops, at the coordinates of the stop (their
#' `parent_node_id`). Links (`link_type`) are all directed:
#'
#' - `"in_vehicle"` links connect the service nodes of consecutive stops of
#'   the trips. `travel_time` is the mean time from the departure at a stop to
#'   the arrival at the next, over the trips with both times (decreasing times
#'   are not used), weighted by their departures. `departures` is the number
#'   of departures of the trips of the network that run through the link.
#'   `length` is the great-circle distance between the stops, as in
#'   [get_stop_distances()], and `free_speed` the length divided by the travel
#'   time (`NA` when the travel time is 0 or either is missing).
#' - `"boarding"` links connect each stop to the service nodes from which
#'   trips depart. `departures` is the number of departures from the stop of
#'   the trips of the network, so it may include departures after `to` from
#'   stops far along their routes. `travel_time` is half the mean headway (the
#'   length of the time of day divided by `departures`).
#' - `"alighting"` links connect each service node back to its stop, with a
#'   `travel_time` of 0.
#' - `"transfer"` links connect, in both directions, the stops at most
#'   `max_walk_dist` apart. `travel_time` is the length divided by
#'   `walk_speed`, which is also their `free_speed`.
#'
#' Lengths are in meters, travel times in minutes and speeds in km/h.
#' Boarding and alighting links have a `length` of 0 and an `NA` `free_speed`;
#' alighting and transfer links have `NA` `departures`. `route_id`,
#' `direction_id` and `inferred_direction` are those of the link's service
#' node, and `NA` in transfer links.
#'
#' The network includes the trips that depart from their first stop at or
#' after `from` and before `to`, as in [get_route_frequency()], so trips
#' already running at `from` are not included. Trips listed in `frequencies`
#' are included once per departure generated within the time of day, with
#' their `stop_times` entries as templates. Trips without `stop_times` entries
#' are not included. The trips of every `service_id` are pooled, so the feed
#' should usually be filtered to a single day first, with [filter_by_date()]
#' or [filter_by_weekday()]. Departures after midnight have times past
#' "24:00:00", so use a time of day such as "24:00:00"-"26:00:00" for them.
#' Times after midnight written as early morning times (e.g. `"00:30:00"`
#' instead of `"24:30:00"`) are first fixed with [fix_overnight_times()], as
#' are `end_time`s earlier than `start_time`s in `frequencies`, so these trips
#' are placed at their real times. Trips whose times still go back are placed
#' by their earliest time.
#'
#' Within a trip, consecutive `stop_times` entries at the same stop are one
#' visit, arriving at their first known time and departing at their last. A
#' trip that visits a stop more than once uses a different service node at
#' each visit (`visit` 1, 2, ...).
#'
#' Directions come from the `direction_id` field of `trips`. Trips without it
#' (or with a blank `direction_id`) get an `inferred_direction` instead: trips
#' of a route that share a pair of consecutive stops, in the same order, are
#' in the same direction, and so are trips that share pairs with them. The
#' opposite directions of routes that share a pair of stops in the same order
#' (e.g. through a one-way loop or street) are thus inferred as a single
#' direction. Trips with a blank `direction_id` are never assigned the
#' direction of other trips of their route.
#'
#' In-vehicle links whose trips all have blank or decreasing times have an
#' `NA` `travel_time`, with a warning; `igraph::distances()` doesn't accept it
#' as a weight, and blank times can be filled beforehand with
#' [interpolate_stop_times()]. Alighting links, in-vehicle links between stops
#' with the same times and transfer links between stops at the same
#' coordinates have a travel time of 0; `igraph::closeness()` and
#' `igraph::betweenness()` require positive weights.
#'
#' Departures are counted at every visit but the last of each trip, even with
#' a blank departure time, unlike in [get_stop_frequency()]. The `transfers`
#' and `pathways` tables, `parent_station`s and the `pickup_type` and
#' `drop_off_type` fields are not used. Large values of `max_walk_dist` in
#' dense feeds raise a warning when comparing the pairs of stops may use a lot
#' of memory, or an error when there are too many pairs. Transfer links are
#' not created across the antimeridian.
#'
#' In the GMNS format, `node_id`, `x_coord`, `y_coord`, `node_type`,
#' `parent_node_id`, `link_id`, `from_node_id`, `to_node_id`, `directed`,
#' `length` and `free_speed` are GMNS fields; the other columns are additional
#' fields, as allowed by GMNS. `config` lists the units, the coordinate
#' reference system (EPSG:4326), the GMNS version (0.96) and the time of day.
#' Stops not listed in `stops` or without coordinates have `NA` coordinates,
#' with a warning (GMNS requires them). Free speeds may exceed the 200 km/h
#' maximum checked by GMNS validators.
#'
#' @seealso The "Building transit network graphs" vignette
#'   (`vignette("graphs", package = "gtfstools")`), which shows how to
#'   analyse and plot the network with `{igraph}`, `{tidygraph}`,
#'   `{sfnetworks}` and `{ggraph}`.
#'
#' @examples
#' \dontshow{
#'   old_dt_threads <- data.table::setDTthreads(1)
#'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
#' }
#' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
#' gtfs <- read_gtfs(data_path)
#'
#' # the services of every day are pooled together, so only the services of a
#' # single weekday are kept
#' gtfs <- filter_by_weekday(gtfs, "wednesday")
#'
#' graph <- build_graph(gtfs, from = "07:00:00", to = "08:00:00")
#' names(graph)
#' head(graph$node)
#' head(graph$link)
#'
#' # the tables can be written to the csv files of a GMNS network
#' gmns_dir <- tempfile("gmns")
#' dir.create(gmns_dir)
#' for (table in names(graph)) {
#'   gmns_file <- file.path(gmns_dir, paste0(table, ".csv"))
#'   data.table::fwrite(graph[[table]], gmns_file)
#' }
#' list.files(gmns_dir)
#'
#' @examplesIf requireNamespace("igraph", quietly = TRUE)
#' # the shortest travel times, in minutes, from a stop to the other stops
#' graph <- build_graph(
#'   gtfs,
#'   from = "07:00:00",
#'   to = "08:00:00",
#'   format = "igraph"
#' )
#' stop_nodes <- igraph::V(graph)[igraph::V(graph)$node_type == "stop"]
#' travel_times <- igraph::distances(
#'   graph,
#'   v = stop_nodes[1],
#'   to = stop_nodes,
#'   mode = "out",
#'   weights = igraph::E(graph)$travel_time
#' )
#'
#' # stops that can't be reached have an infinite travel time
#' is_reachable <- is.finite(travel_times)
#' sum(is_reachable)
#' summary(travel_times[is_reachable])
#'
#' @export
build_graph <- function(gtfs,
                        from,
                        to,
                        format = "gmns",
                        max_walk_dist = 300,
                        walk_speed = 5) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)
  checkmate::assert_string(from, pattern = time_pattern)
  checkmate::assert_string(to, pattern = time_pattern)
  checkmate::assert_string(format)
  checkmate::assert_names(format, subset.of = c("gmns", "igraph", "tidygraph"))
  checkmate::assert_number(max_walk_dist, lower = 0, finite = TRUE)
  checkmate::assert_number(walk_speed)

  if (walk_speed <= 0 || !is.finite(walk_speed)) {
    cli::cli_abort(
      "{.arg walk_speed} must be positive and finite.",
      class = "gtfstools_invalid_speed"
    )
  }

  window <- time_of_day_window(from, to)
  from_secs <- window[1]
  to_secs <- window[2]

  # igraph and tidygraph are suggested packages. in interactive sessions, the
  # user is asked whether to install the missing one

  if (format != "gmns") {
    rlang::check_installed(
      format,
      reason = paste0("to use `format = \"", format, "\"`.")
    )
  }

  gtfsio::assert_field_class(
    gtfs,
    "stops",
    c("stop_id", "stop_lat", "stop_lon"),
    c("character", "numeric", "numeric")
  )
  gtfsio::assert_field_class(
    gtfs,
    "trips",
    c("trip_id", "route_id"),
    c("character", "character")
  )
  gtfsio::assert_field_class(
    gtfs,
    "stop_times",
    c("trip_id", "stop_id", "stop_sequence", "arrival_time", "departure_time"),
    c("character", "character", "integer", "character", "character")
  )

  if (gtfsio::check_field_exists(gtfs, "trips", "direction_id")) {
    gtfsio::assert_field_class(gtfs, "trips", "direction_id", "integer")
  }
  if (gtfsio::check_field_exists(gtfs, "stops", "stop_name")) {
    gtfsio::assert_field_class(gtfs, "stops", "stop_name", "character")
  }

  # times after midnight written as early morning times are fixed first, so
  # trips are placed at their real times. the departures of trips listed in
  # 'frequencies' come from its start and end times, which are fixed too
  # (fields of the wrong class are reported later, when they are used)

  gtfs <- fix_overnight_in_call(gtfs = gtfs, frequencies = TRUE)

  network <- build_service_network(
    gtfs,
    from_secs,
    to_secs,
    max_walk_dist,
    walk_speed
  )
  node <- network$node
  link <- network$link

  if (format == "gmns") {
    config <- data.table::data.table(
      short_length = "m",
      long_length = "m",
      speed = "km/h",
      crs = "EPSG:4326",
      version_number = 0.96,
      id_type = "integer",
      from = from,
      to = to
    )

    return(list(node = node, link = link, config = config))
  }

  # node_id is the row number of each node, so it is used directly as the
  # vertex index, without matching ids as strings. the name of each vertex is
  # its node_id, and no other attribute is called 'name', so nothing
  # overwrites the vertex names. the edge attributes are set first: once the
  # vertices have names, igraph pastes a "from|to" name for every edge when
  # setting them. the tidygraph graph is converted from the igraph one, since
  # tidygraph depends on igraph

  graph <- igraph::make_graph(
    as.vector(rbind(link$from_node_id, link$to_node_id)),
    n = nrow(node),
    directed = TRUE
  )
  igraph::edge_attr(graph) <- as.list(link)
  igraph::vertex_attr(graph) <- c(
    list(name = as.character(node$node_id)),
    as.list(node)
  )

  if (format == "tidygraph") graph <- tidygraph::as_tbl_graph(graph)

  return(graph)
}



#' Build the nodes and links of a transit network
#'
#' @param gtfs A GTFS object.
#' @param from_secs,to_secs The time of day, in seconds after midnight.
#' @param max_walk_dist The maximum distance of transfer links, in meters.
#' @param walk_speed The walking speed, in km/h.
#' @param call The environment of the call that errors are raised from.
#'
#' @return A list with the `node` and `link` tables of the network, as
#'   described in [build_graph()].
#'
#' @keywords internal
build_service_network <- function(gtfs,
                                  from_secs,
                                  to_secs,
                                  max_walk_dist,
                                  walk_speed,
                                  call = parent.frame()) {
  # each trip is weighted by its number of departures within the time of day.
  # trips without stop_times entries have no stops, so they are dropped
  # before prepare_trip_stops(), which would warn about them

  trip_ids <- unique(gtfs$trips$trip_id)
  trip_ids <- trip_ids[
    !is.na(trip_ids) & trip_ids %chin% gtfs$stop_times$trip_id
  ]

  departures <- get_trip_departures(gtfs, trip_ids)
  departures <- departures[
    departure_secs >= from_secs & departure_secs < to_secs
  ]
  weights <- departures[, .(weight = .N), keyby = trip_id]

  if (nrow(weights) == 0) return(empty_service_network())

  st <- prepare_trip_stops(
    gtfs,
    weights$trip_id,
    with_departure = TRUE,
    with_row = TRUE
  )
  st[
    ,
    `:=`(
      arrival_secs = string_to_seconds(gtfs$stop_times$arrival_time[row]),
      departure_secs = string_to_seconds(departure_time)
    )
  ]

  # these columns are not used below, and dropping them keeps the subsets
  # below from copying them

  unused_cols <- c(
    "stop_sequence",
    "departure_time",
    "row",
    "stop_lat",
    "stop_lon"
  )
  st[, (unused_cols) := NULL]

  # the rows of each trip, and of each run of consecutive entries of a trip at
  # the same stop, are contiguous, so they are identified by integer run ids,
  # which are cheaper to compare than ids and are never NA. each run of
  # entries at the same stop is a single visit

  trip_run <- data.table::rleidv(st, "trip_id")
  visit_run <- data.table::rleidv(st, c("trip_id", "stop_id"))
  is_repeat <- c(FALSE, visit_run[-1L] == visit_run[-length(visit_run)])

  if (any(is_repeat)) {
    # a visit made of several entries arrives at the first known time of its
    # entries and departs at the last one, so a blank time in one of its
    # entries doesn't leave it without times. only the rows of these visits
    # are processed, and their times are written to the first entry of each
    # visit, the one that is kept

    is_merged <- logical(visit_run[length(visit_run)])
    is_merged[visit_run[is_repeat]] <- TRUE
    rows <- which(is_merged[visit_run])
    run <- visit_run[rows]

    first_time <- data.table::fcoalesce(
      st$arrival_secs[rows],
      st$departure_secs[rows]
    )
    last_time <- data.table::fcoalesce(
      st$departure_secs[rows],
      st$arrival_secs[rows]
    )

    known <- which(!is.na(first_time))
    first_known <- known[!duplicated(run[known])]
    known <- which(!is.na(last_time))
    last_known <- known[!duplicated(run[known], fromLast = TRUE)]

    first_entry <- rows[!is_repeat[rows]]
    merged_run <- visit_run[first_entry]
    arrival_visit <- match(run[first_known], merged_run)
    departure_visit <- match(run[last_known], merged_run)

    visit_arrival <- rep(NA_integer_, length(first_entry))
    visit_arrival[arrival_visit] <- first_time[first_known]
    visit_departure <- rep(NA_integer_, length(first_entry))
    visit_departure[departure_visit] <- last_time[last_known]

    data.table::set(
      st,
      i = first_entry,
      j = c("arrival_secs", "departure_secs"),
      value = list(visit_arrival, visit_departure)
    )
    st <- st[!is_repeat]
    trip_run <- trip_run[!is_repeat]
  }

  # the service of each visit is its trip's route and direction (or inferred
  # direction), plus the number of the visit to the stop within the trip.
  # trips' fields are looked up by their first match, so duplicated trip_ids
  # in 'trips' can't duplicate rows

  trip_index <- data.table::chmatch(st$trip_id, gtfs$trips$trip_id)
  has_direction <- gtfsio::check_field_exists(gtfs, "trips", "direction_id")
  direction_id <- if (has_direction) {
    gtfs$trips$direction_id[trip_index]
  } else {
    rep(NA_integer_, nrow(st))
  }

  st[
    ,
    `:=`(
      weight = weights$weight[data.table::chmatch(trip_id, weights$trip_id)],
      route_id = gtfs$trips$route_id[trip_index],
      direction_id = direction_id,
      inferred_direction = NA_integer_,
      visit = data.table::rowidv(
        list(trip_run, data.table::chmatch(stop_id, unique(stop_id)))
      )
    )
  ]

  no_direction <- is.na(st$direction_id)
  if (any(no_direction)) {
    st[
      no_direction,
      inferred_direction := infer_trip_directions(trip_id, route_id, stop_id)
    ]
  }

  # the stop nodes come first, sorted by stop_id, followed by the service
  # nodes, sorted by stop and service. stops' fields are looked up by their
  # first match, so duplicated stop_ids in 'stops' can't duplicate nodes

  stops <- data.table::data.table(stop_id = unique(st$stop_id))
  data.table::setorderv(stops, "stop_id")
  stop_index <- data.table::chmatch(stops$stop_id, gtfs$stops$stop_id)
  stop_name <- if (gtfsio::check_field_exists(gtfs, "stops", "stop_name")) {
    gtfs$stops$stop_name[stop_index]
  } else {
    NA_character_
  }
  stops[
    ,
    `:=`(
      stop_lat = gtfs$stops$stop_lat[stop_index],
      stop_lon = gtfs$stops$stop_lon[stop_index],
      stop_name = stop_name
    )
  ]
  n_stops <- nrow(stops)

  service_cols <- c(
    "stop_id",
    "route_id",
    "direction_id",
    "inferred_direction",
    "visit"
  )

  # the dense rank of the service of each visit is the position of the
  # service among the sorted services (NAs first, as setorderv() sorts them),
  # so the services are numbered without grouping the visits

  service_rank <- data.table::frankv(
    st,
    service_cols,
    ties.method = "dense",
    na.last = FALSE
  )
  st[, service_node := n_stops + service_rank]

  first_visit <- which(!duplicated(service_rank))
  first_visit <- first_visit[order(service_rank[first_visit])]
  services <- st[first_visit, service_cols, with = FALSE]
  services[, node_id := n_stops + seq_len(.N)]
  services[, parent_node_id := data.table::chmatch(stop_id, stops$stop_id)]

  node <- data.table::data.table(
    node_id = c(seq_len(n_stops), services$node_id),
    x_coord = c(stops$stop_lon, stops$stop_lon[services$parent_node_id]),
    y_coord = c(stops$stop_lat, stops$stop_lat[services$parent_node_id]),
    node_type = rep(c("stop", "service"), c(n_stops, nrow(services))),
    parent_node_id = c(rep(NA_integer_, n_stops), services$parent_node_id),
    stop_id = c(stops$stop_id, services$stop_id),
    stop_name = c(stops$stop_name, stops$stop_name[services$parent_node_id]),
    route_id = c(rep(NA_character_, n_stops), services$route_id),
    direction_id = c(rep(NA_integer_, n_stops), services$direction_id),
    inferred_direction = c(
      rep(NA_integer_, n_stops),
      services$inferred_direction
    ),
    visit = c(rep(NA_integer_, n_stops), services$visit)
  )

  no_coordinates <- is.na(stops$stop_lat) | is.na(stops$stop_lon)

  if (any(no_coordinates)) {
    abbreviated <- abbreviate_ids(stops$stop_id[no_coordinates])
    cli::cli_warn(
      c(
        paste0(
          "{sum(no_coordinates)} stop{?s} visited by the trips {?is/are} not ",
          "listed in {.file stops} or {?has/have} no coordinates, so ",
          "{?its/their} nodes have {.val NA} coordinates: ",
          "{.val {abbreviated$shown}}{abbreviated$more}."
        ),
        "i" = "These stops have no transfer links."
      ),
      class = "gtfstools_stops_without_coordinates"
    )
  }

  # in-vehicle links connect the service nodes of consecutive visits of each
  # trip, whose rows are contiguous. times that are missing or that decrease
  # (by 12 hours or less, since the others were fixed) are not used

  has_next <- c(trip_run[-1L] == trip_run[-length(trip_run)], FALSE)
  current <- which(has_next)
  following <- current + 1L

  segments <- data.table::data.table(
    from_node_id = st$service_node[current],
    to_node_id = st$service_node[following],
    weight = st$weight[current],
    duration = st$arrival_secs[following] - st$departure_secs[current]
  )

  # untimed segments add 0 to both sums below, so a single grouping with
  # plain sums, which data.table's GForce computes without evaluating j once
  # per group, gives both the departures and the mean travel time

  is_timed <- !is.na(segments$duration) & segments$duration >= 0
  segments[
    ,
    `:=`(
      timed_weight = weight * is_timed,
      weighted_duration = data.table::fifelse(
        is_timed,
        as.numeric(duration) * weight,
        0
      )
    )
  ]

  in_vehicle <- segments[
    ,
    .(
      departures = sum(weight),
      weighted_duration = sum(weighted_duration),
      timed_weight = sum(timed_weight)
    ),
    keyby = c("from_node_id", "to_node_id")
  ]
  in_vehicle[
    ,
    travel_time := data.table::fifelse(
      timed_weight > 0,
      weighted_duration / timed_weight / 60,
      NA_real_
    )
  ]
  in_vehicle[, c("weighted_duration", "timed_weight") := NULL]

  in_vehicle[
    ,
    length := cpp_stop_distances(
      stops$stop_lat,
      stops$stop_lon,
      node$parent_node_id[from_node_id],
      node$parent_node_id[to_node_id]
    )
  ]
  in_vehicle[
    ,
    free_speed := data.table::fifelse(
      travel_time > 0,
      length / 1000 / (travel_time / 60),
      NA_real_
    )
  ]

  in_vehicle[, service_node := from_node_id]

  untimed_links <- sum(is.na(in_vehicle$travel_time))

  if (untimed_links > 0) {
    cli::cli_warn(
      c(
        paste0(
          "{untimed_links} in-vehicle link{?s} {?has/have} no travel time, ",
          "because the trips that run through {?it/them} have blank or ",
          "decreasing times."
        ),
        "i" = paste0(
          "Links without travel time can't be used in weighted shortest ",
          "paths. Blank times can be filled with ",
          "{.fn interpolate_stop_times}."
        )
      ),
      class = "gtfstools_links_without_travel_time"
    )
  }

  # boarding links connect stops to the service nodes from which trips depart
  # (every visit but the last of each trip), and alighting links connect every
  # service node back to its stop

  boarding <- data.table::data.table(
    to_node_id = st$service_node[has_next],
    weight = st$weight[has_next]
  )
  boarding <- boarding[, .(departures = sum(weight)), keyby = to_node_id]
  boarding[
    ,
    `:=`(
      from_node_id = node$parent_node_id[to_node_id],
      length = 0,
      travel_time = (to_secs - from_secs) / 60 / departures / 2,
      service_node = to_node_id
    )
  ]

  alighting <- data.table::data.table(
    from_node_id = services$node_id,
    to_node_id = services$parent_node_id,
    length = 0,
    travel_time = 0,
    service_node = services$node_id
  )

  # transfer links connect nearby stops in both directions

  check_n_pairs <- function(n_pairs) {
    check_stop_pair_count(
      n_pairs,
      max_walk_dist,
      "max_walk_dist",
      "Building transfer links",
      call
    )
  }

  pairs <- find_stop_pairs_within(
    stops$stop_lat,
    stops$stop_lon,
    max_walk_dist,
    check_n_pairs
  )
  data.table::setorderv(pairs, c("from", "to"))

  transfer <- data.table::data.table(
    from_node_id = c(pairs$from, pairs$to),
    to_node_id = c(pairs$to, pairs$from),
    length = c(pairs$distance, pairs$distance)
  )
  transfer[
    ,
    `:=`(
      travel_time = length / 1000 / walk_speed * 60,
      free_speed = walk_speed
    )
  ]

  link <- data.table::rbindlist(
    list(
      in_vehicle = in_vehicle,
      boarding = boarding,
      alighting = alighting,
      transfer = transfer
    ),
    use.names = TRUE,
    fill = TRUE,
    idcol = "link_type"
  )

  # the route of each link is that of its service node, which transfer links
  # don't have

  link[
    ,
    `:=`(
      link_id = seq_len(.N),
      directed = TRUE,
      route_id = node$route_id[service_node],
      direction_id = node$direction_id[service_node],
      inferred_direction = node$inferred_direction[service_node]
    )
  ]
  link[, service_node := NULL]
  data.table::setcolorder(link, names(empty_service_network()$link))

  return(list(node = node, link = link))
}



#' Infer the direction of trips
#'
#' The trips of a route that share a pair of consecutive stops, in the same
#' order, are in the same direction, and so are the trips that share pairs
#' with them. The directions are the connected components of trips linked by
#' shared pairs, found by propagating the smallest trip number through the
#' pairs, and through the labels of labels, until it no longer changes.
#'
#' @param trip_id,route_id,stop_id The `trip_id`, `route_id` and `stop_id` of
#'   the visits of the trips, in which the visits of each trip are contiguous
#'   and in order.
#'
#' @return An integer vector with the inferred direction of the trip of each
#'   visit, numbered from 1 within each route in order of first appearance.
#'
#' @keywords internal
infer_trip_directions <- function(trip_id, route_id, stop_id) {
  trip <- data.table::chmatch(trip_id, unique(trip_id))
  n_visits <- length(trip)
  n_trips <- max(trip)

  has_next <- c(trip[-1L] == trip[-n_visits], FALSE)
  current <- which(has_next)

  pairs <- data.table::data.table(
    route_id = route_id[current],
    from_stop = stop_id[current],
    to_stop = stop_id[current + 1L]
  )
  pair <- data.table::frankv(
    pairs,
    c("route_id", "from_stop", "to_stop"),
    ties.method = "dense",
    na.last = FALSE
  )

  # the minimums below are taken over plain columns, so data.table's GForce
  # computes them without evaluating j once per group

  by_pair <- data.table::data.table(
    pair = pair,
    trip = trip[current],
    label = 0L
  )
  by_trip <- data.table::data.table(
    trip = trip[current],
    pair = pair,
    label = 0L
  )

  label <- seq_len(n_trips)

  # every pass links trips one shared pair further, and labels only decrease.
  # the label of a trip is always a trip of its component, so the smallest
  # label that reaches a trip can also be given to the trip that labels it
  # (hooking), and labels can be replaced by the labels of their labels
  # (pointer jumping). together, they make long chains of trips converge in
  # few passes, whatever the order of their trips. the loop ends once every
  # trip has the smallest label of its component. trips with a single visit
  # have no pairs, and j would be evaluated even on an empty table, hence the
  # nrow() check

  while (nrow(by_pair) > 0) {
    data.table::set(by_pair, j = "label", value = label[by_pair$trip])
    pair_label <- by_pair[, .(label = min(label)), keyby = "pair"]$label
    data.table::set(by_trip, j = "label", value = pair_label[by_trip$pair])
    trip_label <- by_trip[, .(label = min(label)), by = "trip"]

    hooks <- data.table::data.table(
      trip = c(trip_label$trip, label[trip_label$trip]),
      label = rep(trip_label$label, 2L)
    )
    hooks <- hooks[, .(label = min(label)), by = "trip"]

    new_label <- label
    new_label[hooks$trip] <- pmin(label[hooks$trip], hooks$label)

    repeat {
      jumped <- new_label[new_label]
      if (identical(jumped, new_label)) break
      new_label <- jumped
    }

    if (identical(new_label, label)) break
    label <- new_label
  }

  trips <- data.table::data.table(
    route_id = route_id[!duplicated(trip)],
    label = label
  )
  trips[, direction := match(label, unique(label)), by = route_id]

  return(trips$direction[trip])
}



#' Create an empty transit network
#'
#' @return A list with the empty `node` and `link` tables of a network built
#'   by `build_service_network()`.
#'
#' @keywords internal
empty_service_network <- function() {
  node <- data.table::data.table(
    node_id = integer(0),
    x_coord = numeric(0),
    y_coord = numeric(0),
    node_type = character(0),
    parent_node_id = integer(0),
    stop_id = character(0),
    stop_name = character(0),
    route_id = character(0),
    direction_id = integer(0),
    inferred_direction = integer(0),
    visit = integer(0)
  )

  link <- data.table::data.table(
    link_id = integer(0),
    from_node_id = integer(0),
    to_node_id = integer(0),
    directed = logical(0),
    length = numeric(0),
    free_speed = numeric(0),
    link_type = character(0),
    travel_time = numeric(0),
    departures = integer(0),
    route_id = character(0),
    direction_id = integer(0),
    inferred_direction = integer(0)
  )

  return(list(node = node, link = link))
}
