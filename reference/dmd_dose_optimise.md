# Find dose combinations for a clinical dose

Given a dose (e.g. 1000 mg), searches the dm+d for products matching
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
  can_split_vials = FALSE,
  over_delivery = c("forbid", "minimise", "allow"),
  quiet = FALSE
)
```

## Arguments

- query:

  Character string passed through to
  [`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md).

- dose:

  Numeric dose value (in `dose_unit`), **or** a self-contained dose
  string such as `"250 mg"`, `"250mg"`, or `"0.25 g"`. Comma thousands
  separators are accepted (`"100,000 units"`). When a string is supplied
  `dose_unit` may be omitted.

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
  Candidate searches are cached for the session by the content of this
  table, so editing it between calls with ordinary R code is safe (for
  example `db$basic_price <- new_prices`, or
  `db$master$basic_price <- new_prices` for a `<dmd_db>`). An edit made
  in place by reference to a table that is not a data.table (for example
  with `data.table::set()`) is not detected.

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
  electrolytes in mmol), or per a quantity with no canonical form (per
  hour, per square centimetre), cannot be converted to a mass dose; such
  candidates are skipped with a warning. The ingredient's strength is
  applied to the same item the product's own strength would be: the
  whole pack for a single bottle or tube, and for a pack of containers
  the size the name states for one container, as a bare size ("500ml
  bags", "0.25g unit dose", "3ml pre-filled pens") or as a numeric
  strength denominator ("500mg/50ml" vials hold 50 ml). A container
  whose size the name does not state is skipped with a warning rather
  than taken to hold one denominator unit (see
  [`vignette("dose_optimisation")`](https://w-hardy.github.io/dmdprices/articles/dose_optimisation.md)).
  The ingredient table must carry the raw dm+d strength fields
  (`strength_value`, `strength_unit`, `denominator_value`,
  `denominator_unit`); its canonical columns are not read. Requires
  ingredient (VPI) data: the bundled
  [dmd_ingredients](https://w-hardy.github.io/dmdprices/reference/dmd_ingredients.md)
  (used when `db` is not a `<dmd_db>`, including the default), the
  `$ingredients` table of a
  [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
  database built with `f_vmp_VpiType.csv`, or the `ingredients` argument
  of
  [`as_dmd_db()`](https://w-hardy.github.io/dmdprices/reference/as_dmd_db.md).
  With no ingredient data, returns no results and warns.

- can_split:

  Logical. `TRUE` (default) assumes that individual items (tablets,
  capsules) can be taken from a part-pack, as is normal in hospital
  dispensing. `FALSE` requires whole packs to be dispensed, as is normal
  in community pharmacy. With `can_split = TRUE` a concentration-based
  preparation (liquid, inhaler, vial) is still costed in whole
  containers unless `can_split_vials = TRUE`; a pack of several
  containers (pre-filled syringes, ampoules, vials) is priced per
  container, and its whole-pack cost buys as many packs as the
  containers need. When `can_split = FALSE`, every preparation is
  optimised over whole packs — a pack of several containers is dispensed
  as whole packs and `total_items` counts packs — so `"cheapest"` is the
  cheapest set of whole packs covering the dose; reported costs are
  whole-pack costs rather than pro-rata costs, and a
  `"no-pack-splitting"` note is added. `can_split_vials = TRUE` takes
  precedence for concentration preparations under either setting.

- can_split_vials:

  Logical. If `TRUE`, concentration-based preparations (vials, ampoules)
  may be costed as a fraction of a container (vial sharing). Defaults to
  `FALSE`, which costs whole containers only.

- over_delivery:

  How much more than the requested dose a combination may deliver:

  `"forbid"`

  :   (default) only combinations that deliver the dose exactly. A
      preparation group that cannot hit the dose exactly returns no row,
      and a warning names it.

  `"minimise"`

  :   the smallest achievable over-delivery, with the requested
      `objective` applied within it.

  `"allow"`

  :   the objective decides across every combination that delivers *at
      least* the dose; over-delivery is only a tie-break. This was the
      behaviour before version 0.6.0.

  The policy applies where one "item" is an individually administered
  dose — the splittable solid forms — because there over-delivery is
  extra drug given to the patient. Whole-pack dispensing
  (`can_split = FALSE`) and whole-container preparations (vials and
  ampoules with `can_split_vials = FALSE`) are **exempt**: their surplus
  is wastage in the pack or the vial, so the cheapest pack/container
  covering the dose remains the costing answer and an
  `"over-delivery-policy-not-applied"` note is added. Exact delivery
  from a container is available via `can_split_vials = TRUE`.

  The requested dose is never rounded to the strengths. A dose that no
  combination of the group's strengths sums to (2.4 mg against 1 mg
  tablets) has no exact combination: `"forbid"` returns no row for the
  group, and `"minimise"` and `"allow"` return the smallest combination
  that delivers at least the dose (3 mg), with `dose_exact = FALSE` and
  `over_delivery` showing the surplus. No policy returns less than the
  requested dose. Exactness is judged to one part in a billion of the
  dose (never finer than a billionth of a milligram or millilitre), so a
  dose that is exact in the strengths' unit, such as 0.3 mg from three
  0.1 mg tablets, counts as exact.

- quiet:

  Logical. `FALSE` (default) warns, once per call, when a preparation
  group cannot deliver the dose exactly (and is therefore dropped under
  `over_delivery = "forbid"`), when a returned combination delivers more
  than the requested dose — saying whether an exact combination existed
  — and when a group could not be solved for the dose at all (its
  strengths cannot be represented at the precision the dose table allows
  for this dose, or the dose table would exceed its cell cap) and so
  returns no row. `TRUE` silences all three. Unrelated warnings
  (unsupported compounds, multi-product packs, unknown dose counts or
  container amounts, ingredient matching) are not affected.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per `(preparation_group, objective)` combination. See the package
vignette for the column layout. `dose_exact` is `TRUE` when the
combination delivers the requested dose exactly. The `combination`
column is a list of tibbles — one row per AMPP picked, identifying the
specific branded product(s) used. `dose_cost_pence` is the cost (in
pence) of supplying the requested dose: pro-rata item cost when
`can_split = TRUE` (hospital), or whole-pack cost when
`can_split = FALSE` (community). In the `combination` tibble, `count` is
the number of discrete dispensing units: individual tablets/capsules/
containers when `can_split = TRUE`, whole packs when
`can_split = FALSE`, or a fractional container when
`can_split_vials = TRUE`.

## Details

Products are segregated into preparation groups automatically so that,
e.g., immediate-release and modified-release tablets are optimised
separately and never mixed within a single combination. For each group,
one row is returned per requested objective.

Combination (multi-ingredient) products are skipped with a warning
rather than optimised against an ambiguous dose. A product counts as a
combination when the dm+d `is_combination` flag says so (authoritative,
covering e.g. allergen mixes and factor concentrates whose names show a
single number) or when its name lists multiple active strengths. A
bracketed strength that only restates the product's strength in another
unit dimension (eptacog alfa "1mg (50,000unit)") is the same dose and
does not count; one in the same dimension, or one naming another
substance ("Iohexol 755mg/ml (Iodine 350mg/ml)"), still does. Supply
`ingredient` to dose a combination product against one named active
ingredient instead. Packs holding several products whose name gives a
mass or unit strength for each one — titration packs ("Danicopan 50mg
tablets and Danicopan 100mg tablets") and co-packs of different products
— have no single per-item strength either; they are skipped with a
separate "multi-product pack" warning, and their products should be
costed individually. A pack that states a product's strength only as a
percentage ("Fluconazole 150mg capsule and Clotrimazole 2% cream") is
not recognised and is costed as its first product. A pack whose name
gives no strength ("Generic Otezla tablets treatment initiation pack")
is dropped like any other product without a parsed strength, with no
warning naming it.

## See also

[`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md),
[`dmd_parse_strength()`](https://w-hardy.github.io/dmdprices/reference/dmd_parse_strength.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Cheapest and minimum-item combinations of immediate-release metformin
# tablets for a 1000 mg dose
dmd_dose_optimise(
  "metformin", dose = 1000, dose_unit = "mg",
  preparation = "tablet|none|oral"
)

# Equivalent: pass dose as a single string, in any supported unit
dmd_dose_optimise("metformin", dose = "1000 mg", preparation = "tablet|none|oral")
dmd_dose_optimise("metformin", dose = "1 g", preparation = "tablet|none|oral")

# Only modified-release tablets
dmd_dose_optimise(
  "metformin", dose = 1500, dose_unit = "mg",
  preparation = "tablet|modified-release|oral"
)

# Community pharmacy — whole packs must be dispensed
dmd_dose_optimise("metformin", dose = "1500 mg", can_split = FALSE)

# Allow over-delivery when no exact combination exists
dmd_dose_optimise("metformin", dose = "750 mg", over_delivery = "minimise")
} # }
```
