# Look up medicine prices from a dm+d database

Searches a dm+d pricing table for medicines whose names match `query`.
Returns a tibble in the same column format as the NHS Drug Tariff Part
VIIIA CSV, with Drug Tariff and NHS Indicative Price columns appended.

## Usage

``` r
dmd_price_lookup(
  query,
  db = dmdprices::dmd_master,
  method = c("partial", "exact", "fuzzy"),
  max_dist = 3,
  active_only = TRUE
)
```

## Arguments

- query:

  A character string to search for in medicine names.

- db:

  A `<dmd_db>` object from
  [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md),
  or a tibble with the same columns as
  [dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md).
  Defaults to the bundled
  [dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md)
  dataset.

- method:

  One of:

  - `"partial"` *(default)* — case-insensitive substring match using a
    regular expression. Suitable for general searching, e.g.
    `"metformin"`.

  - `"exact"` — case-insensitive exact match against the full VMP name.

  - `"fuzzy"` — approximate string matching (optimal string alignment
    distance via
    [`stringdist::stringdist()`](https://rdrr.io/pkg/stringdist/man/stringdist.html)).
    Tolerates typos. Tune sensitivity with `max_dist`.

- max_dist:

  Maximum edit distance for `method = "fuzzy"` (default `3`). Increase
  for looser matching; decrease for stricter matching.

- active_only:

  If `TRUE` (default), rows where both `basic_price` and
  `nhs_indicative_price` are `NA` are dropped.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with the
following columns:

|                        |                                    |
|------------------------|------------------------------------|
| Column                 | Description                        |
| `medicine`             | VMP (generic) name                 |
| `pack_size`            | Pack quantity                      |
| `unit`                 | Unit of measure (tablet, ml, etc.) |
| `vmp_snomed_code`      | VMP SNOMED CT identifier           |
| `vmpp_snomed_code`     | VMPP SNOMED CT identifier          |
| `drug_tariff_category` | e.g. "Part VIIIA Category M"       |
| `basic_price`          | Drug Tariff basic price (pence)    |
| `nhs_indicative_price` | NHS Indicative Price (pence)       |
| `price_basis`          | Basis of NHS Indicative Price      |
| `price_date`           | Date of NHS Indicative Price       |
| `ampp_name`            | Branded pack name                  |
| `ampp_snomed_code`     | AMPP SNOMED CT identifier          |

## Details

By default, the bundled
[dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md)
dataset (Week 34 2025, 14 August 2025) is used, so no setup is needed.
Supply `db` to use a more recent release loaded with
[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md).

## Examples

``` r
# Uses bundled data — no setup required
dmd_price_lookup("metformin")
#> # A tibble: 271 × 12
#>    medicine                     pack_size unit  vmp_snomed_code vmpp_snomed_code
#>    <chr>                            <dbl> <chr> <chr>           <chr>           
#>  1 Alogliptin 12.5mg / Metform…        56 tabl… 23637211000001… 236325110000011…
#>  2 Alogliptin 12.5mg / Metform…        56 tabl… 23637211000001… 236325110000011…
#>  3 Alogliptin 12.5mg / Metform…        56 tabl… 23637211000001… 236325110000011…
#>  4 Canagliflozin 50mg / Metfor…        60 tabl… 28049211000001… 280241110000011…
#>  5 Canagliflozin 50mg / Metfor…        60 tabl… 28049311000001… 280222110000011…
#>  6 Dapagliflozin 5mg / Metform…        56 tabl… 24054611000001… 240184110000011…
#>  7 Dapagliflozin 5mg / Metform…        56 tabl… 24054611000001… 240184110000011…
#>  8 Dapagliflozin 5mg / Metform…        56 tabl… 24054711000001… 240180110000011…
#>  9 Empagliflozin 12.5mg / Metf…        56 tabl… 30318111000001… 301756110000011…
#> 10 Empagliflozin 12.5mg / Metf…        60 tabl… 30318111000001… 378531110000011…
#> # ℹ 261 more rows
#> # ℹ 7 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>

dmd_price_lookup("Metformin 500mg tablets", method = "exact")
#> # A tibble: 49 × 12
#>    medicine                pack_size unit   vmp_snomed_code   vmpp_snomed_code
#>    <chr>                       <dbl> <chr>  <chr>             <chr>           
#>  1 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  2 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  3 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  4 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  5 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  6 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  7 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  8 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  9 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#> 10 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#> # ℹ 39 more rows
#> # ℹ 7 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>

dmd_price_lookup("metfromin 500mg tablets", method = "fuzzy", max_dist = 4)
#> # A tibble: 82 × 12
#>    medicine                pack_size unit   vmp_snomed_code   vmpp_snomed_code
#>    <chr>                       <dbl> <chr>  <chr>             <chr>           
#>  1 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  2 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  3 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  4 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  5 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  6 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  7 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  8 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  9 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#> 10 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#> # ℹ 72 more rows
#> # ℹ 7 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>

# Include rows without any price
dmd_price_lookup("metformin", active_only = FALSE)
#> # A tibble: 287 × 12
#>    medicine                     pack_size unit  vmp_snomed_code vmpp_snomed_code
#>    <chr>                            <dbl> <chr> <chr>           <chr>           
#>  1 Alogliptin 12.5mg / Metform…        56 tabl… 23637211000001… 236325110000011…
#>  2 Alogliptin 12.5mg / Metform…        56 tabl… 23637211000001… 236325110000011…
#>  3 Alogliptin 12.5mg / Metform…        56 tabl… 23637211000001… 236325110000011…
#>  4 Canagliflozin 50mg / Metfor…        60 tabl… 28049211000001… 280241110000011…
#>  5 Canagliflozin 50mg / Metfor…        60 tabl… 28049311000001… 280222110000011…
#>  6 Dapagliflozin 5mg / Metform…        56 tabl… 24054611000001… 240184110000011…
#>  7 Dapagliflozin 5mg / Metform…        56 tabl… 24054611000001… 240184110000011…
#>  8 Dapagliflozin 5mg / Metform…        56 tabl… 24054711000001… 240180110000011…
#>  9 Empagliflozin 12.5mg / Metf…        56 tabl… 30318111000001… 301756110000011…
#> 10 Empagliflozin 12.5mg / Metf…        60 tabl… 30318111000001… 378531110000011…
#> # ℹ 277 more rows
#> # ℹ 7 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>

if (FALSE) { # \dontrun{
# Use a locally loaded, more recent release
db <- dmd_load("~/dmdDataLoader")
dmd_price_lookup("metformin", db = db)
} # }
```
