#include <algorithm>
#include <climits>
#include <cmath>
#include <utility>
#include <vector>

#include <cpp11.hpp>
using namespace cpp11;

// great-circle distance, in meters, between each pair of points (from[i] and
// to[i], in degrees), using the haversine formula. the sphere has the same
// radius used by {s2}, {sf}'s default engine for geographic coordinates, so
// the results match sf::st_distance() on lon/lat data

static double distance_haversine(double lat_from, double lon_from,
                                 double lat_to, double lon_to) {
  const double earth_radius = 6371010.0; // = s2::s2_earth_radius_meters()
  const double to_radians = 3.14159265358979323846 / 180.0;

  lat_from *= to_radians;
  lon_from *= to_radians;
  lat_to *= to_radians;
  lon_to *= to_radians;

  const double sin_dlat = std::sin((lat_to - lat_from) / 2.0);
  const double sin_dlon = std::sin((lon_to - lon_from) / 2.0);
  double a = sin_dlat * sin_dlat +
    std::cos(lat_from) * std::cos(lat_to) * sin_dlon * sin_dlon;

  // rounding may push 'a' slightly outside [0, 1]

  if (a < 0.0) a = 0.0;
  if (a > 1.0) a = 1.0;

  return 2.0 * earth_radius * std::atan2(std::sqrt(a), std::sqrt(1.0 - a));
}

//' rcpp_distance_haversine
//'
//' Vectorize the above function. Returns NA where any coordinate is NA.
//'
//' @noRd
[[cpp11::register]]
doubles rcpp_distance_haversine(const doubles lat_from,
                                const doubles lon_from,
                                const doubles lat_to,
                                const doubles lon_to) {
  const R_xlen_t n = lat_from.size();
  if (lon_from.size() != n || lat_to.size() != n || lon_to.size() != n) {
    stop("All coordinate vectors must have the same length.");
  }

  writable::doubles distance(n);

  for (R_xlen_t i = 0; i < n; i++) {
    if (ISNAN(lat_from[i]) || ISNAN(lon_from[i]) ||
        ISNAN(lat_to[i]) || ISNAN(lon_to[i])) {
      distance[i] = NA_REAL;
    } else {
      distance[i] = distance_haversine(
        lat_from[i], lon_from[i], lat_to[i], lon_to[i]
      );
    }
  }

  return distance;
}

// wraps a longitude to the interval [reference - 180, reference + 180), so
// that shapes and stops crossing the antimeridian are handled correctly

static double unwrap_longitude(double lon, double reference) {
  double diff = lon - reference;
  diff -= 360.0 * std::floor((diff + 180.0) / 360.0);
  return reference + diff;
}

//' rcpp_locate_stops_on_shape
//'
//' Locates a sequence of stops along a shape, returning the distance, in
//' meters, from the start of the shape to the point of the shape where each
//' stop is projected. Each stop is projected onto the line segments of the
//' shape (not only onto its vertices), and the stops are forced to advance
//' along the shape in the order they are given, so that loops and shapes that
//' pass by the same place more than once are handled correctly.
//'
//' The stops are placed, with dynamic programming, so as to (approximately)
//' minimize the sum of the squared distances between the stops and their
//' points on the shape, under the ordering constraint. A stop located before
//' the previous one on the same segment is placed at the previous stop's
//' position (the previous stop is never moved back to make room for it).
//' Squared distances are calculated in a local
//' equirectangular frame of each shape segment, while the lengths along the
//' shape are great-circle distances calculated with the haversine formula.
//'
//' All coordinates must be non-missing, and the shape must have at least two
//' points.
//'
//' @noRd
[[cpp11::register]]
doubles rcpp_locate_stops_on_shape(const doubles shape_lat,
                                   const doubles shape_lon,
                                   const doubles stop_lat,
                                   const doubles stop_lon) {
  const R_xlen_t n_points = shape_lat.size();
  const R_xlen_t n_stops = stop_lat.size();
  if (shape_lon.size() != n_points || stop_lon.size() != n_stops) {
    stop("Latitude and longitude vectors must have the same length.");
  }
  if (n_points < 2) stop("The shape must have at least two points.");
  if (n_stops == 0) return writable::doubles((R_xlen_t) 0);

  for (R_xlen_t k = 0; k < n_points; k++) {
    if (ISNAN(shape_lat[k]) || ISNAN(shape_lon[k])) {
      stop("Shape coordinates must not be missing.");
    }
  }
  for (R_xlen_t i = 0; i < n_stops; i++) {
    if (ISNAN(stop_lat[i]) || ISNAN(stop_lon[i])) {
      stop("Stop coordinates must not be missing.");
    }
  }

  const R_xlen_t n_segments = n_points - 1;
  const double earth_radius = 6371010.0;
  const double to_radians = 3.14159265358979323846 / 180.0;
  const double meters_per_degree = earth_radius * to_radians;

  // shape preparation: unwrapped longitudes, segment lengths, cumulative
  // distances and the east-west scale of each segment

  std::vector<double> lon(n_points);
  for (R_xlen_t k = 0; k < n_points; k++) {
    lon[k] = unwrap_longitude(shape_lon[k], shape_lon[0]);
  }

  std::vector<double> seg_length(n_segments);
  std::vector<double> cum_dist(n_segments);
  std::vector<double> x_scale(n_segments);
  double total = 0.0;

  for (R_xlen_t j = 0; j < n_segments; j++) {
    seg_length[j] = distance_haversine(
      shape_lat[j], shape_lon[j], shape_lat[j + 1], shape_lon[j + 1]
    );
    cum_dist[j] = total;
    total += seg_length[j];

    const double mid_lat = (shape_lat[j] + shape_lat[j + 1]) / 2.0;
    x_scale[j] = meters_per_degree * std::cos(mid_lat * to_radians);
  }

  std::vector<double> stop_x(n_stops);
  for (R_xlen_t i = 0; i < n_stops; i++) {
    stop_x[i] = unwrap_longitude(stop_lon[i], shape_lon[0]);
  }

  // squared distance between stop i and the point at relative position 't' of
  // segment j. when 'project' is true, 't' is set to the position of the
  // stop's projection onto the segment (0 = start, 1 = end)

  auto squared_distance = [&](R_xlen_t i, R_xlen_t j, double& t, bool project) {
    const double bx = (lon[j + 1] - lon[j]) * x_scale[j];
    const double by = (shape_lat[j + 1] - shape_lat[j]) * meters_per_degree;
    const double px = (stop_x[i] - lon[j]) * x_scale[j];
    const double py = (stop_lat[i] - shape_lat[j]) * meters_per_degree;

    if (project) {
      const double length_sq = bx * bx + by * by;
      t = 0.0;
      if (length_sq > 0.0) {
        t = (px * bx + py * by) / length_sq;
        if (t < 0.0) t = 0.0;
        if (t > 1.0) t = 1.0;
      }
    }

    const double dx = px - t * bx;
    const double dy = py - t * by;
    return dx * dx + dy * dy;
  };

  auto project = [&](R_xlen_t i, R_xlen_t j, double& t) {
    return squared_distance(i, j, t, true);
  };

  // dynamic programming: prev[j] holds the minimum total cost of placing the
  // stops up to the previous one, with the previous one on segment j, at the
  // relative position prev_t[j]. the current stop may follow a stop placed on
  // an earlier segment, or a stop placed on the same segment. in the latter
  // case, if the stop is projected before the previous stop, it is placed at
  // the previous stop's position and the cost is the distance to that point,
  // so stops slightly out of order are handled in the same way on every
  // segment. ties keep the earliest segment. costs that differ by less than
  // 'tie_tolerance' (squared meters) are considered ties, otherwise rounding
  // errors would decide between overlapping parts of a shape (e.g. the two
  // directions of an out-and-back shape)

  const double tie_tolerance = 1e-6;
  std::vector<double> prev(n_segments);
  std::vector<double> cur(n_segments);
  std::vector<double> prev_t(n_segments);
  std::vector<double> cur_t(n_segments);
  std::vector<int> back((size_t) n_stops * (size_t) n_segments);
  double t;

  for (R_xlen_t j = 0; j < n_segments; j++) {
    prev[j] = project(0, j, t);
    prev_t[j] = t;
  }

  for (R_xlen_t i = 1; i < n_stops; i++) {
    check_user_interrupt();

    // minimum cost (and its segment) among the segments before segment j
    double earlier_min = 0.0;
    int earlier_arg = -1;

    for (R_xlen_t j = 0; j < n_segments; j++) {
      double t_free;
      const double cost_free = project(i, j, t_free);

      // staying on the same segment as the previous stop: the stop can't be
      // placed before it
      double t_stay = t_free;
      double cost_stay = cost_free;
      if (t_free < prev_t[j]) {
        t_stay = prev_t[j];
        cost_stay = squared_distance(i, j, t_stay, false);
      }

      double total = prev[j] + cost_stay;
      double total_t = t_stay;
      int best_arg = (int) j;

      if (earlier_arg >= 0 &&
          earlier_min + cost_free <= total + tie_tolerance) {
        total = earlier_min + cost_free;
        total_t = t_free;
        best_arg = earlier_arg;
      }

      cur[j] = total;
      cur_t[j] = total_t;
      back[(size_t) i * (size_t) n_segments + (size_t) j] = best_arg;

      if (earlier_arg < 0 || prev[j] < earlier_min - tie_tolerance) {
        earlier_min = prev[j];
        earlier_arg = (int) j;
      }
    }

    std::swap(prev, cur);
    std::swap(prev_t, cur_t);
  }

  R_xlen_t best_segment = 0;
  for (R_xlen_t j = 1; j < n_segments; j++) {
    if (prev[j] < prev[best_segment] - tie_tolerance) best_segment = j;
  }

  // traceback, from the last stop to the first one

  std::vector<R_xlen_t> segment(n_stops);
  segment[n_stops - 1] = best_segment;
  for (R_xlen_t i = n_stops - 1; i > 0; i--) {
    segment[i - 1] = back[(size_t) i * (size_t) n_segments + (size_t) segment[i]];
  }

  // positions along the shape. a stop projected onto the same segment as the
  // previous stop, but before it, is moved to the previous stop's position, so
  // distances between consecutive stops are never negative

  writable::doubles position(n_stops);
  double previous_pos = 0.0;

  for (R_xlen_t i = 0; i < n_stops; i++) {
    const R_xlen_t j = segment[i];
    project(i, j, t);
    double pos = cum_dist[j] + t * seg_length[j];
    if (i > 0 && pos < previous_pos) pos = previous_pos;
    position[i] = pos;
    previous_pos = pos;
  }

  return position;
}

//' cpp_shape_cut_segments
//'
//' Finds where parts of shapes start and end. 'lat' and 'lon' hold the points
//' of each shape, contiguous and in the order of 'shape_size'. Each part is on
//' the shape given by 'cut_shape' (1-based) and goes from 'from' to 'to',
//' meters from the start of the shape.
//'
//' Returns the cumulative distance of each point ('cum') and, for each part,
//' the segments that contain 'from' and 'to' and the range of points strictly
//' between them ('first_inner' to 'last_inner'), as 1-based indices into
//' 'lat', 'lon' and 'cum'. These are the results of findInterval() on each
//' shape's cumulative distances.
//'
//' @noRd
[[cpp11::register]]
list cpp_shape_cut_segments(const doubles lat,
                            const doubles lon,
                            const integers shape_size,
                            const integers cut_shape,
                            const doubles from,
                            const doubles to) {
  const R_xlen_t n_points = lat.size();
  const R_xlen_t n_shapes = shape_size.size();
  const R_xlen_t n_cuts = cut_shape.size();

  if (lon.size() != n_points) {
    stop("Latitude and longitude vectors must have the same length.");
  }
  if (from.size() != n_cuts || to.size() != n_cuts) {
    stop("'cut_shape', 'from' and 'to' must have the same length.");
  }

  std::vector<R_xlen_t> shape_start(n_shapes);
  R_xlen_t total = 0;
  for (R_xlen_t s = 0; s < n_shapes; s++) {
    if (shape_size[s] < 0) {
      stop("'shape_size' must not include negative or NA values.");
    }
    shape_start[s] = total;
    total += shape_size[s];
  }
  if (total != n_points) {
    stop("'shape_size' must sum to the number of points.");
  }
  if (total >= INT_MAX) stop("Too many shape points.");

  // cumulative distance of the points of each shape. the sum is kept in long
  // double and each value is stored as a double, as R's cumsum() does (unless
  // R is built with --disable-long-double), so the distances are the same as
  // those calculated in R. any difference would be at rounding level, which
  // build_shape_cuts() absorbs by clamping the interpolation factors

  writable::doubles cum(n_points);

  for (R_xlen_t s = 0; s < n_shapes; s++) {
    const R_xlen_t start = shape_start[s];
    const R_xlen_t end = start + shape_size[s];
    long double sum = 0.0L;

    for (R_xlen_t k = start; k < end; k++) {
      if (k > start) {
        sum += distance_haversine(lat[k - 1], lon[k - 1], lat[k], lon[k]);
      }
      const double value = static_cast<double>(sum);
      if (!std::isfinite(value)) {
        stop("Shape distances must be finite.");
      }
      cum[k] = value;
    }
  }

  // for each part: the number of points of its shape whose cumulative distance
  // is <= from (as findInterval()), <= to, and < to (findInterval() with
  // left.open = TRUE). segments are clamped to the segments of the shape

  writable::integers from_segment(n_cuts);
  writable::integers to_segment(n_cuts);
  writable::integers first_inner(n_cuts);
  writable::integers last_inner(n_cuts);

  const double* cum_begin = REAL(cum);

  for (R_xlen_t i = 0; i < n_cuts; i++) {
    if (cut_shape[i] == NA_INTEGER || cut_shape[i] < 1 ||
        cut_shape[i] > n_shapes) {
      stop("'cut_shape' must be valid shape indices.");
    }
    const R_xlen_t s = cut_shape[i] - 1;

    const R_xlen_t offset = shape_start[s];
    const R_xlen_t n = shape_size[s];
    const double* first = cum_begin + offset;
    const double* last = first + n;

    const double from_i = from[i];
    const double to_i = to[i];
    if (ISNAN(from_i) || ISNAN(to_i)) {
      stop("'from' and 'to' must not be missing.");
    }
    const R_xlen_t n_up_to_from = std::upper_bound(first, last, from_i) - first;
    const R_xlen_t n_up_to_to = std::upper_bound(first, last, to_i) - first;
    const R_xlen_t n_below_to = std::lower_bound(first, last, to_i) - first;
    const R_xlen_t last_segment = n - 1;

    from_segment[i] = static_cast<int>(
      offset + std::min(std::max(n_up_to_from, (R_xlen_t) 1), last_segment)
    );
    to_segment[i] = static_cast<int>(
      offset + std::min(std::max(n_up_to_to, (R_xlen_t) 1), last_segment)
    );
    first_inner[i] = static_cast<int>(offset + n_up_to_from + 1);
    last_inner[i] = static_cast<int>(offset + n_below_to);
  }

  using namespace cpp11::literals;

  return writable::list({
    "cum"_nm = cum,
    "from_segment"_nm = from_segment,
    "to_segment"_nm = to_segment,
    "first_inner"_nm = first_inner,
    "last_inner"_nm = last_inner
  });
}
