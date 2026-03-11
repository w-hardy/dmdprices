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
# Current year is 2023/24
# Deflate to earlier years
years <- c("2019/20", "2020/21", "2021/22", "2022/23", "2023/24")

historical_costs <- data.frame(
  year = years,
  deflated_price_pence = NA_real_
)

for (i in seq_along(years)) {
  deflation_factor <- nhscii(
    from_year = "2023/24",
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
#> 1 2019/20             0.5101127             51.01127
#> 2 2020/21             0.5143976             51.43976
#> 3 2021/22             0.5232453             52.32453
#> 4 2022/23             0.5606573             56.06573
#> 5 2023/24             0.5800000             58.00000
```

**Interpretation:** This shows what metformin would have cost in each
year if prices had moved with the NHS CII “prices” index.

### Step 3: Project future costs

Now inflate across the available data and estimate future years. Note
that 2024/25 and 2025/26 rates will be published in the PSSRU 2025
manual; for now we use the 2023/24 rate as a baseline:

``` r
# Available historical years
historical_years <- c("2020/21", "2021/22", "2022/23", "2023/24")

historical_projection <- data.frame(
  year = historical_years,
  projected_price_pounds = NA_real_
)

for (i in seq_along(historical_projection$year)) {
  inflation_factor <- nhscii(
    from_year = "2023/24",
    to_year = historical_projection$year[i],
    index = "prices"
  )
  historical_projection$projected_price_pounds[i] <- current_price_pounds * inflation_factor
}

historical_projection
#>      year projected_price_pounds
#> 1 2020/21              0.5143976
#> 2 2021/22              0.5232453
#> 3 2022/23              0.5606573
#> 4 2023/24              0.5800000

# For future projections, you would apply estimated inflation factors
# once 2024/25 and 2025/26 NHS CII rates are published
inflation_estimate_2024_25 <- 1.04  # Estimated at 4% based on recent trends
inflation_estimate_2025_26 <- 1.03  # Estimated at 3%

future_projection <- data.frame(
  year = c("2024/25", "2025/26"),
  projected_price_pounds = c(
    current_price_pounds * inflation_estimate_2024_25,
    current_price_pounds * inflation_estimate_2024_25 * inflation_estimate_2025_26
  )
)

future_projection
#>      year projected_price_pounds
#> 1 2024/25               0.603200
#> 2 2025/26               0.621296
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
inflation_factor_2024_25 <- nhscii(
  from_year = "2023/24",
  to_year = "2023/24",  # We don't have 2024/25 yet; for demo use current year
  index = "pay_and_prices"
)

# For projection purposes (assuming modest inflation)
inflation_estimate_2024_25 <- 1.04  # 4% placeholder

current_formulary <- current_formulary |>
  mutate(
    annual_cost_2024_25 = annual_cost_2023_24 * inflation_estimate_2024_25,
    cost_increase = annual_cost_2024_25 - annual_cost_2023_24
  )

current_formulary |>
  select(medicine, annual_cost_2023_24, annual_cost_2024_25, cost_increase)
#>                    medicine annual_cost_2023_24 annual_cost_2024_25
#> 1   Metformin 500mg tablets                3480             3619.20
#> 2   Lisinopril 10mg tablets               18396            19131.84
#> 3 Atorvastatin 20mg tablets                1650             1716.00
#>   cost_increase
#> 1        139.20
#> 2        735.84
#> 3         66.00
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
#> 1         23526      24467.04         941.04            4
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

# Inflate costs to 2023/24 (current year)
cea_data <- cea_data |>
  mutate(
    inflation_factor = nhscii(
      from_year = "2020/21",
      to_year = "2023/24",
      index = "pay_and_prices"
    ),
    cost_2023_24_pounds = cost_2020_21_pounds * inflation_factor,
    cost_per_qaly_2020_21 = cost_2020_21_pounds / qalys,
    cost_per_qaly_2023_24 = cost_2023_24_pounds / qalys
  )

cea_data |>
  select(
    medicine, 
    cost_per_qaly_2020_21, 
    cost_per_qaly_2023_24
  )
#>     medicine cost_per_qaly_2020_21 cost_per_qaly_2023_24
#> 1 Medicine A                 10000              11483.37
#> 2 Medicine B                 10000              11483.37
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
#> 1 Trust A       2021/22      0.1500000                    0.1662700
#> 2 Trust B       2022/23      0.1500000                    0.1551750
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
#>  $ dmd_release    : chr "Week 34 2025 (14 August 2025)"
#>  $ analysis_date  : Date[1:1], format: "2026-03-11"
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
    # Once 2024/25 rates are available, you can use:
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
