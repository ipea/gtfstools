# Crop a GTFS object to a spatial extent

Crops a GTFS object to a spatial extent (an `sf`, `sfc` or `bbox`
object), keeping only the stops inside it (and their parent stations)
and the parts of the trips that serve them. Unlike
[`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md),
which keeps or drops entire trips, `crop_gtfs()` cuts the trips that
leave the spatial extent, keeping only their stops inside it, and, by
default, trims their shapes accordingly.

## Usage

``` r
crop_gtfs(gtfs, geom, trim_shapes = TRUE)
```

## Arguments

- gtfs:

  A GTFS object, as created by
  [`read_gtfs()`](https://ipea.github.io/gtfstools/dev/reference/read_gtfs.md).

- geom:

  An `sf`, `sfc` or `bbox` object, in WGS 84 (EPSG 4326). Describes the
  spatial extent used to crop the data. Stops on its boundary are
  considered inside it. A `bbox` is compared directly with the stops'
  coordinates, while `sf` and `sfc` objects are tested with
  [`sf::st_intersects()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html),
  whose edges are geodesics when spherical geometry is used (the default
  in `{sf}`), so stops very close to their edges may be considered
  outside. Bounding boxes crossing the antimeridian are not supported.

- trim_shapes:

  A logical. Whether the shapes of the trips that leave the spatial
  extent should be trimmed to the part between their first and last
  stops inside it (defaults to `TRUE`). If `FALSE`, these trips keep
  their entire shapes.

## Value

The GTFS object passed to the `gtfs` parameter, after the cropping
process.

## Details

The `stop_times` entries at stops outside the spatial extent are
dropped. Trips left with fewer than two `stop_times` entries are
dropped, as are the entries related to them in other tables, as in
[`filter_by_trip_id()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_trip_id.md).
A trip that leaves the spatial extent and enters it again keeps the
stops inside it, with gaps in their `stop_sequence`. The resulting
`stops` table includes the stops inside the spatial extent served by the
remaining trips, the entrances, generic nodes and boarding areas inside
it related to these stops, and their parent stations, even if these lie
outside the spatial extent. Stops without coordinates are considered
outside of it, so generic nodes and boarding areas without coordinates,
and the pathways that link to them, are dropped.

GTFS requires times at the first and last stops of each trip. If the new
first or last stop of a cropped trip has blank times, the blank times of
the trip are interpolated with
[`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md)
(along its shape, or along straight lines between stops if the trip is
not linked to a shape), before the trip is cropped. Intermediate blank
times of these trips are thus filled too. Times that can't be
interpolated (see
[`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md))
are left blank, with a warning. If a cropped trip is listed in
`frequencies`, the `start_time` and `end_time` of its entries are
shifted by the time between the departure (or the arrival, if the
departure is blank) at its original first stop and at its new one, since
they refer to the first stop of the trip. Entries whose shift can't be
calculated (e.g. because of blank times) or is negative are kept
unchanged.

With `trim_shapes = TRUE`, the stops of each cropped trip are located
along its shape, as in
[`get_trip_length()`](https://ipea.github.io/gtfstools/dev/reference/get_trip_length.md),
and its shape is cut from its first to its last remaining stop, keeping
the parts of the shape outside the spatial extent between them. A shape
cut in only one way keeps its `shape_id`. If a shape is cut in different
ways, or is also used by trips that are not cut, each cut gets a new
`shape_id` (`"<shape_id>_1"`, `"<shape_id>_2"`, etc., different from any
`shape_id` already in use). The `shape_dist_traveled` of the new shape
points and of the `stop_times` entries of the trips linked to them is
set to `NA`, because the distance unit used by the feed is unknown.
Trips not linked to a usable shape keep their shape unchanged.

## See also

[`filter_by_spatial_extent()`](https://ipea.github.io/gtfstools/dev/reference/filter_by_spatial_extent.md),
[`interpolate_stop_times()`](https://ipea.github.io/gtfstools/dev/reference/interpolate_stop_times.md)

## Examples

``` r
data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
gtfs <- read_gtfs(data_path)

bbox <- sf::st_bbox(
  c(xmin = -46.66, ymin = -23.57, xmax = -46.62, ymax = -23.53),
  crs = 4326
)
object.size(gtfs)
#> 811304 bytes

# keeps only the stops inside the bounding box and trims the shapes
cropped_gtfs <- crop_gtfs(gtfs, bbox)
object.size(cropped_gtfs)
#> 171072 bytes

# keeps the entire shapes of the cropped trips
cropped_gtfs <- crop_gtfs(gtfs, bbox, trim_shapes = FALSE)
object.size(cropped_gtfs)
#> 366088 bytes
```
