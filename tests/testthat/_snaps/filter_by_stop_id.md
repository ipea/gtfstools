# full_trips is defunct

    Code
      filter_by_stop_id(spo_gtfs, spo_stops, full_trips = TRUE)
    Condition
      Error in `filter_by_stop_id()`:
      ! The `full_trips` argument of `filter_by_stop_id()` was deprecated in gtfstools 1.3.0 and is now defunct.
      i `filter_by_stop_id()` now always filters by the specified stops, as `full_trips = FALSE` did. Please remove `full_trips` from your call.
      i To keep all stops of the trips that pass through the specified stops (the old `full_trips = TRUE` behavior), subset the `stop_times` table by `stop_id` and pass the resulting `trip_id`s to `filter_by_trip_id()`.

