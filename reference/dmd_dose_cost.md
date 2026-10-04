# Vectorised dose cost lookup

A lightweight, vectorised alternative to
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md)
designed for costing large tables. Accepts a numeric vector of doses and
returns a numeric vector of costs in pence of the same length.

## Usage

``` r
dmd_dose_cost(
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
  quiet = FALSE,
  na_value = NA_real_
)
```

## Arguments

- query, dose_unit, db, method, max_dist, price, preparation,
  ingredient, active_only, can_split:

  As in
  [`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md).

- dose:

  A **numeric vector** of dose values in `dose_unit`. `NA`, zero, or
  negative elements are returned as `na_value` without error.

- objective:

  Character vector of one or more of `"cheapest"`, `"min_items"`,
  `"most_expensive"`, or `"all"`. The cost returned per dose element is
  aggregated across preparation groups using each objective's natural
  extremum (minimum for `"cheapest"` / `"min_items"`; maximum for
  `"most_expensive"`). When multiple objectives are supplied, the
  **minimum** of the per-objective aggregates is returned — i.e. the
  default `c("cheapest", "min_items")` returns the cheapest achievable
  cost, while `"most_expensive"` alone returns the worst-case cost
  across groups.

- can_split_vials:

  As in
  [`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md).
  If `TRUE`, vials and ampoules are costed as a fraction of a container
  (vial sharing).

- over_delivery:

  As in
  [`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md).
  Defaults to `"forbid"`, so doses that no combination delivers exactly
  return `na_value` (with one warning per call) rather than the cost of
  an over-delivered dose. The requested dose is never rounded to the
  strengths, and no cost is for less than the dose. Whole containers
  (`can_split_vials = FALSE`) and whole packs (`can_split = FALSE`) are
  exempt from the policy: they are costed as the cheapest container or
  pack covering the dose, without a warning. Pass `"minimise"` or
  `"allow"` to cost over-delivering combinations.

- quiet:

  As in
  [`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md).
  Because this function returns bare numbers, the warnings are the only
  signal that a cost is for an over-delivered dose in the groups the
  over-delivery policy governs (whole-container and whole-pack groups
  are not warned about); `TRUE` silences them for bulk costing runs.

- na_value:

  Scalar returned for doses that are `NA`, non-positive, or for which no
  solution is found. Default `NA_real_`.

## Value

A `numeric` vector of length `length(dose)` giving the dose cost in
pence. Use `/ 100` for GBP. `NA` (or `na_value`) where no solution
exists.

## Details

Unlike
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md),
this function:

- Calls the memoized candidate preparation step **once** regardless of
  how many doses are supplied.

- Applies unit-matching and `preparation` filters **once**.

- Runs only the DP optimisation per dose element, skipping the full
  result-assembly (combination tibble, notes, etc.).

- Returns a plain `numeric` vector — not a tibble — suitable for use
  directly inside
  [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html).

When multiple preparation groups match (e.g. no `preparation` filter is
supplied), the **minimum cost across all groups** is returned for each
dose.

## See also

[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md)
for the full result tibble with combination details.

## Examples

``` r
if (FALSE) { # \dontrun{
# Vectorised costing inside a mutate — no map_dbl needed
library(dplyr)
treatment_df |>
  mutate(
    ritux_gbp = dmd_dose_cost(
      query       = "rituximab",
      dose        = day1_ritux_mg,
      dose_unit   = "mg",
      objective   = "cheapest",
      preparation = "infusion"
    ) / 100
  )
} # }
```
