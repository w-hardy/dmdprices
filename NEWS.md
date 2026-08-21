# dmdprices 0.6.0

## Dose optimisation now delivers the requested dose exactly by default

`dmd_dose_optimise()`, `dmd_dose_cost()`, and `dmd_dose_cost_range()` gain an
`over_delivery` argument, defaulting to `"forbid"` (#23).

Previously every objective optimised across all combinations delivering *at
least* the dose, with over-delivery only a tie-break. When an over-delivering
combination was strictly cheaper, strictly fewer items, or strictly dearer, an
available exact-dose combination was never surfaced by any objective — a 3 mg
buprenorphine sublingual dose returned 4 mg (`cheapest`), 8 mg (`min_items`),
and 11 mg (`most_expensive`), so `dmd_dose_cost()` silently costed 4 mg.

- `"forbid"` (new default) returns only exact-dose combinations. A preparation
  group that cannot hit the dose exactly returns no row and is named in a single
  warning per call; `dmd_dose_cost()` returns `NA` for such doses.
- `"minimise"` returns the smallest achievable over-delivery, with the requested
  objective applied within it.
- `"allow"` restores the previous behaviour.

The policy applies where one item is an individually administered dose. Whole
pack dispensing (`can_split = FALSE`) and whole containers (vials and ampoules
with `can_split_vials = FALSE`) are exempt — there the surplus is wastage, so
the cheapest pack or container covering the dose is still returned, with an
`"over-delivery-policy-not-applied"` note.

Results gain a `dose_exact` logical column, and `notes` gains `"exact-dose"`,
`"over-delivery-minimised"`, and `"over-delivery-policy-not-applied"` entries,
so an optimised exact dose, an impossible one, and a query that matched nothing
are all distinguishable.

A returned combination that over-delivers now also raises a warning — one per
call, listing the preparation groups and saying whether no exact combination
existed or whether one existed but the objective preferred an over-delivering
combination. This matters most for `dmd_dose_cost()` and `dmd_dose_cost_range()`,
which return bare numbers and so cannot show the `notes` column. The exempt
whole-pack and whole-container results do not warn, since their surplus is
expected wastage. `quiet = TRUE` (new argument on all three functions) silences
this warning and the no-exact one, leaving unrelated warnings intact.

## Behaviour changes (upgrading from 0.3.0)

No functions were removed or renamed and no argument signatures changed, so
existing code continues to run. However, the following changes can alter
**results** and are worth noting when upgrading:

- **NHS CII 2023/24 figures revised.** Following the PSSRU 2025 manual, the
  provisional 2023/24 rates have been revised (e.g. `pay_and_prices` 2023/24
  moved from `4.31%` to `2.47%`). Any `nhscii()` / `inflate_nhscii()` call
  that spans 2023/24 now returns different numbers than 0.3.0. Coverage also
  now extends back to 2014/15 and forward to 2024/25 (#9, #6).
- **`dmd_price_lookup(method = "partial")` now matches literally, not as a
  regular expression.** Queries that previously relied on regex metacharacters
  (e.g. `"a|b"` as an alternation) will behave differently; plain-text queries
  are unaffected.
- **`dmd_price_lookup()` now also searches branded pack names (`ampp_name`).**
  The same query can return more rows than before (e.g. `"Buvidal"` now
  resolves to its packs). Generic-name queries return at least what they did
  previously.
- **Bundled `dmd_master` refreshed** from Week 34 2025 to Week 15 2026, so
  default price lookups reflect the newer release (different prices/availability)
  and the dataset gains an `is_combination` column.

## Data

- Bundled `dmd_master` and `dmd_ingredients` datasets updated to **dm+d Week 15
  2026 (06 April 2026)**, replacing the previous Week 34 2025 (14 August 2025)
  release.
- `dmd_load()` and `data-raw/dmd_master.R` updated to reflect renamed CSV files
  in this release: `f_vmp_VpiType.csv` (was `f_vmp_VirtualProductIngredientType.csv`),
  `f_ingredient.csv` (was `f_ingredient_IngredientType.csv`), and
  `f_lookup_UoMHistoryInfoType.csv` (was `f_lookup_UnitOfMeasureType.csv`, now
  4-column schema without `INVALID`).
- Bundled `dmd_master` now shows readable pack units for doses
  (inhalers/vaccines → `"dose"`), grams (`"g"`), and pre-filled syringes
  instead of raw SNOMED unit codes. The `dmd_master` documentation now also
  lists the `is_combination` column added with the ingredient data.

## Added

- **Combination-product handling (#8).** `dmd_parse_strength()` now detects
  multi-ingredient products (e.g. co-codamol `"8mg/500mg"`) and returns each
  ingredient's strength in a new `components` list-column with `is_combination`
  / `n_components` flags, instead of misreading the mass/mass strength as a
  concentration. This also covers combination inhalers and similar products
  written as `"X micrograms/dose / Name Y micrograms/dose"`.
- `dmd_load()` now reads the dm+d Virtual Product Ingredient (VPI) extract when
  present, exposing a `$ingredients` table of per-ingredient strengths and an
  `is_combination` flag on `$master`. A new bundled [dmd_ingredients] dataset
  documents the schema (empty until rebuilt from a release containing VPI).
- `dmd_dose_optimise()`, `dmd_dose_cost()`, and `dmd_dose_cost_range()` gain an
  `ingredient` argument: dose against a single named active ingredient, which
  lets combination products be optimised for one ingredient (e.g. the codeine
  content of co-codamol). Matching is case-insensitive and word-boundary based,
  so `"codeine"` does not also match `"dihydrocodeine"`; a warning is emitted
  when the term resolves to several distinct ingredients, or when a targeted
  ingredient is recorded in a non-mass unit (e.g. GBq, mmol) that cannot be
  dosed by mass. Without ingredient data, combination products continue to be
  skipped with a warning.

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
- `bslib`, `cachem`, and `lifecycle` added to `Imports`.

## Changed

- The dose optimiser Shiny app now shows a note below the results table
  explaining that "Dose delivered", "Over-delivery", and "Cost (pence)" are
  rounded for display only (2 d.p., 2 d.p., and 1 d.p. respectively), and that
  full-precision values are preserved in CSV/Excel exports and in the R object
  returned by `dmd_dose_optimise()`.
- All three Shiny apps now surface package warnings **and** errors to the user
  as Bootstrap alert callout boxes, rather than silently swallowing them or
  printing only to the console. For example, the dose optimiser shows
  `cli::cli_warn()` notices (compound products skipped, ambiguous ingredient,
  non-mass units) above the results, and invalid input shows the underlying
  error message. The dm+d price-lookup app footer now also reads Week 15 2026.
- `dmd_price_lookup()` now also searches the branded pack name (`ampp_name`),
  not just the generic `medicine` name, so a query for a brand (e.g.
  `"Buvidal"`) returns its packs while generic queries continue to work as
  before. Applies to all three methods (`partial`, `exact`, `fuzzy`).
- NHS CII rates updated to the PSSRU *Unit Costs of Health and Social Care 2025
  Manual*. Coverage now extends to 2024/25 (provisional), and the previously
  provisional 2023/24 figures have been revised to the values published in the
  2025 manual (#9).
- `nhscii()` and `inflate_nhscii()` now accept 2014/15 as a `from_year`, the
  first row of the NHSCII table (#6).

## Deprecated

- `objective = "both"` in `dmd_dose_optimise()` and `dmd_dose_cost()` is
  deprecated. Replace with `objective = c("cheapest", "min_items")`. A
  `lifecycle::deprecate_warn()` warning is emitted on first use.

## Fixed

- Dose-optimiser combination rows no longer conflate two AMPPs. In the
  splittable path, the cheapest *per-tablet* pack and the cheapest *whole*
  pack of a strength can differ; the row previously showed one pack's identity
  with another pack's `pack_price_pence` / `price_field_used` (e.g. a
  1000-tablet pack labelled with a 28-tablet pack's price). Each row now
  describes a single product consistently — `pack_price_pence`,
  `per_item_price_pence`, the whole-pack subtotal, and `price_field_used` all
  refer to the AMPP named in that row.
- Inhaler (and other per-dose) costing: the `"dose"` pack-unit code is now
  recognised, so a single inhaler is treated as its full actuation count
  (e.g. 200 doses) rather than one actuation priced as a whole pack. Previously
  a 20 mg salbutamol request returned 200 "items" at the whole-inhaler price;
  it now returns one inhaler.
- Cheapest dose optimisation now breaks cost ties by preferring the **lowest
  over-delivery**. Previously it could return an over-delivering combination
  (e.g. 2 × 32 mg = 64 mg for a 40 mg target) when an exact-dose combination of
  equal cost existed, because the tie-break inspected the fewest-items path
  rather than the cheapest path's over-delivery.
- Pack units now resolve via the dm+d unit-of-measure lookup as a fallback, so
  container codes not in the curated short-label table (e.g. the pre-filled
  syringe unit on depot injections like buprenorphine prolonged-release) show
  their proper label instead of a raw SNOMED code. Curated short labels
  (`"ml"`, `"tablet"`, …) still take precedence. Takes effect when the bundled
  data is rebuilt (`data-raw/dmd_master.R`) or a release is loaded with
  `dmd_load()`.
- `dmd_price_lookup(method = "partial")` now matches the query as a literal
  substring rather than a regular expression, so queries containing regex
  metacharacters (e.g. the `"[I-131]"` in radiopharmaceutical names) no longer
  error.
- `dmd_dose_cost(objective = "most_expensive")` now returns the worst-case cost
  (maximum across preparation groups) instead of silently returning the
  cheapest. Aggregation across multiple objectives uses each objective's
  natural extremum.
- `dmd_dose_optimise(objective = "most_expensive", can_split = FALSE)` now
  selects the dearest whole-pack combination rather than falling through to
  the cheapest branch. The notes column reads `"most-expensive-pack-per-dose"`
  on this path.
- `dmd_dose_optimise(objective = "most_expensive")` now follows a true
  max-cost DP path rather than selecting the highest of the cheapest paths.
- Concentration-based products now calculate the active quantity per container
  correctly when the pack quantity shares the concentration denominator unit
  (for example, `10mg/5ml` in a `100 ml` bottle).
- Unsupported compound products with multiple active strengths in one VMP name
  are skipped with a warning rather than optimised against an ambiguous dose.
- `print.dmd_dose_combination()` and the dose-optimiser Shiny app's
  combination formatter use `%g` instead of `%d` so fractional
  vial-sharing counts (e.g. `0.5`) render without a warning.
- The dose optimiser Shiny app now renders the selected-row combination detail
  table through a normal `DTOutput()` / `renderDT()` pair.
- `DT` moved back to `Imports` (from `Suggests`) so `run_dmd_price_lookup()`
  works on a fresh install without a separate `install.packages("DT")` step.
- `dmd_dose_optimise()` result columns are now in the same order as the empty
  scaffold returned when no candidates are found (`dose_cost_pence` was
  previously appended after `notes` rather than between `cost_whole_pack_pence`
  and `price_field_used`).
- `dmd_dose_cost()` now emits an informative error when `dose` is a character
  string, explaining the difference from `dmd_dose_optimise()`.
- Memoization cache is now capped at 1 GB via `cachem::cache_mem()` to prevent
  unbounded memory growth in long-running sessions.
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
- Vignette `dose_optimisation` documents whole-pack dispensing, vial sharing,
  vectorised costing, cost ranges, and compound-product skipping.
- The README and apps vignette now list all three Shiny apps as hosted and
  locally runnable, including the dose optimiser app.

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
