# Working with Drug Tariff and NHS Indicative Prices

## Overview

The NHS maintains two key price lists for medicines:

- **Drug Tariff**: Official reimbursement prices for community
  pharmacies (updated monthly)
- **NHS Indicative Prices**: List prices for hospitals and other NHS
  settings (quarterly updates)

The `dmdprices` package unifies these sources with the **dm+d**
(Dictionary of Medicines and Devices), allowing you to reconcile data
from both lists seamlessly.

``` r
library(dmdprices)
```

## Understanding the price columns

The bundled `dmd_master` dataset includes columns from both sources:

``` r
# Load the bundled data
data(dmd_master)

# Examine a small subset
dmd_master |>
  dplyr::select(
    medicine, pack_size, unit,
    basic_price, nhs_indicative_price, price_basis
  ) |>
  dplyr::slice(1:3)
#> # A tibble: 3 × 6
#>   medicine          pack_size unit  basic_price nhs_indicative_price price_basis
#>   <chr>                 <dbl> <chr>       <int>                <int> <chr>      
#> 1 Risdiplam 5mg ta…        28 tabl…          NA              1843300 NHS Indica…
#> 2 Generic Comirnat…        10 3317…          NA                    0 No Price A…
#> 3 Generic Kilkof o…       200 ml             NA                  206 NHS Indica…
```

**Column meanings:**

| Column                 | Source         | Meaning                                           |
|------------------------|----------------|---------------------------------------------------|
| `basic_price`          | Drug Tariff    | Community pharmacy reimbursement (pence)          |
| `nhs_indicative_price` | NHS Indicative | Hospital/NHS typical price (pence)                |
| `price_basis`          | NHS Indicative | Basis of the indicative price (e.g. “DT”, “MIMS”) |
| `price_date`           | NHS Indicative | Date price was current                            |

## Key differences between the two lists

### Drug Tariff prices

- Updated **monthly** (typically mid-month)
- Legally binding for pharmacy reimbursement
- Usually lower (patient cost-containment)
- Available for most community medicines
- Column: `basic_price`

### NHS Indicative Prices

- Updated **quarterly**
- Reference only (hospitals negotiate)
- May be higher than Drug Tariff
- Reflects broader supply chain
- Column: `nhs_indicative_price`

### When prices differ

``` r
# Find medicines where Drug Tariff < NHS Indicative
price_discrepancies <- dmd_master |>
  dplyr::filter(!is.na(basic_price), !is.na(nhs_indicative_price)) |>
  dplyr::mutate(
    tariff_cheaper = basic_price < nhs_indicative_price,
    pct_difference = ((nhs_indicative_price - basic_price) / basic_price) * 100
  ) |>
  dplyr::filter(tariff_cheaper) |>
  dplyr::arrange(dplyr::desc(pct_difference))

price_discrepancies |>
  dplyr::select(medicine, basic_price, nhs_indicative_price, pct_difference) |>
  dplyr::slice(1:5)
#> # A tibble: 5 × 4
#>   medicine                       basic_price nhs_indicative_price pct_difference
#>   <chr>                                <int>                <int>          <dbl>
#> 1 Sodium chloride 5% eye drops …           0                 2520            Inf
#> 2 Sodium chloride 5% eye drops …           0                 2400            Inf
#> 3 Sodium chloride 5% eye drops …           0                 1598            Inf
#> 4 Sodium chloride 5% eye drops …           0                 2300            Inf
#> 5 Sodium chloride 5% eye drops …           0                  729            Inf
```

This is **normal**: the Drug Tariff is typically more aggressive on cost
control for high-volume, low-cost items.

## Handling missing prices

Not all medicines have prices in both lists:

``` r
# Medicines with Drug Tariff but no NHS Indicative
tariff_only <- dmd_master |>
  dplyr::filter(!is.na(basic_price), is.na(nhs_indicative_price))

nrow(tariff_only)
#> [1] 143

# Medicines with NHS Indicative but no Drug Tariff (often specialty drugs)
indicative_only <- dmd_master |>
  dplyr::filter(is.na(basic_price), !is.na(nhs_indicative_price))

nrow(indicative_only)
#> [1] 84559
```

### Centrally-funded products

Some NHS medicines are centrally procured and have no retail price:

``` r
# These typically appear as missing in both lists
no_price <- dmd_master |>
  dplyr::filter(is.na(basic_price), is.na(nhs_indicative_price))

nrow(no_price)
#> [1] 13900
```

These include: - Vaccines (centrally procured) - Infusions and
injectables (often bespoke agreements) - Orphan/rare disease medicines -
Some biosimilars

**For analysis:** decide upfront whether to exclude, estimate, or flag
these records.

## Matching medicines between sources

If you have a **Drug Tariff CSV** from NHS, use
[`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md)
to reconcile:

``` r
# Example: you have a list of medicine names from your pharmacy system
your_medicines <- c("Metformin 500mg tablets", "Lisinopril 10mg tablets")

# Look them up in dm+d
results <- lapply(your_medicines, dmd_price_lookup, method = "exact")
results
#> [[1]]
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
#> 
#> [[2]]
#> # A tibble: 18 × 12
#>    medicine                pack_size unit   vmp_snomed_code   vmpp_snomed_code 
#>    <chr>                       <dbl> <chr>  <chr>             <chr>            
#>  1 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#>  2 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#>  3 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#>  4 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#>  5 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#>  6 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#>  7 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#>  8 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#>  9 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#> 10 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#> 11 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#> 12 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#> 13 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#> 14 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#> 15 Lisinopril 10mg tablets        28 tablet 42376111000001109 1067211000001107 
#> 16 Lisinopril 10mg tablets       500 tablet 42376111000001109 36938011000001104
#> 17 Lisinopril 10mg tablets       500 tablet 42376111000001109 36938011000001104
#> 18 Lisinopril 10mg tablets       500 tablet 42376111000001109 36938011000001104
#> # ℹ 7 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>
```

### Fuzzy matching for typos/variations

If exact matches fail, use fuzzy matching:

``` r
# Your source data might have minor spelling variations
dmd_price_lookup("metformin 500 mg tablets", method = "fuzzy", max_dist = 3)
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

## Reconciling external price lists

If you’re importing a Drug Tariff extract:

``` r
# Simulated Drug Tariff data
external_tariff <- data.frame(
  medicine_name = c("Paracetamol 500mg tablets", "Ibuprofen 200mg tablets"),
  external_price_pence = c(150, 280)
)

# Match each medicine to dm+d
external_tariff$vmp_name <- sapply(
  external_tariff$medicine_name,
  function(x) {
    result <- dmd_price_lookup(x, method = "fuzzy", max_dist = 2)
    if (nrow(result) > 0) result$medicine[[1]] else NA_character_
  }
)

# Now you can compare prices
external_tariff
#>               medicine_name external_price_pence                  vmp_name
#> 1 Paracetamol 500mg tablets                  150 Paracetamol 500mg tablets
#> 2   Ibuprofen 200mg tablets                  280   Ibuprofen 200mg tablets
```

## Best practices

### 1. Always check for missing prices first

``` r
# Flag records with incomplete pricing
dmd_master |>
  dplyr::mutate(
    has_tariff = !is.na(basic_price),
    has_indicative = !is.na(nhs_indicative_price),
    pricing_status = dplyr::case_when(
      has_tariff & has_indicative ~ "Both sources",
      has_tariff ~ "Tariff only",
      has_indicative ~ "Indicative only",
      TRUE ~ "No price"
    )
  ) |>
  dplyr::count(pricing_status)
#> # A tibble: 4 × 2
#>   pricing_status      n
#>   <chr>           <int>
#> 1 Both sources    19594
#> 2 Indicative only 84559
#> 3 No price        13900
#> 4 Tariff only       143
```

### 2. Document your price source choice

``` r
# Create a unified price column with priority logic
analysis_data <- dmd_master |>
  dplyr::mutate(
    analysis_price_pence = dplyr::coalesce(basic_price, nhs_indicative_price),
    price_source = dplyr::case_when(
      !is.na(basic_price) ~ "Drug Tariff",
      !is.na(nhs_indicative_price) ~ "NHS Indicative",
      TRUE ~ "Missing"
    )
  )

# Report this in your methodology
analysis_data |>
  dplyr::count(price_source)
#> # A tibble: 3 × 2
#>   price_source       n
#>   <chr>          <int>
#> 1 Drug Tariff    19737
#> 2 Missing        13900
#> 3 NHS Indicative 84559
```

### 3. Note the currency and units

Prices in `dmdprices` are in **pence**. Always convert for reporting:

``` r
# Convert to pounds for reports
analysis_data |>
  dplyr::mutate(price_pounds = analysis_price_pence / 100) |>
  dplyr::select(medicine, price_pence = analysis_price_pence, price_pounds) |>
  dplyr::slice(1:3)
#> # A tibble: 3 × 3
#>   medicine                                              price_pence price_pounds
#>   <chr>                                                       <int>        <dbl>
#> 1 Risdiplam 5mg tablets                                     1843300     18433   
#> 2 Generic Comirnaty LP.8.1 adults and adolescents from…           0         0   
#> 3 Generic Kilkof oral solution                                  206         2.06
```

### 4. Keep audit trails

``` r
# Record which version of dm+d was used
analysis_timestamp <- list(
  dmd_release = attr(dmd_master, "dmd_release_label"),
  analysis_date = Sys.Date()
)

analysis_timestamp
#> $dmd_release
#> [1] "Week 34 2025 (14 August 2025)"
#> 
#> $analysis_date
#> [1] "2026-03-11"
```

## Further reading

- [NHSBSA Drug
  Tariff](https://www.nhsbsa.nhs.uk/pharmacies-gp-practices-and-appliance-contractors/drug-tariff)
- [NHS Indicative
  Prices](https://www.england.nhs.uk/publication/national-cost-collection-ncc/)
- [dm+d on TRUD](https://isd.digital.nhs.uk/trud)
