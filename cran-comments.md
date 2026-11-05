**This is a resubmission to fix bugs**

## R CMD check results

── R CMD check results ─────────────────────────────────────────────────────────── gtfstools 2.0.1 ────
Duration: 7m 25.4s

0 errors ✔ | 0 warnings ✔ | 0 notes ✔


## Bug fixes

- gtfstools functions now accept `dt_gtfs` objects whose tables were turned into tibbles, grouped data frames or plain data frames by other packages (e.g. after `dplyr::group_by()`). With `by_reference = TRUE`, an object with any such table now raises an informative error, since the edits can't be made by reference on a converted copy: convert it first with `as_dt_gtfs()` (#130, reported by @baarthur, who also opened PR #132).
- Several functions that involved estimating trip speed and duration would
drop trips that cross midnight if GTFS input had times in 00:MM:SS, which
disrespects the GTFS standard to report times as 24:MM:SS in such cases. 
This bug has been fixed.  Now all functions that calculate or change durations
and speeds now fix these times using a new function `fix_overnight_times()`
and return correct estimates for overnight trips.
- `filter_by_weekday()` now warns when the GTFS object has no `calendar` table, instead of silently returning it unchanged. Its documentation now states that services defined only in `calendar_dates` are never related to a weekday (use `filter_by_date()` to consider them).
- `validate_gtfs()` now raises an error when `n_threads` is not a whole number, as documented, instead of passing it to the validator.


## Notes

- Change in package maintainer from Daniel to Rafael
- the URL <https://www.sptrans.com.br/desenvolvedores/> works fine on the browser.

## Test environments

- Local Windows 11 installation (R 4.4.2)
- GitHub Actions:
  - Windows (release)
  - MacOS (release)
  - Ubuntu 22.04 (devel, release, oldrel)
- win-builder (devel, release, oldrel)
- rhub:
  - linux (devel)
  - macos (devel)
  - macos-arm64 (devel)
  - windows (devel)
  - rchk (devel)


## Reverse dependencies

We checked 5 reverse dependencies (gtfs2emis, gtfs2gps, GTFShift, GTFSwizard and r5r), comparing R CMD check results across CRAN and dev versions of this
package.

 * We saw 0 new problems
 * We failed to check 0 packages

