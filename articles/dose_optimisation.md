# Dose optimisation

## Overview

[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md)
takes a clinical dose (e.g. 900 mg) and returns the best combination of
AMPPs (branded packs) from the dm+d that deliver it. “Best” is
controlled by the `objective` argument, which accepts one or more of:

- **cheapest** — lowest pro-rata cost across priced combinations.
- **min_items** — fewest tablets, capsules, ampoules, or other discrete
  items.
- **most_expensive** — highest-cost combination (useful for worst-case
  cost modelling or budget-impact analysis upper bounds).

Pass a character vector to request multiple objectives at once, or use
`objective = "all"` as a shorthand for all three. The default is
`c("cheapest", "min_items")`.

Preparations are segregated automatically: immediate-release tablets,
modified-release tablets, oral solutions, and solutions for injection
each get their own row so they are never mixed in a single combination.
Compound products with multiple active strengths in one VMP name are
skipped with a warning because the dose target would be ambiguous.

## A basic example

A 1,500 mg dose of metformin, restricted to standard (immediate-release)
tablets (default objectives: cheapest + min_items):

``` r

res <- dmd_dose_optimise(
  "metformin",
  dose = 1500,
  dose_unit = "mg",
  preparation = "tablet|none|oral"
)
res
```

Each row contains a `combination` list-column identifying the specific
branded products picked:

``` r

res$combination[[1]]
```

The combination tibble has one row per AMPP used, with the VMP name,
branded pack name, SNOMED codes, and the count / packs-to-buy / pro-rata
/ whole-pack cost breakdown.

## When objectives differ

A 900 mg metformin dose is a good illustration. The cheapest combination
may use more items (several smaller tablets) while the minimum-items
answer may over-deliver (e.g. two 500 mg tablets → 1,000 mg). The output
flags `over_delivery` in both the column and the notes:

``` r

res <- dmd_dose_optimise("metformin", dose = 900, dose_unit = "mg",
                         preparation = "tablet|none|oral")
res[, c("objective", "total_items", "dose_delivered",
        "over_delivery", "cost_prorata_pence", "cost_whole_pack_pence")]
```

## Segregating preparations

A morphine dose should never mix oral solutions with tablets or
injections, so
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md)
returns one result per preparation group:

``` r

dmd_dose_optimise("morphine", dose = 20, dose_unit = "mg")[,
  c("preparation_label", "objective", "total_items",
    "dose_delivered", "over_delivery")]
```

## Micrograms

Small doses in micrograms are handled transparently. The requested dose
unit is retained in the output while the canonical form is used
internally:

``` r

dmd_dose_optimise("levothyroxine", dose = 125, dose_unit = "microgram")
```

## Pricing

By default, pro-rata costs (`pack_price × items ÷ pack_size`) are
computed from `basic_price`, with fallback to `nhs_indicative_price`
per-AMPP when the chosen column is NA (flagged in `notes`). Whole-pack
costs (`pack_price × packs_to_buy`) reflect what you would actually pay
when you cannot split a pack.

Switch the primary price field with `price = "nhs_indicative_price"`.

## Community pharmacy: whole-pack dispensing

In hospital dispensing, individual tablets can be taken from a part-pack
(`can_split = TRUE`, the default). In community pharmacy, whole packs
must be dispensed. Set `can_split = FALSE` to switch to pack-level
optimisation:

``` r

dmd_dose_optimise("metformin", dose = "1500 mg", can_split = FALSE)
```

When `can_split = FALSE`:

- The DP operates on whole packs rather than individual tablets.
- `dose_cost_pence` reflects the whole-pack cost (what the pharmacy
  actually pays), not a pro-rata fraction.
- The `notes` column includes `"no-pack-splitting"`.
- In the `combination` tibble, `count` is the number of **packs**
  dispensed rather than individual tablets.

Concentration-based preparations (liquids, vials, inhalers) are treated
as one container regardless of `can_split`, since one bottle, vial, or
ampoule is the minimum dispensing unit. For liquids where the pack
quantity is in the same unit as the concentration denominator (for
example `10 mg/5 ml` in a `100 ml` bottle), the optimiser uses the total
pack volume to calculate the active quantity in the container.

## Worst-case cost

`objective = "most_expensive"` selects the highest-cost combination of
AMPPs that delivers the dose. This is useful for budget-impact analysis
or scenario modelling where you want an upper bound on expenditure:

``` r

dmd_dose_optimise(
  "metformin",
  dose = 1000,
  dose_unit = "mg",
  preparation = "tablet|none|oral",
  objective = "most_expensive"
)
```

Request multiple objectives at once by passing a vector, or use `"all"`
as a shorthand for all three:

``` r

# Three rows: cheapest, min_items, and most_expensive
dmd_dose_optimise(
  "metformin",
  dose = 1000,
  dose_unit = "mg",
  preparation = "tablet|none|oral",
  objective = "all"
)
```

## Vial sharing

By default, concentration-based preparations (vials, ampoules) are
costed as whole containers — even when the dose is a fraction of the
container volume. Set `can_split_vials = TRUE` to enable **vial
sharing**, where the cost is pro-rated to the exact fraction of the
container needed:

``` r

# 250 mg from a 500 mg/50 ml vial — costs half a vial, not a whole one
dmd_dose_optimise(
  "rituximab",
  dose = 250,
  dose_unit = "mg",
  preparation = "infusion",
  can_split_vials = TRUE
)
```

When vial sharing is active:

- The `count` in the `combination` tibble is the non-integer fraction of
  the container used (e.g. `0.5` for half a vial).
- `"vial-sharing"` is added to the `notes` column.
- The reported cost is ≤ the whole-container cost for the same dose.

This mode is appropriate when a single vial is shared between multiple
patients on the same day, as is common in day-case oncology units.

## Vectorised costing with `dmd_dose_cost()`

For costing a column of doses inside a data frame,
[`dmd_dose_cost()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_cost.md)
is more efficient than calling
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md)
inside
[`purrr::map_dbl()`](https://purrr.tidyverse.org/reference/map.html). It
accepts a numeric vector of doses and returns a numeric vector of costs
in pence of the same length:

``` r

library(dplyr)

treatment_df |>
  mutate(
    ritux_cost_gbp = dmd_dose_cost(
      query       = "rituximab",
      dose        = dose_mg,
      dose_unit   = "mg",
      objective   = "cheapest",
      preparation = "infusion"
    ) / 100
  )
```

Key differences from
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md):

- `dose` must be a **numeric vector** (string doses are not accepted).
- Returns a plain `numeric` vector, not a tibble — no `combination`
  detail.
- The expensive candidate-preparation step runs **once** for all doses
  in the vector (memoized across calls within the same session).
- When multiple preparation groups match, the **minimum cost** across
  groups is returned. Specify `preparation` to restrict to a single
  route.
- `NA`, zero, or negative dose elements return `NA` (or a custom
  `na_value`).

Use
[`dmd_dose_cost_range()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_cost_range.md)
when you need both lower and upper cost bounds:

``` r

dmd_dose_cost_range(
  "rituximab",
  dose = c(375, 500, 700),
  dose_unit = "mg",
  preparation = "infusion"
)
```

## Cross-referencing with other dm+d data

The `combination` list-column includes `vmpp_snomed_code` and
`ampp_snomed_code` for each picked product, so you can join back to
other dm+d views or NHS Drug Tariff Part VIIIA CSVs.

## Limitations

- Discrete items only — tablet splitting is not considered.
- For liquids, each “item” is one container (bottle, ampoule, vial)
  unless `can_split_vials = TRUE`. A small dose requested against a
  large container is delivered as one whole container with an
  `over_delivery` flag.
- Compound products (multiple active ingredients in one VMP) are skipped
  with a warning and are not returned as optimiser rows.
- Clinical safety (max single / max daily dose) is **not** enforced.
