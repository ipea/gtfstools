---
paths:
  - "R/**/*.R"
  - "src/**"
  - "tests/**/*.R"
  - "man/**"
  - "vignettes/**"
  - "README.Rmd"
  - "DESCRIPTION"
  - "NAMESPACE"
  - "NEWS.md"
  - "_pkgdown.yml"
---

# gtfstools package conventions

**Standard:** a CRAN-ready, fast, predictable package. `R CMD check --as-cran`
returns 0 errors, 0 warnings, and only explained notes. New code reads like the
code around it.

Part A describes how gtfstools is written today (verified against the source).
Items tagged **[NEW]** are decisions for new or modified code only; never apply
them to untouched code as drive-bys. Part B is the general CRAN standard. When
they conflict, Part A wins; flag the conflict in the plan.

---

# Part A: gtfstools house style

## A1. Namespacing

- **Always call `package::function()`**, including `data.table::`,
  `checkmate::`, `gtfsio::`, `sf::`, `sfheaders::`, `cli::`, `utils::`.
- **Exceptions:**
  - data.table special symbols and operators: `:=`, `.N`, `.SD`, `.I`, `.GRP`,
    `%chin%`. These, plus `utils globalVariables`, are the only `@importFrom`
    imports (in `R/gtfstools.R`).
  - ggplot2 functions in vignettes and README, after `library(ggplot2)`.
- Never use `library()`/`require()` in `R/`. Suggested packages are guarded
  with `requireNamespace("pkg", quietly = TRUE)`.
- Column names used with non-standard evaluation go into the
  `utils::globalVariables(c(...))` block in `R/gtfstools.R`. Append new names
  at the end and check for duplicates first (the block already has some).

## A2. Function skeleton

```r
#' @template gtfs
#' ...
#' @export
filter_by_something <- function(gtfs, something, keep = TRUE) {
  gtfs <- assert_and_assign_gtfs_object(gtfs)        # R/utils.R
  checkmate::assert_character(something, any.missing = FALSE)
  checkmate::assert_logical(keep, len = 1, any.missing = FALSE)

  # ... body ...

  return(gtfs)
}
```

- **Inputs:** validate with `checkmate::assert_*`. Enumerated options use
  `assert_names(x, subset.of = ...)`: after `checkmate::assert_string(x)` for a
  single value (`filter_by_weekday(combine)`), or after
  `checkmate::assert_character(x)` for several (`convert_time_to_seconds(file)`).
  Don't switch these to `assert_choice()`, which accepts only one value and
  would break multi-value arguments. Check that GTFS files and fields exist with
  the `gtfsio::check_*`/`assert_*` helpers.
- **Output class:** functions returning a feed return
  `c("dt_gtfs", "gtfs", "list")`. Build new feeds with
  `gtfsio::new_gtfs(x, "dt_gtfs")`.
- **Optional files and fields** (`calendar_dates`, `frequencies`, `shapes`,
  `parent_station`, …) may be missing, and functions must behave correctly
  when they are. The established pattern (`R/filter_helpers.R`):
  - **Optional file or field absent:** skip that step silently
    (`if (gtfsio::check_field_exists(gtfs, file, field)) { ... }`, no else).
    Don't warn; ordinary feeds lack many optional files.
  - **Table present but missing the field needed to process it**, so its rows
    can't be matched: warn and keep the table intact, e.g. `"'trips' table
    missing 'shape_id' column, therefore kept intact during the filtering
    process."` New code emits that warning with `cli::cli_warn()` (A4).

## A3. data.table discipline

- **Never modify the caller's objects.** A `dt_gtfs` is a list of references:
  `assert_and_assign_gtfs_object()` does not copy an object that is already a
  `dt_gtfs`, so `:=`/`set*()` on `gtfs$<table>` modifies the user's data.
  Before any in-place update, either `data.table::copy()` the table, or expose
  an explicit `by_reference = FALSE` argument (see
  `convert_time_to_seconds()`).
- **Legacy exceptions, not models:** `filter_by_time_of_day()` (on
  `frequencies` and `stop_times`), `frequencies_to_stop_times()` and
  `filter_fare_rules_from_zone_id()` in `R/filter_helpers.R` (`.flagged` on
  `fare_rules`) add temporary columns to the caller's tables by reference and drop them
  afterwards. That leaves junk columns if they error midway. New code copies
  first.
- Filtering subsets (`dt[i]`) produce new tables and leave the caller's data
  alone. data.table auto-indexing may still add an `index` attribute to the
  caller's table. That is accepted: don't add `copy()` calls to prevent it,
  because that costs performance for no data safety.
- Use `:=` for in-place updates of tables the function already owns. Use
  `%chin%` for character membership. Filters use this two-line idiom and pass
  `` `%ffilter%` `` to the helpers in `R/filter_helpers.R` as an argument:
  ```r
  `%ffilter%` <- `%chin%`
  if (!keep) `%ffilter%` <- Negate(`%chin%`)
  ```
- Long calls are split one argument per line (example from
  `convert_time_to_seconds()`, where `by_reference` guards the update):
  ```r
  gtfs$stop_times[
    ,
    departure_time_secs := string_to_seconds(departure_time)
  ]
  ```
- No row-wise loops or `apply` over rows. Prefer vectorised operations, keyed
  joins / `on =` joins, and grouping with `by =`.

## A4. Messages and errors (cli)

- **Today:** messages use base `stop()`/`warning()`/`message()`, with
  `call. = FALSE` used inconsistently. cli is used only for the two deprecation
  warnings.
- **[NEW] New or modified code** uses `cli::cli_abort()`, `cli::cli_warn()` and
  `cli::cli_inform()` with inline markup (`{.arg x}`, `{.fn f}`, `{.file f}`,
  `{.val v}`).
- **[NEW]** Give errors a class when tests or users may want to catch them:
  `class = "gtfstools_<topic>_error"`, where `<topic>` is a short label such
  as `bad_crs`.
- Existing base calls are migrated gradually, never as a drive-by inside an
  unrelated change. Each migration is its own planned step, and any snapshot
  changes get reviewed.
- **Deprecations (existing pattern):** `cli::cli_warn(class =
  "deprecated_<thing>", ...)` naming the replacement, tested with
  `expect_warning(..., class = "deprecated_<thing>")`, and kept for at least one
  CRAN release (see `filter_by_sf()`, `filter_by_stop_id(full_trips)`).
  `lifecycle` is not a dependency.

## A5. Style

- 2-space indent, `<-`, 80-column lines, snake_case, explicit `return()` at the
  end of functions.
- Blank lines between top-level functions: three in new files and in files that
  already use three (e.g. `utils.R`). Otherwise match the file:
  `filter_helpers.R` and `validate_gtfs.R` use one. Comments are lowercase
  prose explaining *why*, with a blank line around them.
- Code must pass `.lintr` (defaults minus `object_usage_linter` and
  `commented_code_linter`).
- Long, descriptive names for internal helpers
  (`filter_calend_dates_from_service_id`). Helpers shared by a family live in
  `<family>_helpers.R`.

## A6. Documentation (roxygen2, markdown)

- Use `@template gtfs` for the `gtfs` argument
  (`man/roxygen/templates/gtfs.R`). Link with `[fun()]`.
- Use the existing `@family` tags where they apply (`filtering functions`,
  `io functions`, `validation`). `get_*`/`convert_*` have no family; don't add
  one without a plan. Internal helpers either have no roxygen
  (`filter_helpers.R`) or use `@keywords internal` (`utils.R`); match the file.
- **Examples** use the bundled fixtures and limit data.table threads for CRAN
  CPU time:
  ```r
  #' @examples
  #' \dontshow{
  #'   old_dt_threads <- data.table::setDTthreads(1)
  #'   on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)
  #' }
  #' data_path <- system.file("extdata/spo_gtfs.zip", package = "gtfstools")
  #' gtfs <- read_gtfs(data_path)
  ```
  Tests and vignettes instead set `Sys.setenv(OMP_THREAD_LIMIT = 2)`.
- Every new export is added to a section of `_pkgdown.yml`. Check with
  `pkgdown::check_pkgdown()` (Gate 1); the `pkgdown` pre-commit hook does the
  same only where pre-commit is installed.
- Never hand-edit generated files. Edit the source and regenerate:

  | Generated file | Regenerate with |
  |---|---|
  | `NAMESPACE`, `man/*.Rd` | `devtools::document()` |
  | `R/cpp11.R`, `src/cpp11.cpp` | `cpp11::cpp_register()`; `document()` also runs it |
  | `README.md` | `rmarkdown::render("README.Rmd")` |
  | `codemeta.json` | `codemetar::write_codemeta()` (synced from DESCRIPTION) |

## A7. Tests (testthat 3e)

- One file per function: `tests/testthat/test-<function>.R`. Load fixtures with
  `system.file("extdata/<x>_gtfs.zip", package = "gtfstools")`.
- Common structure: fixtures, then a `tester()` wrapper with default arguments
  (most files; about a third have none), then `test_that()` blocks. About half
  the files have a `# tests ---` header before the blocks; match the file.
- **New or modified functions** need at least:
  - "raises error due to incorrect input types"
  - "results in a dt_gtfs object" (or the documented return class)
  - **"doesn't change given gtfs"**, using the repo's pattern:
    ```r
    original_gtfs <- read_gtfs(spo_path)
    gtfs <- read_gtfs(spo_path)
    expect_identical(original_gtfs, gtfs)
    result <- tester(gtfs)
    expect_equal(original_gtfs, gtfs, ignore_attr = TRUE)  # indices may differ
    ```
  - behaviour when optional files or fields are missing. Build those fixtures
    with the internal helpers `copy_gtfs_without_file()`,
    `copy_gtfs_without_field()` and `copy_gtfs_diff_field_class()`
    (`R/utils.R`).
  - at least one feed besides `spo` when behaviour can differ (`ggl` and `ber`
    have different optional files)
- Restore global state with `on.exit()`. `withr` is not a dependency; add it
  to Suggests only through a plan.
- The whole suite is skipped on CRAN (`tests/testthat.R`).
- `test-validate_gtfs.R` is fully disabled, and `test-download_validator.R`
  is disabled from its second block on (line 42), by an unconditional
  `testthat::skip()` (backlog). New Java or
  network tests use `skip_on_cran()`, `skip_if_offline()` and a Java check.
  Re-enabling the disabled ones needs a plan.

## A8. Performance

- Treat performance as part of correctness. Watch for avoidable `copy()`s,
  repeated joins inside loops, growing objects, `sf` work on full tables when a
  subset would do, and repeated character↔time conversions.
- For time conversions, use the vectorised `string_to_seconds()` /
  `seconds_to_string()` from `R/utils.R`, which wrap cpp11 code.
  `seconds_to_string()` requires a non-negative integer, so wrap doubles in
  `as.integer()`.
- **A claimed speed-up needs evidence:** `bench::mark(old = ..., new = ...)` on
  at least the `spo` fixture (plus a larger feed when relevant), results checked
  equal, and the timings recorded in the plan or session log. `bench` is a dev
  tool, not a dependency.
- Don't add a hard dependency (Imports) without a plan that justifies it.

## A9. NEWS.md

Entries go under `# gtfstools (development version)`. Section headings used
in the repo, in no fixed order:
- `## New features`
- `## Bug fixes`
- `## Feature deprecation`
- `## Breaking changes` (only changes that break existing code or change
  correct results; never "Potentially breaking")
- `## Notes`

```
- `fun()` gains `arg` to ... (#issue). PR contribution by @handle.
- Fixed a bug in `fun()` that ... (#issue).
```

Function names go in backticks, packages as `{pkg}`. Credit external
contributors.

## A10. Figures (vignettes, README, pkgdown)

- **Existing convention:** ggplot2 is in Suggests and chunks are gated with
  `eval = requireNamespace("ggplot2", quietly = TRUE)`.
- **[NEW] Publication-ready standard for new or modified figures:**
  - one consistent theme (`theme_minimal()` base unless a plan says otherwise)
  - a colour-blind-safe palette (viridis / Okabe-Ito)
  - labelled axes with units, no chart junk
  - fixed `fig.width`, `fig.height` and `dpi` in chunk options
  - maps with `sf` objects in EPSG 4326, or a stated projected CRS

  Existing figures are restyled only through a plan.

---

# Part B: general CRAN standard

- **DESCRIPTION:** `Imports` for code in `R/`, `Suggests` for
  tests/vignettes/optional paths, `Depends` only for the R version. Version
  floors only when a feature requires them. `Authors@R` with roles.
- **Docs:** every export documents all `@param`s, `@return`, and runnable
  `@examples`. Use `\donttest{}` for slow-but-correct examples; never use
  `\dontrun{}` to hide errors.
- **Red flags:**

| Red flag | Do instead |
|---|---|
| `library()`/`require()` in `R/` | `pkg::fun()` |
| Writing outside `tempdir()` | Write only to `tempdir()` or user-supplied paths |
| `<<-` to global env | Return values |
| `print()`/`cat()` in functions | `cli::cli_inform()`, gated on `quiet`/`verbose` where relevant |
| `options()`/`par()`/threads changed, not restored | `on.exit(..., add = TRUE)` |
| `T`/`F` | `TRUE`/`FALSE` |
| Unvalidated enumerated arg | `checkmate::assert_names(x, subset.of = ...)` (A2) |
| `==` on doubles | `abs(x - y) < tol` or `all.equal()` |
| [NEW] Implicit `na.rm` on feed data | State `na.rm` explicitly in new or modified code |
| Growing vectors in loops | Pre-allocate or vectorise |

- **Versioning:** dev versions use `x.y.z.9000`. The maintainer bumps release
  versions; Claude never does.

## Checklist (new or modified code)

```
[ ] pkg::fun() everywhere (except data.table operators / ggplot2 in docs)
[ ] assert_and_assign_gtfs_object() + checkmate validation; dt_gtfs returned
[ ] input gtfs data not modified (copy() or by_reference); test proves it
[ ] works without optional files/fields (skip silently; warn only if table lacks a needed field); tested on >1 fixture
[ ] cli::cli_* for new messages; error classes where useful
[ ] style: 2 spaces, <-, 80 cols, return(), lintr clean, file's blank-line style
[ ] roxygen: @template gtfs, @family where one exists, @return, examples with setDTthreads guard
[ ] new exports listed in _pkgdown.yml
[ ] devtools::document() run; no hand-edited generated files
[ ] NEWS.md bullet for user-facing changes
[ ] perf claims backed by bench::mark with equal results
```

## Cross-references

- [`quality-gates.md`](quality-gates.md): when each check must pass.
- `.claude/agents/r-package-reviewer.md` enforces this rule. It is local to the
  maintainer's setup and may be absent in a fresh clone; if so, apply the
  checklist manually.
