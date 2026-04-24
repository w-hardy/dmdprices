# dmdprices (development version)

## Added

- `dmd_dose_cost_range()` — new exported function that returns a tibble with
  `lo_pence` and `hi_pence` columns (one row per dose), giving the cheapest
  and most expensive achievable dose cost in a single call. Designed for
  health-economics range analyses inside `dplyr::mutate()` or
  `dplyr::bind_cols()`. The memoized candidate preparation step is shared with
  `dmd_dose_cost()`, so calling both functions for the same drug incurs the
  expensive lookup work only once.
- `dmd_master_info()` — new exported function returning key metadata (release
  label, load timestamp, AMPP/VMPP/VMP counts, price date range) about
  `dmd_master` or a `dmd_load()` database. Useful for confirming data freshness
  in analysis scripts and Shiny app footers. Returns a `"dmd_db_info"` object
  with a `print()` method.
- `dmd_dose_optimise()` and `dmd_dose_cost()` gain a `"most_expensive"`
  objective, which selects the highest-cost combination of AMPPs. Useful for
  worst-case cost modelling and budget-impact analysis upper bounds.
- `objective` now accepts a **character vector** of any combination of
  `"cheapest"`, `"min_items"`, and `"most_expensive"`. Pass `"all"` as a
  shorthand for all three. The default remains `c("cheapest", "min_items")`.
- `dmd_dose_optimise()` and `dmd_dose_cost()` gain `can_split_vials = FALSE`.
  Set to `TRUE` to cost concentration preparations (vials, ampoules) as a
  fraction of a container (vial sharing), which adds `"vial-sharing"` to the
  `notes` column and returns a non-integer `count` in the combination tibble.
- `cachem` and `lifecycle` added to `Imports`.

## Deprecated

- `objective = "both"` in `dmd_dose_optimise()` and `dmd_dose_cost()` is
  deprecated. Replace with `objective = c("cheapest", "min_items")`. A
  `lifecycle::deprecate_warn()` warning is emitted on first use.

## Fixed

- `dmd_dose_cost(objective = "most_expensive")` now returns the worst-case cost
  (maximum across preparation groups) instead of silently returning the
  cheapest. Aggregation across multiple objectives uses each objective's
  natural extremum.
- `dmd_dose_optimise(objective = "most_expensive", can_split = FALSE)` now
  selects the dearest whole-pack combination rather than falling through to
  the cheapest branch. The notes column reads `"most-expensive-pack-per-dose"`
  on this path.
- `print.dmd_dose_combination()` and the dose-optimiser Shiny app's
  combination formatter use `%g` instead of `%d` so fractional
  vial-sharing counts (e.g. `0.5`) render without a warning.
- `DT` moved back to `Imports` (from `Suggests`) so `run_dmd_price_lookup()`
  works on a fresh install without a separate `install.packages("DT")` step.
- `dmd_dose_optimise()` result columns are now in the same order as the empty
  scaffold returned when no candidates are found (`dose_cost_pence` was
  previously appended after `notes` rather than between `cost_whole_pack_pence`
  and `price_field_used`).
- `dmd_dose_cost()` now emits an informative error when `dose` is a character
  string, explaining the difference from `dmd_dose_optimise()`.
- Memoization cache is now capped at 256 MB via `memoise::cache_memory()` to
  prevent unbounded memory growth in long-running sessions.
- Dead code removed from `.best_target()` internal function (`min_items` branch
  had a redundant feasibility filter that was always a no-op).

## Performance

- The memoized candidate preparation step now keys on lightweight scalars
  (`dmd_db$loaded_at`, or the `dmd_release_label` attribute of the bundled
  `dmd_master`) rather than hashing the full 118k-row tibble on every call.
  This eliminates a ~10 ms per-call digest overhead for the common case where
  the database does not change within a session.
- `.dose_dp()` internal DP function: the inner per-strength loop is now fully
  vectorised using `which.min()` and R vector arithmetic, replacing a pure R
  nested loop. This reduces loop overhead for the outer DP iterations and
  yields a 2–5× speedup for typical drug queries.

## Documentation

- `dmd_dose_optimise()` `@return` now documents that `count` in the
  `combination` tibble means individual dispensing units (tablets/containers)
  when `can_split = TRUE`, and whole packs when `can_split = FALSE`.
- Vignette `dose_optimisation` gains two new sections: "Community pharmacy:
  whole-pack dispensing" (`can_split = FALSE`) and "Vectorised costing with
  `dmd_dose_cost()`".

# dmdprices 0.5.0

## Added

- `dmd_dose_cost()` — vectorised companion to `dmd_dose_optimise()`. Accepts a
  numeric vector of doses and returns a plain numeric vector of costs in pence.
  Designed for use inside `dplyr::mutate()` without `purrr::map_dbl()`.
- `preparation` argument of `dmd_dose_optimise()` and `dmd_dose_cost()` now
  accepts a plain case-insensitive substring (e.g. `"infusion"`) rather than
  requiring the exact preparation group key.

## Performance

- The expensive dose-independent work in `dmd_dose_optimise()` (price lookup,
  strength parsing, preparation classification) is now memoized for the session
  via `memoise`. Repeated calls for the same drug within a session (e.g. across
  all rows of a table) incur that cost only once.

# dmdprices 0.4.0

## Added

- `dmd_dose_optimise()` — given a clinical dose, returns the cheapest and/or
  minimum-item combination of AMPPs that delivers it. Preparations (e.g.
  immediate-release vs modified-release tablets, oral solutions,
  solution-for-injection) are segregated automatically. Each result row
  includes a `combination` list-column identifying the specific branded
  products picked.
- `dmd_parse_strength()` — helper exposing the VMP-name strength parser (amount,
  unit, optional denominator for concentrations such as `mg/ml`,
  `microgram/dose`).

# dmdprices 0.3.0

## Added

- `nhscii()` — compute NHS Cost Inflation Index factors between financial years.
- `inflate_nhscii()` — adjust costs using NHS CII rates.
- Both functions support "pay_and_prices", "pay", and "prices" indices covering
  2015/16–2023/24 (provisional).
- `run_dmd_price_lookup()` — launch the dm+d price lookup Shiny app locally.
- `run_inflate_nhscii()` — launch the NHS CII cost adjuster Shiny app locally.
- Hosted interactive apps on Posit Connect Cloud.

# dmdprices 0.2.0

## Added

- `dmd_load()` — loads a more recent dm+d release from a local `dmdDataLoader`
  CSV directory.
- `dmd_price_lookup()` — queries the pricing table by medicine name with
  "partial", "exact", and "fuzzy" match methods.
- Bundled `dmd_master` dataset (Week 34 2025, 14 August 2025) for zero-setup
  use.
- Output columns mirror the NHS Drug Tariff Part VIIIA CSV format.
