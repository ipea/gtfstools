---
paths:
  - "R/**"
  - "src/**"
  - "tests/**"
  - "vignettes/**"
  - "man/roxygen/**"
  - "README.Rmd"
  - "DESCRIPTION"
  - "NEWS.md"
  - "_pkgdown.yml"
---

# Quality gates (gtfstools)

Gates are **pass/fail checks**, not scores. A task is "done" only when the gate
for its checkpoint passes and the output has actually been seen; "should work"
doesn't count.

## Gate 1: Task done / commit

All must hold for the files touched:

| Check | Command | Pass |
|---|---|---|
| Docs regenerated | `Rscript -e "devtools::document()"` then `git diff --stat man/ NAMESPACE R/cpp11.R src/cpp11.cpp` | No unexpected content drift (use `git diff`, not `git status`: with `core.autocrlf` cpp11 rewrites line endings only); intended changes staged with the source |
| Targeted tests | `Rscript -e "devtools::test(filter = '<fn>')"` for every touched function | 0 failures, 0 new warnings |
| Lint | `Rscript -e "lintr::lint('R/<file>.R')"` per changed file | No new lints |
| README | if `README.Rmd` changed: `rmarkdown::render("README.Rmd")` | `README.md` regenerated and staged with `README.Rmd` |
| NEWS | user-facing change | Bullet under `# gtfstools (development version)` |
| codemeta | if `DESCRIPTION` changed: `Rscript -e "codemetar::write_codemeta()"` | `codemeta.json` regenerated and staged (or reason noted) |
| pkgdown index | if an `@export` was added or removed: `Rscript -e "pkgdown::check_pkgdown()"` | No missing or stale topics in `_pkgdown.yml` |
| Staging hygiene | `git diff --cached --name-only` | No `.rds`/`.RData`/`.Rhistory`; no workflow files except `CLAUDE.md` and `.claude/rules/` |
| Conventions | `.claude/rules/r-package-conventions.md` checklist | All items hold |

## Gate 2: Pull request

Gate 1, plus:

| Check | Command | Pass |
|---|---|---|
| Full suite | `Rscript -e "devtools::test()"` | 0 failures |
| CRAN check | `Rscript -e "devtools::check(args = '--as-cran')"` (background; several minutes) | 0 errors, 0 warnings; each NOTE triaged (pre-existing vs new) |
| Review loop | parallel review lenses (`orchestrator-protocol.md`) | Converged: 0 open CRITICAL/MAJOR |
| Package review | `r-package-reviewer` agent on changed files (local; if absent, apply the conventions checklist manually) | 0 CRITICAL/MAJOR |
| Performance | if the change claims or risks a speed change | `bench::mark` evidence recorded |

## Gate 3: Release (maintainer-driven)

Gate 2, plus `/gt-package-check` (full report), `devtools::check_win_devel()`
and/or R-hub, a reverse-dependency check, `cran-comments.md` updated, and
`_pkgdown.yml` covering all exports. Claude prepares; the maintainer bumps the
version and submits.

## Overrides

A gate may be skipped only on an explicit user instruction ("commit anyway"),
and the reason is recorded in the commit body and the session log. Never use
`git commit --no-verify`. The repo's `.pre-commit-config.yaml` hooks (README
rendered, codemeta synced, pkgdown reference index, no `.rds`/`.RData`/
`.Rhistory`) run only where `pre-commit install` has been run. That is why
Gate 1 checks README and staging explicitly instead of relying on the hooks.

## Pre-existing failures

If a gate fails for reasons unrelated to the change, don't fix it as a drive-by.
Report it, confirm it also fails on `main`, and add it to the backlog
(`quality_reports/specs/`).
