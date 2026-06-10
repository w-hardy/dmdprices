# Agents Guide — dmdprices

Guidance for AI coding agents working on this R package.

## What This Package Does

`dmdprices` is an R package for querying NHS medicine prices from the **dm+d (Dictionary of Medicines and Devices)**. It bundles a complete dm+d release (~118k AMPPs) and provides:

- **`dmd_price_lookup()`** — fuzzy/partial/exact medicine name search returning a price tibble.
- **`dmd_dose_optimise()`** — finds the cheapest / fewest-item combination of branded products (AMPPs) that delivers a given clinical dose.
- **`dmd_dose_cost()`** — vectorised cost lookup for use inside `dplyr::mutate()`.
- **`dmd_load()`** — loads a fresh dm+d release from a `dmdDataLoader` CSV folder.
- **`nhscii()` / `inflate_nhscii()`** — NHS Cost Inflation Index adjustments.
- Three **Shiny apps** (`run_dmd_price_lookup()`, `run_dmd_dose_optimise()`, `run_inflate_nhscii()`).

## Project Layout

```
R/                          # All package source
  dmd_price_lookup.R        # Core search function
  dmd_dose_optimise.R       # Optimiser + vectorised cost + memoized prep
  dose_combinations.R       # Internal DP solver
  parse_strength.R          # Strength parser + preparation classifier
  dmd_load.R                # CSV loader → <dmd_db>
  nhscii.R                  # Inflation index
  apps.R                    # Shiny launchers
  utils.R                   # Internal helpers, column specs, unit table
data/dmd_master.rda         # Bundled dataset (xz-compressed)
data-raw/dmd_master.R       # Script to rebuild bundled data
tests/testthat/             # testthat edition 3 tests
  helper.R                  # Shared .fake_dose_db() fixture
inst/shiny/                 # Shiny app UI/server files
vignettes/                  # Rmd vignettes (9)
.github/workflows/          # R-CMD-check + pkgdown CI
```

## Dev Commands

```r
devtools::document()   # Regenerate man/ from roxygen2 tags — run after any @tag change
devtools::test()       # Run all tests
devtools::check()      # Full R CMD check
devtools::build()      # Build tarball
pkgdown::build_site()  # Rebuild docs site
```

## Coding Rules

1. **Style:** tidyverse — `|>` pipe, `dplyr`/`tibble`/`stringr`/`cli`. No `%>%`.
2. **Errors:** `cli::cli_abort()` only. Never `stop()` or bare `message()`.
3. **Warnings:** `cli::cli_warn()` only.
4. **Internal functions:** prefix with `.` (e.g. `.col_names`). Do not `@export` them.
5. **Docs:** every exported function needs `@param`, `@return`, `@export`, and `@examples` (use `\dontrun{}` when the example needs data/network).
6. **Tests:** testthat edition 3. Use `.fake_dose_db()` from `helper.R` — no real CSVs, no network calls. Add snapshot tests for complex tibble output.
7. **Performance:** cache expensive per-session computations with `memoise::memoise()` + `cachem::cache_mem(max_size = 1024 * 1024^2)`.

## Key Architectural Points

- **Memoization boundary:** `.dmd_prepare_candidates_memo()` (in `dmd_dose_optimise.R`) caches all dose-independent work (price lookup, strength parsing, preparation classification). Everything upstream of this call is cheap per dose; everything downstream (the DP solver) is per-dose.
- **DP solver:** `.optimise_group()` in `dose_combinations.R` — operates on a single `preparation_group` slice; returns a single-row tibble or `NULL`.
- **Unit canonicalisation:** `.canonicalise_unit()` in `utils.R` converts all dose values to a common basis (mg/ml/etc.) before comparison. Always use this; never compare raw user-supplied units directly.
- **Preparation classification:** `.classify_preparation()` in `parse_strength.R` maps the parsed "tail" of a VMP name to `preparation_group` (pipe-delimited key) and `preparation_label` (human-readable). Groups are stable identifiers used throughout the optimiser.
- **`can_split` semantics:** `TRUE` = hospital (pro-rata per tablet/capsule); `FALSE` = community (whole packs only). Concentration-based preps (liquids, vials) are always unsplittable.
- **Result schema:** `.empty_dose_result()` in `dmd_dose_optimise.R` is the canonical column definition. All code paths must return a tibble conforming to this schema.

## Maintaining the Bundled Data

`dmd_master` / `dmd_ingredients` are rebuilt from a dmdDataLoader CSV export via `data-raw/dmd_master.R` (`source()` it from the package root — it saves **both** `.rda` files). Update the release metadata in that script, in `R/data.R`, and in `DESCRIPTION`, then run `document()` / `test()` / `check()`. CSV filenames occasionally change between dm+d releases — update them in `R/dmd_load.R`, `data-raw/dmd_master.R`, and the column specs in `.col_names` (`utils.R`). Full process: `vignette("data_sources_updates")`.

**UoM mapping:** pack units arrive as SNOMED codes and are resolved in `.build_master()` by (1) the curated `.uom_labels` — short, *canonicalisable* labels (`mg`/`ml`/`g`/`dose`/`unit`/…) used for dose costing — then (2) a fallback to the dm+d UoM lookup `DESC` (display-only). A unit that affects **dosing** (concentration pack units like `dose`, `actuation`, `ml`, `g`) must go in `.uom_labels` with a token `.canonicalise_unit()` recognises (`.unit_table` in `parse_strength.R`); display-only units (devices, containers) need nothing. Both layers run at build time. Verify a rebuild with `sum(grepl("^[0-9]+$", dmd_master$unit)) == 0`.

## Common Pitfalls

- After changing any `@` roxygen tag or function signature, run `devtools::document()` before testing — stale `NAMESPACE`/`man/` files cause confusing failures.
- `cachem` is used directly in the memoization setup. Ensure it is listed under `Imports` in `DESCRIPTION`.
- `dmd_dose_cost()` only accepts **numeric** `dose` vectors (not strings like `"500 mg"`). `dmd_dose_optimise()` accepts both.
- Snapshot files in `tests/testthat/_snaps/` must be updated deliberately with `testthat::snapshot_accept()` after intentional output changes — don't silently overwrite them.
- The bundled dataset (`dmd_master`) uses `LazyData: true` — it loads on first access, not at `library()`. Don't assume it's available before first use in tests.
