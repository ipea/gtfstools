filter_agency_from_agency_id <- function(gtfs, relevant_agencies, `%ffilter%`) {
  # since agency_id is optional in many tables when the feed is only composed by
  # one agency, we may have situations in which relevant_agencies is NULL (e.g.
  # when trying to get gtfs$routes$agency_id from a routes table without an
  # agency_id column).
  # so if relevant_agencies is NULL, we keep the gtfs intact. otherwise, we
  # would wrongfully subset agency down to an empty table.

  if (is.null(relevant_agencies)) return(gtfs)

  if (gtfsio::check_field_exists(gtfs, "agency", "agency_id")) {
    gtfsio::assert_field_class(gtfs, "agency", "agency_id", "character")
    gtfs$agency <- gtfs$agency[agency_id %ffilter% relevant_agencies]
  }

  return(gtfs)
}

filter_agency_from_derived_agency_id <- function(gtfs, relevant_agencies) {
  # agency_id may be blank or absent in single-agency feeds, so we keep
  # 'agency' intact in such cases

  if (NROW(gtfs$agency) <= 1L) return(gtfs)

  return(filter_agency_from_agency_id(gtfs, relevant_agencies, `%chin%`))
}

filter_attributions_from_agency_id <- function(gtfs,
                                               relevant_agencies,
                                               `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "attributions", "agency_id")) {
    gtfsio::assert_field_class(gtfs, "attributions", "agency_id", "character")
    gtfs$attributions <- gtfs$attributions[
      agency_id %chin% "" | agency_id %ffilter% relevant_agencies
    ]
  }

  return(gtfs)
}

filter_fare_attr_from_agency_id <- function(gtfs,
                                            relevant_agencies,
                                            `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "fare_attributes", "agency_id")) {
    gtfsio::assert_field_class(
      gtfs,
      "fare_attributes",
      "agency_id",
      "character"
    )
    gtfs$fare_attributes <- gtfs$fare_attributes[
      agency_id %ffilter% relevant_agencies
    ]
  }

  return(gtfs)
}

filter_fare_attr_from_fare_id <- function(gtfs, relevant_fares, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "fare_attributes", "fare_id")) {
    gtfsio::assert_field_class(gtfs, "fare_attributes", "fare_id", "character")
    gtfs$fare_attributes <- gtfs$fare_attributes[
      fare_id %ffilter% relevant_fares
    ]
  }

  return(gtfs)
}

filter_routes_from_agency_id <- function(gtfs, relevant_agencies, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "routes", "agency_id")) {
    gtfsio::assert_field_class(gtfs, "routes", "agency_id", "character")
    gtfs$routes <- gtfs$routes[agency_id %ffilter% relevant_agencies]
  }

  return(gtfs)
}

filter_fare_rules_from_route_id <- function(gtfs,
                                            relevant_routes,
                                            `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "fare_rules", "route_id")) {
    gtfsio::assert_field_class(gtfs, "fare_rules", "route_id", "character")
    gtfs$fare_rules <- gtfs$fare_rules[
      route_id %chin% "" | route_id %ffilter% relevant_routes
    ]
  }

  return(gtfs)
}

filter_fare_rules_from_zone_id <- function(gtfs, relevant_zones, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "fare_rules", "origin_id")) {
    gtfsio::assert_field_class(gtfs, "fare_rules", "origin_id", "character")
    gtfs$fare_rules <- gtfs$fare_rules[
      origin_id %chin% "" | origin_id %ffilter% relevant_zones
    ]
  }

  if (gtfsio::check_field_exists(gtfs, "fare_rules", "destination_id")) {
    gtfsio::assert_field_class(
      gtfs,
      "fare_rules",
      "destination_id",
      "character"
    )
    gtfs$fare_rules <- gtfs$fare_rules[
      destination_id %chin% "" | destination_id %ffilter% relevant_zones
    ]
  }

  # the spec mentions that if the same fare_id is associated to many zones in
  # contains_id, all contains_ids must be matched for the fare to apply.
  # using their example: (https://gtfs.org/schedule/reference/#fare_rulestxt)
  #
  # fare_id,route_id,...,contains_id
  # c,GRT,...,5
  # c,GRT,...,6
  # c,GRT,...,7
  #
  # an itinerary that passes through zones 5 and 6 but not zone 7 would not have
  # fare class "c".
  #
  # in this case, when filtering fare_rules by contains_id we have to check if
  # all referred contains_ids exist in stops (or if all ids are not in stops,
  # when dropping ids), otherwise we can drop the fare class entirely

  if (gtfsio::check_field_exists(gtfs, "fare_rules", "contains_id")) {
    gtfsio::assert_field_class(gtfs, "fare_rules", "contains_id", "character")

    .all_but_contains <- setdiff(names(gtfs$fare_rules), "contains_id")

    gtfs$fare_rules[
      ,
      .flagged := ifelse(
        contains_id %chin% "" | contains_id %ffilter% relevant_zones,
        TRUE,
        FALSE
      )
    ]

    gtfs$fare_rules <- gtfs$fare_rules[
      gtfs$fare_rules[, .I[all(.flagged)], by = .all_but_contains]$V1
    ]

    gtfs$fare_rules[, .flagged := NULL][]
  }

  return(gtfs)
}

filter_trips_from_route_id <- function(gtfs, relevant_routes, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "trips", "route_id")) {
    gtfsio::assert_field_class(gtfs, "trips", "route_id", "character")
    gtfs$trips <- gtfs$trips[route_id %ffilter% relevant_routes]
  }

  return(gtfs)
}

filter_trips_from_shape_id <- function(gtfs, relevant_shapes, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "trips", "shape_id")) {
    gtfsio::assert_field_class(gtfs, "trips", "shape_id", "character")
    gtfs$trips <- gtfs$trips[shape_id %ffilter% relevant_shapes]
  } else if (gtfsio::check_file_exists(gtfs, "trips")) {
    warning(
      "'trips' table missing 'shape_id' column, therefore kept intact during ",
      "the filtering process.",
      call. = FALSE
    )
  }

  return(gtfs)
}

filter_trips_from_service_id <- function(gtfs, relevant_services, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "trips", "service_id")) {
    gtfsio::assert_field_class(gtfs, "trips", "service_id", "character")
    gtfs$trips <- gtfs$trips[service_id %ffilter% relevant_services]
  }

  return(gtfs)
}

filter_shapes_from_shape_id <- function(gtfs, relevant_shapes, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "shapes", "shape_id")) {
    gtfsio::assert_field_class(gtfs, "shapes", "shape_id", "character")
    gtfs$shapes <- gtfs$shapes[shape_id %ffilter% relevant_shapes]
  }

  return(gtfs)
}

filter_calendar_from_service_id <- function(gtfs,
                                            relevant_services,
                                            `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "calendar", "service_id")) {
    gtfsio::assert_field_class(gtfs, "calendar", "service_id", "character")
    gtfs$calendar <- gtfs$calendar[service_id %ffilter% relevant_services]
  }

  return(gtfs)
}

filter_calend_dates_from_service_id <- function(gtfs,
                                                relevant_services,
                                                `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "calendar_dates", "service_id")) {
    gtfsio::assert_field_class(
      gtfs,
      "calendar_dates",
      "service_id",
      "character"
    )
    gtfs$calendar_dates <- gtfs$calendar_dates[
      service_id %ffilter% relevant_services
    ]
  }

  return(gtfs)
}

filter_frequencies_from_trip_id <- function(gtfs, relevant_trips, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "frequencies", "trip_id")) {
    gtfsio::assert_field_class(gtfs, "frequencies", "trip_id", "character")
    gtfs$frequencies <- gtfs$frequencies[trip_id %ffilter% relevant_trips]
  }

  return(gtfs)
}

filter_stop_times_from_trip_id <- function(gtfs, relevant_trips, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "stop_times", "trip_id")) {
    gtfsio::assert_field_class(gtfs, "stop_times", "trip_id", "character")
    gtfs$stop_times <- gtfs$stop_times[trip_id %ffilter% relevant_trips]
  }

  return(gtfs)
}

filter_stop_times_from_stop_id <- function(gtfs, relevant_stops, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "stop_times", "stop_id")) {
    gtfsio::assert_field_class(gtfs, "stop_times", "stop_id", "character")
    gtfs$stop_times <- gtfs$stop_times[stop_id %ffilter% relevant_stops]
  }

  return(gtfs)
}

filter_transfers_from_stop_id <- function(gtfs, relevant_stops, `%ffilter%`) {
  from_to_stop_id <- c("from_stop_id", "to_stop_id")

  if (gtfsio::check_field_exists(gtfs, "transfers", from_to_stop_id)) {
    gtfsio::assert_field_class(
      gtfs,
      "transfers",
      from_to_stop_id,
      rep("character", 2)
    )
    gtfs$transfers <- gtfs$transfers[
      from_stop_id %chin% "" | from_stop_id %ffilter% relevant_stops
    ]
    gtfs$transfers <- gtfs$transfers[
      to_stop_id %chin% "" | to_stop_id %ffilter% relevant_stops
    ]
  }

  return(gtfs)
}

filter_transfers_from_route_id <- function(gtfs, relevant_routes, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "transfers", "from_route_id")) {
    gtfsio::assert_field_class(gtfs, "transfers", "from_route_id", "character")
    gtfs$transfers <- gtfs$transfers[
      from_route_id %chin% "" | from_route_id %ffilter% relevant_routes
    ]
  }

  if (gtfsio::check_field_exists(gtfs, "transfers", "to_route_id")) {
    gtfsio::assert_field_class(gtfs, "transfers", "to_route_id", "character")
    gtfs$transfers <- gtfs$transfers[
      to_route_id %chin% "" | to_route_id %ffilter% relevant_routes
    ]
  }

  return(gtfs)
}

filter_transfers_from_trip_id <- function(gtfs, relevant_trips, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "transfers", "from_trip_id")) {
    gtfsio::assert_field_class(gtfs, "transfers", "from_trip_id", "character")
    gtfs$transfers <- gtfs$transfers[
      from_trip_id %chin% "" | from_trip_id %ffilter% relevant_trips
    ]
  }

  if (gtfsio::check_field_exists(gtfs, "transfers", "to_trip_id")) {
    gtfsio::assert_field_class(gtfs, "transfers", "to_trip_id", "character")
    gtfs$transfers <- gtfs$transfers[
      to_trip_id %chin% "" | to_trip_id %ffilter% relevant_trips
    ]
  }

  return(gtfs)
}

filter_stops_from_stop_id <- function(gtfs, relevant_stops, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "stops", "stop_id")) {
    gtfsio::assert_field_class(gtfs, "stops", "stop_id", "character")
    gtfs$stops <- gtfs$stops[stop_id %ffilter% relevant_stops]
  }

  return(gtfs)
}

filter_pathways_from_stop_id <- function(gtfs, relevant_stops, `%ffilter%`) {
  from_to_stop_id <- c("from_stop_id", "to_stop_id")

  if (gtfsio::check_field_exists(gtfs, "pathways", from_to_stop_id)) {
    gtfsio::assert_field_class(
      gtfs,
      "pathways",
      from_to_stop_id,
      rep("character", 2)
    )
    gtfs$pathways <- gtfs$pathways[from_stop_id %ffilter% relevant_stops]
    gtfs$pathways <- gtfs$pathways[to_stop_id %ffilter% relevant_stops]
  }

  return(gtfs)
}

filter_levels_from_level_id <- function(gtfs, relevant_levels, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "levels", "level_id")) {
    gtfsio::assert_field_class(gtfs, "levels", "level_id", "character")
    gtfs$levels <- gtfs$levels[level_id %ffilter% relevant_levels]
  }

  return(gtfs)
}

filter_trips_from_trip_id <- function(gtfs, relevant_trips, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "trips", "trip_id")) {
    gtfsio::assert_field_class(gtfs, "trips", "trip_id", "character")
    gtfs$trips <- gtfs$trips[trip_id %ffilter% relevant_trips]
  }

  return(gtfs)
}

filter_routes_from_route_id <- function(gtfs, relevant_routes, `%ffilter%`) {
  if (gtfsio::check_field_exists(gtfs, "routes", "route_id")) {
    gtfsio::assert_field_class(gtfs, "routes", "route_id", "character")
    gtfs$routes <- gtfs$routes[route_id %ffilter% relevant_routes]
  }

  return(gtfs)
}




get_stops_and_parents <- function(gtfs) {
  relevant_stops <- unique(gtfs$stop_times$stop_id)

  # get_parent_station() raises a warning if a stop is present in 'stop_times'
  # but not in 'stops', but we don't need to worry about it

  if (gtfsio::check_field_exists(gtfs, "stops", "parent_station")) {
    suppressWarnings(
      stops_with_parents <- get_parent_station(gtfs, relevant_stops)
    )
    relevant_stops <- stops_with_parents$stop_id
  }

  return(relevant_stops)
}
