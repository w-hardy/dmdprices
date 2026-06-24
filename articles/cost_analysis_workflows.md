# Cost Analysis Workflows

## Overview

This vignette shows how to combine
[`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md)
and
[`inflate_nhscii()`](https://w-hardy.github.io/dmdprices/reference/inflate_nhscii.md)
to track medicine costs over time and across different financial years.

``` r

library(dmdprices)
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
```

## Scenario: Tracking a medicine’s cost over time

Suppose you’re evaluating the cost of **metformin 500mg tablets** across
multiple years in your pharmacy budget.

### Step 1: Look up the current price

``` r

metformin <- dmd_price_lookup("metformin 500mg tablets", method = "exact")
metformin
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
```

Extract the price:

``` r

current_price_pence <- metformin$basic_price[[1]]
current_price_pounds <- current_price_pence / 100

cat("Current price (Drug Tariff):", current_price_pounds, "pounds\n")
#> Current price (Drug Tariff): 0.58 pounds
```

### Step 2: Estimate historical costs using NHS CII

You want to know what this medicine would have cost in previous years
(in comparable prices):

``` r

# Current year is 2024/25
# Deflate to earlier years
years <- c("2019/20", "2020/21", "2021/22", "2022/23", "2023/24", "2024/25")

historical_costs <- data.frame(
  year = years,
  deflated_price_pence = NA_real_
)

for (i in seq_along(years)) {
  deflation_factor <- nhscii(
    from_year = "2024/25",
    to_year = years[i],
    index = "prices"
  )
  historical_costs$deflated_price_pence[i] <- current_price_pence * deflation_factor
}

historical_costs <- historical_costs |>
  mutate(
    deflated_price_pounds = deflated_price_pence / 100,
    .before = deflated_price_pence
  )

historical_costs
#>      year deflated_price_pounds deflated_price_pence
#> 1 2019/20             0.5021960             50.21960
#> 2 2020/21             0.5064145             50.64145
#> 3 2021/22             0.5151248             51.51248
#> 4 2022/23             0.5519563             55.19563
#> 5 2023/24             0.5684045             56.84045
#> 6 2024/25             0.5800000             58.00000
```

**Interpretation:** This shows what metformin would have cost in each
year if prices had moved with the NHS CII “prices” index.

### Step 3: Project future costs

Now inflate across the available data. The NHS CII now covers up to
2024/25 (the latest, provisional, year from the PSSRU 2025 manual). For
years beyond the published data, such as 2025/26, you still need to
apply your own estimate:

``` r

# Available historical years (now including 2024/25)
historical_years <- c("2020/21", "2021/22", "2022/23", "2023/24", "2024/25")

historical_projection <- data.frame(
  year = historical_years,
  projected_price_pounds = NA_real_
)

for (i in seq_along(historical_projection$year)) {
  inflation_factor <- nhscii(
    from_year = "2024/25",
    to_year = historical_projection$year[i],
    index = "prices"
  )
  historical_projection$projected_price_pounds[i] <- current_price_pounds * inflation_factor
}

historical_projection
#>      year projected_price_pounds
#> 1 2020/21              0.5064145
#> 2 2021/22              0.5151248
#> 3 2022/23              0.5519563
#> 4 2023/24              0.5684045
#> 5 2024/25              0.5800000

# For years beyond the published data you must supply your own estimate.
# 2025/26 NHS CII rates are not yet published:
inflation_estimate_2025_26 <- 1.03  # Estimated at 3%

future_projection <- data.frame(
  year = "2025/26",
  projected_price_pounds = current_price_pounds * inflation_estimate_2025_26
)

future_projection
#>      year projected_price_pounds
#> 1 2025/26                 0.5974
```

## Scenario: Budget impact analysis

You need to estimate the budget impact of a medicine switch across
multiple medicines.

### Setup: Your current medicines

``` r

# Current medicines in your formulary (fictitious costs)
current_formulary <- data.frame(
  medicine = c(
    "Metformin 500mg tablets",
    "Lisinopril 10mg tablets",
    "Atorvastatin 20mg tablets"
  ),
  current_monthly_packs = c(500, 300, 250)
)

# Look up each medicine
current_formulary$price_pence <- sapply(
  current_formulary$medicine,
  function(med) {
    result <- dmd_price_lookup(med, method = "fuzzy", max_dist = 2)
    if (nrow(result) > 0) {
      result$basic_price[[1]]
    } else {
      NA_real_
    }
  }
)

current_formulary <- current_formulary |>
  mutate(price_pounds = price_pence / 100)

current_formulary
#>                    medicine current_monthly_packs price_pence price_pounds
#> 1   Metformin 500mg tablets                   500          58         0.58
#> 2   Lisinopril 10mg tablets                   300         511         5.11
#> 3 Atorvastatin 20mg tablets                   250          55         0.55
```

### Calculate monthly and annual costs

``` r

current_formulary <- current_formulary |>
  mutate(
    monthly_cost = current_monthly_packs * price_pounds,
    annual_cost_2023_24 = monthly_cost * 12,
    .after = price_pounds
  )

current_formulary
#>                    medicine current_monthly_packs price_pence price_pounds
#> 1   Metformin 500mg tablets                   500          58         0.58
#> 2   Lisinopril 10mg tablets                   300         511         5.11
#> 3 Atorvastatin 20mg tablets                   250          55         0.55
#>   monthly_cost annual_cost_2023_24
#> 1        290.0                3480
#> 2       1533.0               18396
#> 3        137.5                1650
```

### Project costs to 2024/25

``` r

# 2024/25 NHS CII rates are now available (provisional) in the PSSRU 2025 manual
inflation_factor_2024_25 <- nhscii(
  from_year = "2023/24",
  to_year = "2024/25",
  index = "pay_and_prices"
)

current_formulary <- current_formulary |>
  mutate(
    annual_cost_2024_25 = annual_cost_2023_24 * inflation_factor_2024_25,
    cost_increase = annual_cost_2024_25 - annual_cost_2023_24
  )

current_formulary |>
  select(medicine, annual_cost_2023_24, annual_cost_2024_25, cost_increase)
#>                    medicine annual_cost_2023_24 annual_cost_2024_25
#> 1   Metformin 500mg tablets                3480            3619.896
#> 2   Lisinopril 10mg tablets               18396           19135.519
#> 3 Atorvastatin 20mg tablets                1650            1716.330
#>   cost_increase
#> 1      139.8960
#> 2      739.5192
#> 3       66.3300
```

**Summary:**

``` r

current_formulary |>
  summarise(
    total_2023_24 = sum(annual_cost_2023_24, na.rm = TRUE),
    total_2024_25 = sum(annual_cost_2024_25, na.rm = TRUE),
    total_increase = sum(cost_increase, na.rm = TRUE),
    pct_increase = (total_increase / total_2023_24) * 100
  )
#>   total_2023_24 total_2024_25 total_increase pct_increase
#> 1         23526      24471.75       945.7452         4.02
```

## Scenario: Cost-effectiveness analysis with historical comparison

Evaluate how a medicine’s cost-effectiveness ratio changes with
inflation adjustment.

``` r

# Simulated QALY data and costs
cea_data <- data.frame(
  medicine = c("Medicine A", "Medicine B"),
  cost_2020_21_pounds = c(5000, 7500),
  qalys = c(0.50, 0.75)
)

# Inflate costs to 2024/25 (current year)
cea_data <- cea_data |>
  mutate(
    inflation_factor = nhscii(
      from_year = "2020/21",
      to_year = "2024/25",
      index = "pay_and_prices"
    ),
    cost_2024_25_pounds = cost_2020_21_pounds * inflation_factor,
    cost_per_qaly_2020_21 = cost_2020_21_pounds / qalys,
    cost_per_qaly_2024_25 = cost_2024_25_pounds / qalys
  )

cea_data |>
  select(
    medicine,
    cost_per_qaly_2020_21,
    cost_per_qaly_2024_25
  )
#>     medicine cost_per_qaly_2020_21 cost_per_qaly_2024_25
#> 1 Medicine A                 10000              11734.29
#> 2 Medicine B                 10000              11734.29
```

## Scenario: Comparing costs across NHS trusts

Different trusts may purchase medicines at different times. Normalize to
a common year:

``` r

# Data from multiple trusts (purchased in different years)
trust_data <- data.frame(
  trust = c("Trust A", "Trust B", "Trust C"),
  medicine = "Paracetamol 500mg tablets",
  purchase_year = c("2021/22", "2022/23", "2023/24"),
  cost_paid_pounds = c(150, 180, 220),
  quantity = c(1000, 1200, 1500)
)

# Normalize all to 2023/24 prices
trust_data <- trust_data |>
  mutate(
    unit_cost_paid = cost_paid_pounds / quantity,
    inflation_factor = mapply(
      function(from, to) nhscii(from_year = from, to_year = to, index = "prices"),
      from = purchase_year,
      to = "2023/24"
    ),
    normalized_unit_cost_2023_24 = unit_cost_paid * inflation_factor
  )

trust_data |>
  select(trust, purchase_year, unit_cost_paid, normalized_unit_cost_2023_24)
#>     trust purchase_year unit_cost_paid normalized_unit_cost_2023_24
#> 1 Trust A       2021/22      0.1500000                    0.1655146
#> 2 Trust B       2022/23      0.1500000                    0.1544700
#> 3 Trust C       2023/24      0.1466667                    0.1466667
```

**Insight:** Unit cost increased from £0.15 to £0.22, but after
normalizing all to 2023/24 prices, we see Trust A paid slightly *more*
(in 2023/24 equivalent) — suggesting price changes or negotiation
differences.

## Best practices

### 1. Always document your price year

``` r

# Include metadata in your results
analysis_meta <- list(
  price_source = "NHS dm+d bundled data",
  price_year = "2023/24",
  inflation_index = "pay_and_prices",
  dmd_release = attr(dmd_master, "dmd_release_label"),
  analysis_date = Sys.Date()
)

str(analysis_meta)
#> List of 5
#>  $ price_source   : chr "NHS dm+d bundled data"
#>  $ price_year     : chr "2023/24"
#>  $ inflation_index: chr "pay_and_prices"
#>  $ dmd_release    : chr "Week 15 2026 (06 April 2026)"
#>  $ analysis_date  : Date[1:1], format: "2026-06-24"
```

### 2. Handle lookup failures gracefully

``` r

# Function to safely look up prices with fallback
safe_lookup <- function(medicine_name, method = "fuzzy") {
  result <- dmd_price_lookup(
    medicine_name,
    method = method,
    max_dist = 3
  )
  
  if (nrow(result) == 0) {
    warning("No match found for: ", medicine_name)
    return(list(price = NA_real_, matched = FALSE))
  }
  
  list(
    price = result$basic_price[[1]],
    matched = TRUE,
    matched_name = result$medicine[[1]]
  )
}

safe_lookup("paracetamol 500mg tablets")
#> $price
#> [1] NA
#> 
#> $matched
#> [1] TRUE
#> 
#> $matched_name
#> [1] "Paracetamol 500mg tablets"
safe_lookup("xyz_medicine_not_real")
#> Warning: No medicines found matching "xyz_medicine_not_real"
#> with method = "fuzzy".
#> Warning in safe_lookup("xyz_medicine_not_real"): No match found for:
#> xyz_medicine_not_real
#> $price
#> [1] NA
#> 
#> $matched
#> [1] FALSE
```

### 3. Separate data from analysis

``` r

# Keep input data separate from calculated fields
analysis <- current_formulary |>
  select(medicine, current_monthly_packs, price_pence) |>
  mutate(
    # Derived calculations
    monthly_cost_pounds = (current_monthly_packs * price_pence) / 100,
    annual_cost_2023_24 = monthly_cost_pounds * 12,
    # 2024/25 rates are now available (provisional), e.g.:
    # inflated_2024_25 = annual_cost_2023_24 * nhscii("2023/24", "2024/25")
    .after = price_pence
  )
```

## Further reading

- [Costing principles guide (NHS
  England)](https://www.england.nhs.uk/publication/nhs-costing-standards/)
- [NICE cost-effectiveness
  assessment](https://www.nice.org.uk/process/pmg6)
- NHS CII vignette:
  [`vignette("nhscii")`](https://w-hardy.github.io/dmdprices/articles/nhscii.md)
