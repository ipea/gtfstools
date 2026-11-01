# creates a feed whose times after midnight are written as early morning
# times: trip W runs from 23:50 to "00:35:00", and the frequency-based trip F
# departs every 30 minutes from 23:00 to "01:00:00". this is a setup file, not
# a helper, for the reason given in setup-read_gtfs.R

overnight_feed <- function() {
  feed <- list(
    trips = data.table::data.table(
      trip_id = c("W", "F"),
      route_id = c("R1", "R2"),
      service_id = "S1"
    ),
    stops = data.table::data.table(
      stop_id = c("A", "B", "C", "D"),
      stop_lat = 0,
      stop_lon = c(0, 0.01, 0.02, 0.03)
    ),
    stop_times = data.table::data.table(
      trip_id = c("W", "W", "W", "W", "F", "F"),
      stop_id = c("A", "B", "C", "D", "A", "B"),
      stop_sequence = c(1:4, 1:2),
      arrival_time = c(
        "23:50:00", "00:05:00", "00:20:00", "00:35:00", "00:00:00", "00:10:00"
      ),
      departure_time = c(
        "23:50:00", "00:05:00", "00:20:00", "00:35:00", "00:00:00", "00:10:00"
      )
    ),
    frequencies = data.table::data.table(
      trip_id = "F",
      start_time = "23:00:00",
      end_time = "01:00:00",
      headway_secs = 1800L
    )
  )

  return(gtfsio::new_gtfs(feed, "dt_gtfs"))
}
