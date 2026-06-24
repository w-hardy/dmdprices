# Find dose combinations for a clinical dose

Given a dose (e.g. 900 mg), searches the dm+d for products matching
`query` and returns the cheapest, most expensive, and/or fewest-item
combination of AMPPs that delivers that dose.

## Usage

``` r
dmd_dose_optimise(
  query,
  dose,
  dose_unit = NULL,
  db = dmdprices::dmd_master,
  method = c("partial", "exact", "fuzzy"),
  max_dist = 3,
  price = c("basic_price", "nhs_indicative_price"),
  objective = c("cheapest", "min_items"),
  preparation = NULL,
  ingredient = NULL,
  active_only = TRUE,
  can_split = TRUE,
  can_split_vials = FALSE
)
```

## Arguments

- query:

  Character string passed through to
  [`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md).

- dose:

  Numeric dose value (in `dose_unit`), **or** a self-contained dose
  string such as `"250 mg"`, `"250mg"`, or `"0.25 g"`. When a string is
  supplied `dose_unit` may be omitted.

- dose_unit:

  One of `"mg"`, `"microgram"` / `"mcg"`, `"g"`, `"ml"`, `"unit"`.
  Default `"mg"`. Ignored (with a warning) if `dose` is a string that
  already contains a unit.

- db:

  A `<dmd_db>` object from
  [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
  or a tibble in the same shape as
  [dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md).
  Default: bundled
  [dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md).

- method, max_dist, active_only:

  Passed through to
  [`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md).

- price:

  Which price column to use — `"basic_price"` (default) or
  `"nhs_indicative_price"`. Falls back to the other column when the
  chosen one is NA for an individual AMPP (a note is added).

- objective:

  Character vector of one or more objectives: `"cheapest"`,
  `"min_items"`, `"most_expensive"`. Pass `"all"` as a shorthand for all
  three. Defaults to `c("cheapest", "min_items")`. Each objective
  produces one row per preparation group in the result.

- preparation:

  Optional character — a case-insensitive plain substring matched
  against `preparation_group` or `preparation_label` before returning
  results. An exact key (e.g. `\"tablet|none|oral\"`) continues to work,
  but partial strings such as `\"infusion\"` or `\"oral\"` are also
  accepted and will match any group whose key or label contains that
  text. Pipe characters in preparation keys are treated literally, not
  as regex alternation.

- ingredient:

  Optional character. Name of a single active ingredient to dose against
  (e.g. `"codeine"`). When supplied, candidates are restricted to
  products containing that ingredient and the dose is matched against
  the ingredient's own strength rather than the whole-product strength.
  This is what enables combination products such as co-codamol to be
  optimised for one ingredient. Matching is case-insensitive and
  **word-boundary** based, so `"codeine"` matches `"Codeine phosphate"`
  but not `"dihydrocodeine"`; ingredient names are matched as written in
  the dm+d (including salt forms). If the term still resolves to more
  than one distinct ingredient, all are used and a warning lists them.
  Ingredients recorded in non-mass units (e.g. radioactivity in GBq,
  electrolytes in mmol) cannot be converted to a mass dose; such
  candidates are skipped with a warning. Requires ingredient (VPI) data:
  a
  [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
  database that includes it, or a rebuilt bundled
  [dmd_ingredients](https://w-hardy.github.io/dmdprices/reference/dmd_ingredients.md).
  With no ingredient data, returns no results and warns.

- can_split:

  Logical. `TRUE` (default) assumes that individual items (tablets,
  capsules) can be taken from a part-pack, as is normal in hospital
  dispensing. `FALSE` requires whole packs to be dispensed, as is normal
  in community pharmacy. Concentration-based preparations (liquids,
  inhalers, vials) are treated as one container regardless of this
  setting unless `can_split_vials = TRUE`. When `can_split = FALSE`,
  reported costs are whole-pack costs rather than pro-rata costs, and a
  `"no-pack-splitting"` note is added.

- can_split_vials:

  Logical. If `TRUE`, concentration-based preparations (vials, ampoules)
  may be costed as a fraction of a container (vial sharing). Defaults to
  `FALSE`, which costs whole containers only.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per `(preparation_group, objective)` combination. See the package
vignette for the column layout. The `combination` column is a list of
tibbles — one row per AMPP picked, identifying the specific branded
product(s) used. `dose_cost_pence` is the cost (in pence) of supplying
the requested dose: pro-rata item cost when `can_split = TRUE`
(hospital), or whole-pack cost when `can_split = FALSE` (community). In
the `combination` tibble, `count` is the number of discrete dispensing
units: individual tablets/capsules/ containers when `can_split = TRUE`,
whole packs when `can_split = FALSE`, or a fractional container when
`can_split_vials = TRUE`.

## Details

Products are segregated into preparation groups automatically so that,
e.g., immediate-release and modified-release tablets are optimised
separately and never mixed within a single combination. For each group,
one row is returned per requested objective.

Unsupported compound products with multiple active strengths in one VMP
name are skipped with a warning rather than optimised against an
ambiguous dose.

## See also

[`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md),
[`dmd_parse_strength()`](https://w-hardy.github.io/dmdprices/reference/dmd_parse_strength.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Cheapest and minimum-item combinations for a 900 mg dose of metformin
dmd_dose_optimise("metformin", dose = 900, dose_unit = "mg")

# Equivalent: pass dose as a single string
dmd_dose_optimise("metformin", dose = "900 mg")
dmd_dose_optimise("metformin", dose = "0.9 g")   # same dose, different unit

# Only modified-release tablets
dmd_dose_optimise(
  "metformin", dose = 1500, dose_unit = "mg",
  preparation = "tablet|modified-release|oral"
)

# Community pharmacy — whole packs must be dispensed
dmd_dose_optimise("metformin", dose = "1500 mg", can_split = FALSE)
} # }
```
