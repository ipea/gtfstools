# CLAUDE.md — gtfstools

**gtfstools** is an R package for editing and analysing transit feeds in GTFS
format. Feeds are read as lists of `data.table`s (class
`c("dt_gtfs", "gtfs", "list")`), which makes manipulation simple and fast.
Published on CRAN; developed by Ipea (ipeaGIT). Maintainer: Daniel Herszenhut.
License MIT. Docs: <https://ipeagit.github.io/gtfstools/>.

---

## Core principles

- **Performance is a feature.** Vectorised `data.table` code, no avoidable
  copies. Any claimed speed-up needs a `bench::mark()` comparison with equal
  results checked.
- **Never surprise the caller.** Functions don't modify the input `gtfs`
  unless they explicitly offer `by_reference`.
- **CRAN-ready at all times.** `R CMD check --as-cran`: 0 errors, 0 warnings.
- **Plan first.** Enter plan mode before non-trivial tasks. Every plan must be
  reviewed by two adversarial agents that improve it and make it simpler, with
  as little code intervention as possible. Present the plan only when both
  agents reach consensus (max 3 rounds, then escalate the disagreement). Plans
  live in `quality_reports/plans/`.
- **Verify after.** Every task ends with the gates below, not with "should work".
- **Learn from corrections.** Log `[LEARN:category] wrong → right` in
  `MEMORY.md`.
- **Code style.** Always use the convention `package::function()`. Exceptions
  are functions from ggplot2 and special data.table operators such as `:=`.

Conventions are in [`.claude/rules/r-package-conventions.md`](.claude/rules/r-package-conventions.md);
gates are in [`.claude/rules/quality-gates.md`](.claude/rules/quality-gates.md).

---

## Repository map

```
gtfstools/
├── DESCRIPTION, NAMESPACE        # NAMESPACE is roxygen-generated; never hand-edit
├── R/                            # mostly one exported function per file (+ *_helpers.R, utils.R)
│   ├── gtfstools.R               # package doc, importFrom, utils::globalVariables()
│   └── cpp11.R                   # generated; never hand-edit
├── src/                          # cpp11 C++ (time conversions)
├── tests/testthat/               # test-<function>.R; suite skipped on CRAN
├── inst/extdata/                 # fixtures: spo_gtfs.zip, poa_gtfs.zip, ber_gtfs.zip, ggl_gtfs.zip
├── man/roxygen/templates/        # @template gtfs
├── vignettes/                    # gtfstools.Rmd, filtering.Rmd, validating.Rmd
├── README.Rmd → README.md        # edit the .Rmd, then re-render
├── NEWS.md                       # user-facing changelog
├── _pkgdown.yml                  # reference index; every export must be listed
├── .github/workflows/            # R CMD check matrix, as-cran, pkgdown, coverage, rhub
├── .pre-commit-config.yaml       # readme-rendered, codemeta, pkgdown, no .rds/.RData (active only after `pre-commit install`)
└── .lintr
```

Function families: `read_gtfs`/`write_gtfs` · `filter_by_*` · `get_*` ·
`convert_*` · `set_trip_speed` · `merge_gtfs` · `remove_duplicates` ·
`frequencies_to_stop_times` · `validate_gtfs`/`download_validator`/`list_validator_versions` ·
`as_dt_gtfs`.

Local-only workflow files (gitignored and Rbuildignored): `MEMORY.md`,
`quality_reports/`, `templates/`, and everything in `.claude/` except `rules/`.

---

## Commands

```r
devtools::load_all()
devtools::document()                         # regenerate man/ + NAMESPACE
devtools::test()                             # full suite (sets NOT_CRAN=true)
devtools::test(filter = "filter_by_route_id")
devtools::check(args = "--as-cran")          # long; run in background
lintr::lint("R/<file>.R")                    # or lintr::lint_package()
rmarkdown::render("README.Rmd")              # after editing README.Rmd
pkgdown::build_site()
covr::package_coverage()
```

- CRAN checks CPU time, so threads are capped. Tests and vignettes set
  `Sys.setenv(OMP_THREAD_LIMIT = 2)`; examples use a `\dontshow{}`
  `data.table::setDTthreads(1)` guard.
- The validator needs Java. Its tests are currently disabled with an
  unconditional `skip()` (backlog).

---

## Quality gates (summary)

| Checkpoint | Must hold |
|---|---|
| Commit | `document()` produces no content drift (`git diff`); tests for touched functions pass; `lintr` clean on changed files; README re-rendered if `README.Rmd` changed; `NEWS.md` entry for user-facing changes |
| PR | Full `test()` passes; `check(--as-cran)` gives 0 errors / 0 warnings, NOTEs triaged; review loop converged; `r-package-reviewer` 0 CRITICAL/MAJOR |
| Release | `/gt-package-check`; win-builder + rhub; reverse-dependency check; `cran-comments.md` updated |

Never bypass `.pre-commit-config.yaml` hooks (`--no-verify`). Details: `.claude/rules/quality-gates.md`.

---

## Skills and agents

These are local to the maintainer's Claude setup and are not in git. In a fresh
clone, follow the rules in `.claude/rules/` directly.

Project skills carry a `gt-` prefix so user-level skills with the same base
name can't shadow them. **In this repo, always use the `gt-` version:** use
`/gt-commit`, never a generic `/commit` that merges to `main`. Where
user-level rules conflict with `.claude/rules/`, the project rules win.

- `/gt-package-check`: document, test, check `--as-cran`, triage, reviewer
  report.
- `/gt-commit`: Gate 1, then branch and commit. Push and PR only when asked,
  after Gate 2. **Merging to `main` only on explicit request.**
- `/gt-diagnose`: root-cause a failing test or wrong result.
- `/gt-checkpoint`, `/gt-compress-session`, `/context-status`: session state.
- `/gt-learn`: turn a session discovery into a reusable skill.
- Agent `r-package-reviewer`: read-only CRAN and convention review of
  package source.

---

## Working mode

1. **Plan:** for non-trivial tasks, enter plan mode, explore, ask only about
   real decisions, pass the adversarial plan review, and get approval.
2. **Execute (contractor mode):** after approval, work autonomously through
   implement → verify → parallel review → fix, looping until reviews come
   back dry (see `.claude/rules/orchestrator-protocol.md`). Come back only for
   ambiguity or a decision that belongs to the user.
3. **Report:** summarise what changed, gate results, open questions; log the
   session.

No commits, pushes, PRs, merges, version bumps or `.github/workflows/`
changes without an explicit request. Never hand-edit generated files
(`NAMESPACE`, `man/*.Rd`, `R/cpp11.R`, `src/cpp11.cpp`, `README.md`,
`codemeta.json`).
