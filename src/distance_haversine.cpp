#include <cmath>

#include <cpp11.hpp>
using namespace cpp11;

// great-circle distance, in meters, between each pair of points (from[i] and
// to[i], in degrees), using the haversine formula. the sphere has the same
// radius used by {s2}, {sf}'s default engine for geographic coordinates, so
// the results match sf::st_distance() on lon/lat data

double distance_haversine(double lat_from, double lon_from,
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
