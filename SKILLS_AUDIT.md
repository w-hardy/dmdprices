# dmdprices package audit

Audited against the Posit Claude skills vendored into `.claude/skills/`
(`r-package-development`, `testing-r-packages`, `cli`, `cran-extrachecks`,
`lifecycle`, `critical-code-reviewer`). Date: 2026-06-30.

R 4.3.3 and all dependencies were installed (from the Ubuntu `r-cran-*`
archive — the egress policy blocks CRAN mirrors), so the findings below were
verified with `devtools::test()` and `devtools::check()`.

## Status after this branch

```
devtools::test()  -> [ FAIL 0 | WARN 0 | SKIP 0 | PASS 331 ]
devtools::check() -> 0 errors | 0 warnings | 1 note
```

The single remaining NOTE is *"checking for future file timestamps … unable to
verify current time"*, which is environmental (the sandbox has no time source)
and will not appear on a normal machine or CI. Vignettes were not built during
check (they render against the full 118k-row dataset); run
`devtools::check()` with vignettes locally before release.

---

## Applied and verified in this branch

- **`R/nhscii.R` — bare `stop()` → `cli::cli_abort()` (6 sites).** Now matches
  the CLAUDE.md "always cli, never bare `stop()`" rule, with `{.arg}`/`{.val}`
  inline classes and `"i"` hint bullets. Errors are attributed to the
  user-facing caller (`call = rlang::caller_env()`) so they read
  `Error in nhscii():` rather than naming an internal helper.
- **`R/nhscii.R` — internal helpers dot-prefixed.** `validate_scalar`,
  `normalize_fin_year`, `build_index_levels` → `.validate_scalar`,
  `.normalize_fin_year`, `.build_index_levels`, per the `.`-prefix convention.
- **`tests/testthat/test-nhscii.R` — text-matching `expect_error()` → snapshots.**
  The four `expect_error(regexp=)` validation assertions are now a single
  `expect_snapshot(error = TRUE)` test; recorded in
  `tests/testthat/_snaps/nhscii.md`. The full cli error output is now reviewable.
- **`R/apps.R` — bare `stop()` → `cli::cli_abort()` (3 sites).**
- **`DESCRIPTION` — added `cph` (copyright holder) role** to `Authors@R` (CRAN
  requirement); `man/dmdprices-package.Rd` re-documented to match.
- **`R/dmdprices-package.R` — dropped the unused `@importFrom memoise cache_memory`.**
  Only `memoise::memoise()` is used (qualified); `cache_memory` was never called.
- **`R/dmdprices-package.R` / NAMESPACE — added `@importFrom DT datatable`.**
  Fixes the `R CMD check` NOTE *"Namespace in Imports field not imported from:
  'DT'"*. `DT` is a real runtime dependency of the bundled Shiny apps
  (`DT::datatable`/`renderDT`/`DTOutput`); this mirrors the existing
  `bslib bs_theme` import.
- **`NEWS.md` — fixed the NEWS-parsing NOTE.** `## Behaviour changes (upgrading
  from 0.3.0)` contained a literal `0.3.0`, which R's NEWS.md parser misread as a
  version and then failed on the sibling `##` subsection titles. Renamed to
  `## Behaviour changes` (the "from 0.3.0" context moved into prose). `R CMD
  check` now parses 0.5.0 / 0.4.0 / 0.3.0 / 0.2.0 cleanly.
- **`.nhscii_rates` orphaned man page** — `@noRd` added; `man/dot-nhscii_rates.Rd`
  removed (it documented a non-exported internal as a public topic).
- **`.Rbuildignore`** — excludes `.claude/`, `agents.md`, `SKILLS_AUDIT.md`.

---

## Recommended (not applied — judgement calls or large mechanical sweeps)

### 1. Test modernisation — `expect_true()`/`expect_false()` → specific expectations
~70 `expect_true()/expect_false()` calls, mostly in `test-dmd_dose_optimise.R`,
lose diff quality on failure. Highest-value swaps:
- `expect_true(grepl(p, x))` / `expect_true(any(grepl(...)))` → `expect_match()`
  (`:164, 166, 348, 369, 839, 914, 979, 1128, 1211`).
- `expect_true(a <= b)` / `>=` → `expect_lte()` / `expect_gte()`
  (`:276, 912, 930, 945, 980`).
- `expect_true(is.na(x))` → `expect_equal(x, NA_real_)` (`:646, 1518`).
- `test-dmd_load.R:63` `expect_true(inherits(…))` → `expect_s3_class()`.

This is the `nhscii.R` snapshot migration repeated across the suite; left out to
keep this branch's diff focused and reviewable. Happy to do it as a follow-up.

### 2. More message-text assertions → snapshots
~17 `expect_error()/expect_warning(regexp=)` in `test-dmd_dose_optimise.R`
(`:64, 203, 794, 1004, 1052, 1131, 1147, 1431`) plus three hand-rolled
`withCallingHandlers(... muffleWarning)` blocks (`:1068, 1246, 1282`) should be
`expect_snapshot()`, the same pattern applied to `nhscii` here.

### 3. Coverage gaps
- `dmd_load()` happy path: only error branches are tested; no test loads a fake
  CSV folder through the public function and checks the `<dmd_db>` result.
- `print.dmd_db` / `format.dmd_db`: untested — good `expect_snapshot()` targets.
- `run_dmd_price_lookup` / `run_dmd_dose_optimise` / `run_inflate_nhscii`:
  untested; the `system.file() == ""` branch can be snapshot-tested and the
  launch mocked with `local_mocked_bindings(runApp = …)`.

### 4. `lifecycle` deprecation version (maintainer decision)
`R/dmd_dose_optimise.R:491, 731` call `deprecate_warn("0.6.0", …)` but
`DESCRIPTION` is `Version: 0.5.0` and `NEWS.md` is "(development version)". Pick
the next release number and make the `when` string, `DESCRIPTION`, and the NEWS
header agree. Optionally run `usethis::use_lifecycle()` to add the standard
badge SVGs / `@importFrom lifecycle deprecated` (currently absent — the package
uses `lifecycle::deprecate_warn()` directly, which works but skips the infra).

### 5. `dmd_dose_cost_range()` fragile warning de-duplication
`R/dmd_dose_optimise.R:976` dedupes the "unsupported compound" warning by
`grepl()`-ing the message text from `.drop_unsupported_compounds()`. Reword that
message and the dedup silently breaks. Emit it with a custom condition class
(`cli::cli_warn(…, class = "dmdprices_unsupported_compound")`) and filter on
`inherits()` instead. (Observed live: the metformin example fires this warning
4× — once per call — which class-based dedup would also let callers suppress
cleanly.)

### 6. `DESCRIPTION` Description — quote software name
`dmdDataLoader` is a tool name; single-quote it (`'dmdDataLoader'`) per CRAN
convention. (Title, length, opening phrase, and acronyms are all fine.)

### 7. `helper.R` fixture
`.fake_dose_db()` is well-built but sets `loaded_at = Sys.time()`
(non-deterministic) — use a fixed timestamp if any whole-`<dmd_db>` snapshot is
added later. `.codeine_db()` lives in a test file rather than `helper.R`.

### 8. `cran-comments.md` / README CRAN line — only if CRAN submission is planned
The package is currently GitHub-only. Before a CRAN submission add
`cran-comments.md` (`usethis::use_cran_comments()`) with a "Method References"
note (the PSSRU manual is already cited via `\doi{}`) and add an
`install.packages("dmdprices")` line to the README.

---

## Verified clean (no action)

- `R CMD check`: examples OK, Rd OK, tests OK, no code/doc mismatch.
- Base pipe `|>` everywhere; no `%>%`; no `T`/`F`; no `TODO`/`FIXME`/dead code.
- All exported functions have `@return` and `@examples`.
- **`\dontrun{}` on the dose-function examples is justified** (correcting an
  earlier recommendation): tested live, `dmd_dose_optimise()` takes ~10s on the
  first call over the full dataset (well past CRAN's 5s example budget), and the
  `dmd_dose_cost`/`dmd_dose_cost_range` examples reference an illustrative
  `treatment_df` that is intentionally undefined. `\donttest{}` is an option for
  the runnable `dmd_dose_optimise` snippet, but `\dontrun{}` is acceptable.
- `print.dmd_dose_combination()` uses `cat()` — acceptable for a print method.
- `cachem` IS in `DESCRIPTION`; `man/dmd_ingredients.Rd` is a real dataset topic.
- `LICENSE` / `LICENSE.md` / `inst/CITATION` year is 2026 (current).
- DP-solver integer-overflow guarding (`dose_combinations.R`) is careful.
