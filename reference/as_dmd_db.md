# Build a dm+d database from an in-memory table

Turn a data frame of medicine prices into a `<dmd_db>` object that the
`dmdprices` functions
([`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md),
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md),
[`dmd_dose_cost()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_cost.md),
[`dmd_master_info()`](https://w-hardy.github.io/dmdprices/reference/dmd_master_info.md))
accept via their `db` argument.

This is the supported entry point for **external** Drug-Tariff-shaped
data (for example the `drug_tariff_viii_a` table from the NICE `COSTmos`
package). Rename your columns to the `dmdprices` schema first — the same
columns the bundled
[dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md)
carries and that
[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
produces — then pass the frame here. Missing optional columns are filled
with `NA` and column types are coerced; a message reports any resulting
loss of functionality.

## Usage

``` r
as_dmd_db(master, ingredients = NULL, loaded_at = Sys.time())
```

## Arguments

- master:

  A data frame with, at minimum, a `medicine` column and one of
  `basic_price` / `nhs_indicative_price` (in pence). Columns already
  matching the `dmdprices` schema are used as-is; missing canonical
  columns are filled.

- ingredients:

  Optional. `NULL` (default), or a data frame of per-ingredient
  strengths in the
  [dmd_ingredients](https://w-hardy.github.io/dmdprices/reference/dmd_ingredients.md)
  shape, enabling ingredient-targeted dose optimisation. It must carry
  `vmp_snomed_code`, `ingredient_name` and the raw dm+d strength fields
  `strength_value`, `strength_unit`, `denominator_value` and
  `denominator_unit`; the canonical columns are not read.

- loaded_at:

  A length-1 `POSIXct` timestamp recording when the data was assembled,
  shown by [`print()`](https://rdrr.io/r/base/print.html) and
  [`dmd_master_info()`](https://w-hardy.github.io/dmdprices/reference/dmd_master_info.md).
  Defaults to [`Sys.time()`](https://rdrr.io/r/base/Sys.time.html). It
  is descriptive only: results and caching depend on the content of
  `$master`, never on this value.

## Value

A `<dmd_db>` object: a list with `$master` (a
[tibble](https://tibble.tidyverse.org/reference/tibble.html) in the
canonical schema), `$ingredients` (the supplied table or `NULL`), and
`$loaded_at` (the timestamp).

## Details

The required column is `medicine`, plus at least one price column
(`basic_price` or `nhs_indicative_price`, both in **pence**). All other
canonical columns — `pack_size`, `unit`, `vmp_snomed_code`,
`vmpp_snomed_code`, `drug_tariff_category`, `price_basis`, `price_date`,
`ampp_name`, `ampp_snomed_code` — are filled with `NA` when absent. See
[dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md)
for the full column contract.

Features degrade predictably when columns are missing: without
`ampp_name`, brand-name search is disabled
([`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md)
matches the generic name only); without `ampp_snomed_code`, pack
identifiers are `NA` and
[`dmd_master_info()`](https://w-hardy.github.io/dmdprices/reference/dmd_master_info.md)
reports 0 AMPPs; without `pack_size`/`unit`, dose optimisation is
unavailable or degraded.

Unlike
[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md),
prices are trusted as given — a `0` price stays `0` (it is not treated
as missing).

`loaded_at` is descriptive: it is shown by
[`print()`](https://rdrr.io/r/base/print.html) and
[`dmd_master_info()`](https://w-hardy.github.io/dmdprices/reference/dmd_master_info.md)
and changes no result, so any timestamp is safe, including one shared by
several databases.
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md),
[`dmd_dose_cost()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_cost.md)
and
[`dmd_dose_cost_range()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_cost_range.md)
cache their candidate search for the session by the *content* of
`$master`, so a database whose `$master` holds different rows or prices,
including one edited in place (for example
`db$master$basic_price <- new_prices`), is not served another table's
cached results. The exception is an edit made by reference from compiled
code to a table that is not a data.table, such as `data.table::set()` on
a data frame (see the `db` argument of
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md)).

## See also

[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
to read a full dm+d release from disk;
[`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md),
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md).

## Examples

``` r
# A minimal Drug-Tariff-shaped table (prices in pence).
df <- data.frame(
  medicine = c("Metformin 500mg tablets", "Metformin 1000mg tablets"),
  pack_size = c(28, 28),
  unit = "tablet",
  basic_price = c(58L, 180L),
  nhs_indicative_price = c(63L, 190L)
)
# ampp_name / ampp_snomed_code are absent, so as_dmd_db() warns that
# brand search and pack identifiers are unavailable.
db <- as_dmd_db(df)
#> Warning: Built a <dmd_db> with reduced functionality:
#> • No ampp_name: brand-name search is disabled (`dmd_price_lookup()` matches the
#>   generic name only).
#> • No ampp_snomed_code: pack identifiers are `NA` (`dmd_master_info()` reports 0
#>   AMPPs).
dmd_price_lookup("metformin", db = db)
#> # A tibble: 2 × 12
#>   medicine pack_size unit  vmp_snomed_code vmpp_snomed_code drug_tariff_category
#>   <chr>        <dbl> <chr> <chr>           <chr>            <chr>               
#> 1 Metform…        28 tabl… NA              NA               NA                  
#> 2 Metform…        28 tabl… NA              NA               NA                  
#> # ℹ 6 more variables: basic_price <int>, nhs_indicative_price <int>,
#> #   price_basis <chr>, price_date <chr>, ampp_name <chr>,
#> #   ampp_snomed_code <chr>

if (FALSE) { # \dontrun{
# Interoperate with NICE COSTmos Drug Tariff Part VIIIA data.
# COSTmos is not on CRAN; install it separately.
library(dplyr)
db <- COSTmos::drug_tariff_viii_a |>
  rename(unit = unit_of_measure, basic_price = basic_price_in_p) |>
  as_dmd_db()
dmd_dose_optimise("metformin", dose = "1500 mg", db = db)
} # }
```
