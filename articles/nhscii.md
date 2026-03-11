# NHS Cost Inflation Index (NHS CII)

## Overview

The NHS Cost Inflation Index (NHS CII) is published annually by the
PSSRU (Personal Social Services Research Unit) as part of their *Unit
Costs of Health and Social Care* publication. It provides standardized
rates to adjust health and social care costs for inflation across
financial years.

This vignette shows how to use
[`nhscii()`](https://w-hardy.github.io/dmdprices/reference/nhscii.md)
and
[`inflate_nhscii()`](https://w-hardy.github.io/dmdprices/reference/inflate_nhscii.md)
to work with NHS CII rates in your analyses.

``` r
library(dmdprices)
```

## Getting inflation factors

Use
[`nhscii()`](https://w-hardy.github.io/dmdprices/reference/nhscii.md) to
compute the inflation adjustment between two financial years:

``` r
# Inflate from 2019/20 to 2023/24
nhscii("2019/20", "2023/24")
#> [1] 1.17693
```

A factor of `1.127` means a 12.7% increase over that period.

### Using numeric years

For convenience, you can also pass numeric years (interpreted as
end-years):

``` r
# 2020 is interpreted as "2019/20", 2024 as "2023/24"
nhscii(2020, 2024)
#> [1] 1.17693
```

### Percentage change

To get the percentage change directly:

``` r
nhscii("2019/20", "2023/24", output_type = "percent")
#> [1] 17.69304
```

### Different indices

Three indices are available: `"pay_and_prices"` (default), `"pay"`, and
`"prices"`.

``` r
# Pay component only
nhscii("2021/22", "2023/24", index = "pay")
#> [1] 1.125549

# Prices component only
nhscii("2021/22", "2023/24", index = "prices")
#> [1] 1.108467
```

Notice that pay inflation (`7.41%`) was higher than general price
inflation (`7.15%`) in 2022/23.

## Adjusting costs

Use
[`inflate_nhscii()`](https://w-hardy.github.io/dmdprices/reference/inflate_nhscii.md)
to adjust cost values to a different financial year:

``` r
# A single cost
inflate_nhscii(1000, "2019/20", "2023/24")
#> [1] 1176.93
```

### Multiple costs at once

``` r
costs <- c(150, 500, 2000)
inflated <- inflate_nhscii(
  costs,
  from_year = "2019/20",
  to_year = "2023/24",
  index = "pay_and_prices"
)

data.frame(
  original = costs,
  inflated_2023_24 = inflated
)
#>   original inflated_2023_24
#> 1      150         176.5396
#> 2      500         588.4652
#> 3     2000        2353.8609
```

## Real-world example

Suppose you have unit costs for a health intervention from 2020/21 and
need to report them in 2023/24 prices:

``` r
# Unit costs in 2020/21
unit_cost_2020_21 <- 450

# Inflate to 2023/24
unit_cost_2023_24 <- inflate_nhscii(
  unit_cost_2020_21,
  from_year = 2021,
  to_year = 2024,
  index = "pay_and_prices"
)

unit_cost_2023_24
#> [1] 516.7516
```

If you were comparing across multiple sectors (e.g., staff costs
vs. service delivery), you might use different indices:

``` r
staff_cost <- 200
non_staff_cost <- 250

# Staff costs inflate with pay index
staff_inflated <- inflate_nhscii(staff_cost, 2021, 2024, index = "pay")

# Non-staff costs inflate with prices index
non_staff_inflated <- inflate_nhscii(non_staff_cost, 2021, 2024, index = "prices")

data.frame(
  component = c("Staff", "Non-staff"),
  original = c(staff_cost, non_staff_cost),
  inflated = c(staff_inflated, non_staff_inflated)
)
#>   component original inflated
#> 1     Staff      200 232.0208
#> 2 Non-staff      250 281.8831
```

## Data source and provenance

The NHS CII rates are derived from:

**PSSRU Unit Costs of Health and Social Care**  
<https://doi.org/10.22024/UniKent/01.02.109563>

Current coverage: 2015/16 to 2023/24

### A note on 2023/24 figures

The 2023/24 values in this package are **provisional**. As is standard
for each annual PSSRU publication, later releases (e.g., the 2025
manual) may revise these figures when additional data become available.
Check the latest PSSRU manual for the most current rates.

## Available years

To see which financial years are currently supported:

``` r
# Pay and prices index
nhscii("2015/16", "2015/16")  # Check earliest available year
#> [1] 1

# All indices cover the same period:
# 2015/16, 2016/17, 2017/18, 2018/19, 2019/20, 2020/21, 2021/22, 2022/23, 2023/24
```

If you try to use an unavailable year, you’ll get a helpful error:

``` r
nhscii("2014/15", "2023/24")
#> Error:
#> ! from_year must be one of: 2015/16, 2016/17, 2017/18, 2018/19, 2019/20, 2020/21, 2021/22, 2022/23, 2023/24
```

## Further reading

- [PSSRU Unit Costs of Health and Social
  Care](https://www.pssru.ac.uk/project-pages/unit-costs/)
- [NHS costing
  guidance](https://www.england.nhs.uk/publication/nhs-costing-standards/)
