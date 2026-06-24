# Look up medicine prices from a dm+d database

Searches a dm+d pricing table for medicines whose names match `query`.
Both the generic VMP name (`medicine`) and the branded pack name
(`ampp_name`) are searched, so a query for either a brand (e.g.
`"Buvidal"`) or its generic (e.g.
`"Buprenorphine ... prolonged-release"`) returns the matching packs.
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

  One of (each matches against the generic `medicine` name and the
  branded `ampp_name`):

  - `"partial"` *(default)* — case-insensitive **literal** substring
    match. The query is matched as written, so punctuation such as
    `"[I-131]"` is treated literally rather than as a regular
    expression. Suitable for general searching, e.g. `"metformin"` or
    `"Buvidal"`.

  - `"exact"` — case-insensitive exact match against the full VMP name
    or the full branded pack name.

  - `"fuzzy"` — approximate string matching (optimal string alignment
    distance via
    [`stringdist::stringdist()`](https://rdrr.io/pkg/stringdist/man/stringdist.html),
    taking the closer of the generic and brand names). Tolerates typos.
    Tune sensitivity with `max_dist`.

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
dataset (Week 15 2026, 06 April 2026) is used, so no setup is needed.
Supply `db` to use a more recent release loaded with
[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md).

## Examples

``` r
# Uses bundled data — no setup required
dmd_price_lookup("metformin")
#> # A tibble: 224 × 13
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
#> 10 Empagliflozin 12.5mg / Metf…        56 tabl… 30318211000001… 301747110000011…
#> # ℹ 214 more rows
#> # ℹ 8 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>, is_combination <lgl>

# Brand names work too (matched against the branded pack name)
dmd_price_lookup("Buvidal")
#> # A tibble: 8 × 13
#>   medicine pack_size unit  vmp_snomed_code vmpp_snomed_code drug_tariff_category
#>   <chr>        <dbl> <chr> <chr>           <chr>            <chr>               
#> 1 Bupreno…         1 pre-… 36751611000001… 367347110000011… Part VIIIA Category…
#> 2 Bupreno…         1 pre-… 40558011000001… 405511110000011… Part VIIIA Category…
#> 3 Bupreno…         1 pre-… 36751711000001… 367276110000011… Part VIIIA Category…
#> 4 Bupreno…         1 pre-… 36751911000001… 367285110000011… Part VIIIA Category…
#> 5 Bupreno…         1 pre-… 36752211000001… 367299110000011… Part VIIIA Category…
#> 6 Bupreno…         1 pre-… 36752311000001… 367316110000011… Part VIIIA Category…
#> 7 Bupreno…         1 pre-… 36752411000001… 367265110000011… Part VIIIA Category…
#> 8 Bupreno…         1 pre-… 36752511000001… 367333110000011… Part VIIIA Category…
#> # ℹ 7 more variables: basic_price <int>, nhs_indicative_price <int>,
#> #   price_basis <chr>, price_date <chr>, ampp_name <chr>,
#> #   ampp_snomed_code <chr>, is_combination <lgl>

dmd_price_lookup("Metformin 500mg tablets", method = "exact")
#> # A tibble: 37 × 13
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
#> # ℹ 27 more rows
#> # ℹ 8 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>, is_combination <lgl>

dmd_price_lookup("metfromin 500mg tablets", method = "fuzzy", max_dist = 4)
#> # A tibble: 62 × 13
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
#> # ℹ 52 more rows
#> # ℹ 8 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>, is_combination <lgl>

# Include rows without any price
dmd_price_lookup("metformin", active_only = FALSE)
#> # A tibble: 287 × 13
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
#> # ℹ 8 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>, is_combination <lgl>

if (FALSE) { # \dontrun{
# Use a locally loaded, more recent release
db <- dmd_load("~/dmdDataLoader")
dmd_price_lookup("metformin", db = db)
} # }
```
