# Getting started with dmdprices

## Overview

`dmdprices` provides price lookups against the NHS Dictionary of
Medicines and Devices (dm+d). A bundled dataset (Week 34 2025) is
included so no setup is needed for immediate use.

There are two main functions:

| Function                                                                                  | Purpose                                                |
|-------------------------------------------------------------------------------------------|--------------------------------------------------------|
| [`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md) | Search for medicines by name and return pricing        |
| [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)                 | Load a more recent dm+d release from a local directory |

------------------------------------------------------------------------

## Using the bundled data

### Partial match (default)

Returns all rows where the medicine name contains the query string
(case-insensitive):

``` r
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
```

### Exact match

Case-insensitive match against the full VMP name:

``` r
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
```

### Fuzzy match

Tolerates typos using optimal string alignment distance. Tune
sensitivity with `max_dist` (default `3`):

``` r
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
```

### Including products without prices

By default, rows where both `basic_price` and `nhs_indicative_price` are
`NA` are dropped. Set `active_only = FALSE` to keep them:

``` r
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
```

### Checking the bundled release

``` r
attr(dmd_master, "dmd_release_label")
#> [1] "Week 34 2025 (14 August 2025)"
```

------------------------------------------------------------------------

## Using a more recent release

If you have the NHSBSA dm+d extract tool (`dmdDataLoader`), load a newer
release with
[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
and pass the result to
[`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md):

``` r
db <- dmd_load("path/to/dmdDataLoader")
dmd_price_lookup("metformin", db = db)
```

You can set a project-wide default path in your `.Rprofile` to avoid
repeating it each session:

``` r
options(dmdprices.path = "~/dmdDataLoader")
# Then simply:
db <- dmd_load()
```

------------------------------------------------------------------------

## Output columns

Prices are in **pence**, matching the NHS Drug Tariff Part VIIIA CSV
convention. One row is returned per branded pack (AMPP).

| Column                 | Description                        |
|------------------------|------------------------------------|
| `medicine`             | VMP (generic) name                 |
| `pack_size`            | Pack quantity                      |
| `unit`                 | Unit of measure (tablet, ml, etc.) |
| `vmp_snomed_code`      | VMP SNOMED CT identifier           |
| `vmpp_snomed_code`     | VMPP SNOMED CT identifier          |
| `drug_tariff_category` | e.g. “Part VIIIA Category M”       |
| `basic_price`          | Drug Tariff basic price (pence)    |
| `nhs_indicative_price` | NHS Indicative Price (pence)       |
| `price_basis`          | Basis of NHS Indicative Price      |
| `price_date`           | Date of NHS Indicative Price       |
| `ampp_name`            | Branded pack name                  |
| `ampp_snomed_code`     | AMPP SNOMED CT identifier          |

------------------------------------------------------------------------

## Data attribution

The bundled `dmd_master` dataset is derived from the **NHS Dictionary of
Medicines and Devices (dm+d)**, Week 34 2025 (14 August 2025), published
by the **NHS Business Services Authority (NHSBSA)**.

© Crown copyright. Licensed under the [Open Government Licence
v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
