# dmdprices package audit

Audited against the Posit Claude skills vendored into `.claude/skills/`
(`r-package-development`, `testing-r-packages`, `cli`, `cran-extrachecks`,
`lifecycle`, `critical-code-reviewer`). Date: 2026-06-30.

R 4.3.3 and all dependencies were installed (from the Ubuntu `r-cran-*`
archive — the egress policy blocks CRAN mirrors), so the findings below were
verified with `devtools::test()` and `devtools::check()`.

## Status after this branch

```
devtools::test()  -> [ FAIL 0 | WARN 0 | SKIP 0 | PASS 352 ]
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

### Test modernisation (whole suite)

- **`expect_true()/expect_false()` → specific expectations.** ~45 wrapped-predicate
  assertions across `test-dmd_dose_optimise.R`, `test-dmd_price_lookup.R`,
  `test-parse_strength.R`, `test-dmd_load.R` converted to `expect_match()`,
  `expect_gte()/lte()/gt()`, `expect_contains()`, `expect_s3_class()`, and
  `expect_equal(x, NA_*)` for real failure diffs. Direct scalar-boolean field
  checks (e.g. `expect_false(res$is_combination)`) and a few "absence" /
  multi-clause invariants with no cleaner form were intentionally kept.
- **Message-text `expect_error()/expect_warning(regexp=)` → snapshots.** ~19
  assertions (incl. three hand-rolled `withCallingHandlers(... muffleWarning)`
  blocks) migrated to `expect_snapshot()` / `expect_snapshot(error = TRUE)`.
  New snapshots: `_snaps/dmd_dose_optimise.md`, `_snaps/dmd_load.md`,
  `_snaps/dmd_price_lookup.md`. The full cli output is now reviewable, and the
  verbose manual warning-collectors are gone.
- **`R/dmd_dose_optimise.R` — fixed a broken deprecation message (found by the
  snapshot migration).** The `objective = "both"` `deprecate_warn()` passed
  `what = 'dmd_dose_optimise(objective = "both")'`, which `lifecycle` mis-parsed
  into the ungrammatical *"The `objective` argument of `dmd_dose_optimise()` both
  as of dmdprices 0.6.0."*. Switched to `what = I('`objective = "both"`')`, which
  now reads *"`objective = "both"` was deprecated in dmdprices 0.6.0."* (both
  `dmd_dose_optimise()` and `dmd_dose_cost()` call sites).
- **Kept the `print.dmd_dose_combination` test as `expect_output(…, "Metformin")`**
  rather than a full snapshot: the printed output contains a `×` (U+00D7) glyph
  that serialises to `<U+00D7>` and would not be portable across locales/OSes.

### Coverage gaps closed

- **`dmd_load()` end-to-end.** Previously only its two error branches and the
  internal `.build_master()` were tested. Added a `local_temp_dmd_dir()` fixture
  that writes a minimal, valid pipe-delimited `csv/` folder (two products, one a
  combination) and three tests: the no-VPI happy path (asserts the `<dmd_db>`
  shape, units, price, and `$ingredients == NULL`), the with-VPI path (asserts
  `$ingredients` and the `is_combination` flag), and a missing-required-file
  error. Covers the ingredient-join branch and `.read_dmd`/`.read_dmd_optional`.
- **`print.dmd_db` / `format.dmd_db`.** Now tested — `format()` by exact string,
  `print()` by snapshot for both the plain and ingredient-bearing fixtures.
- **`run_dmd_price_lookup` / `run_dmd_dose_optimise` / `run_inflate_nhscii`.**
  New `test-apps.R`: success paths mock `shiny::runApp` and assert the resolved
  app dir; the missing-app branch is snapshot-tested. Required a small refactor —
  the three duplicated launcher bodies now share an internal `.app_dir()` /
  `.app_path()` seam (the `.app_path()` wrapper exists specifically so the
  missing-app branch is mockable: base `system.file()` cannot be mocked under
  `R CMD check`).
- **Deterministic fixtures.** `.fake_dose_db()` / `.fake_ingredient_db()` take a
  `loaded_at` argument defaulting to a fixed timestamp, so the print snapshots
  above are stable (also resolves the `Sys.time()` fixture note).

---

## Recommended (not applied — judgement calls or larger work)

### 1. `lifecycle` deprecation version (maintainer decision)
The two `deprecate_warn()` calls now use `when = "0.6.0"` but `DESCRIPTION` is
`Version: 0.5.0` and `NEWS.md` is "(development version)". Pick the next release
number and make the `when` string, `DESCRIPTION`, and the NEWS header agree.
Optionally run `usethis::use_lifecycle()` to add the standard badge SVGs /
`@importFrom lifecycle deprecated` (currently absent — the package uses
`lifecycle::deprecate_warn()` directly, which works but skips the infra). *(The
malformed `what` argument itself is already fixed — see above.)*

### 2. `dmd_dose_cost_range()` fragile warning de-duplication
`R/dmd_dose_optimise.R:976` dedupes the "unsupported compound" warning by
`grepl()`-ing the message text from `.drop_unsupported_compounds()`. Reword that
message and the dedup silently breaks. Emit it with a custom condition class
(`cli::cli_warn(…, class = "dmdprices_unsupported_compound")`) and filter on
`inherits()` instead. (Observed live: the metformin example fires this warning
4× — once per call — which class-based dedup would also let callers suppress
cleanly.)

### 3. `DESCRIPTION` Description — quote software name
`dmdDataLoader` is a tool name; single-quote it (`'dmdDataLoader'`) per CRAN
convention. (Title, length, opening phrase, and acronyms are all fine.)

### 4. `helper.R` fixture tidy-up (minor)
`.codeine_db()` is defined in `test-dmd_dose_optimise.R` rather than alongside
the other constructors in `helper.R` — a small consistency nit. (The
`Sys.time()` non-determinism is now fixed — see "Deterministic fixtures".)

### 5. `cran-comments.md` / README CRAN line — only if CRAN submission is planned
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
