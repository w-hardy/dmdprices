# Vectorised dose cost range lookup

Returns the **cheapest** and **most expensive** achievable cost for each
dose in a single call. A purpose-built alternative to calling
[`dmd_dose_cost()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_cost.md)
twice with different `objective` values, with clearer naming for
health-economics range analyses.

## Usage

``` r
dmd_dose_cost_range(
  query,
  dose,
  dose_unit = NULL,
  db = dmdprices::dmd_master,
  method = c("partial", "exact", "fuzzy"),
  max_dist = 3,
  price = c("basic_price", "nhs_indicative_price"),
  preparation = NULL,
  ingredient = NULL,
  active_only = TRUE,
  can_split = TRUE,
  can_split_vials = FALSE,
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
  negative elements yield `na_value` in both output columns.

- can_split_vials:

  As in
  [`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md).
  If `TRUE`, vials and ampoules are costed as a fraction of a container
  (vial sharing).

- na_value:

  Scalar returned for doses that are `NA`, non-positive, or for which no
  solution is found. Default `NA_real_`.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with
`length(dose)` rows and two columns:

- `lo_pence`:

  Cheapest achievable dose cost in pence. Divide by 100 for GBP.

- `hi_pence`:

  Most expensive achievable dose cost in pence. Divide by 100 for GBP.

Both columns are `na_value` when no solution is found.

## Details

The candidate preparation step is memoized, so even though this function
runs the DP twice internally (once per bound), the expensive
price-lookup and parsing work is only performed once per
`(query, db, ...)` combination within a session.

## See also

[`dmd_dose_cost()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_cost.md)
for a single-objective numeric vector,
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md)
for the full combination tibble with product detail.

## Examples

``` r
if (FALSE) { # \dontrun{
# Cost range for rituximab doses — divide by 100 for GBP
library(dplyr)
doses_mg <- c(375, 500, 700)
dmd_dose_cost_range(
  query       = "rituximab",
  dose        = doses_mg,
  dose_unit   = "mg",
  preparation = "infusion"
) / 100

# Use inside mutate() to add lo/hi cost columns to a treatment table
treatment_df |>
  dplyr::bind_cols(
    dmd_dose_cost_range("rituximab", dose = treatment_df$dose_mg) / 100
  )
} # }
```
