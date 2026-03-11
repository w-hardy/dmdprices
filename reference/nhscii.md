# NHS Cost Inflation Index factor between two financial years

Returns the inflation adjustment as a multiplicative factor by default.
For example, a value of `1.125` means a 12.5% increase.

## Usage

``` r
nhscii(
  from_year,
  to_year,
  index = "pay_and_prices",
  output_type = c("factor", "percent")
)
```

## Arguments

- from_year:

  Financial year in `"YYYY/YY"` format (e.g. `"2019/20"`) or numeric
  end-year (e.g. `2020`, interpreted as `"2019/20"`).

- to_year:

  Financial year in `"YYYY/YY"` format (e.g. `"2023/24"`) or numeric
  end-year (e.g. `2024`, interpreted as `"2023/24"`).

- index:

  Character scalar. One of `"pay_and_prices"` (default), `"pay"`, or
  `"prices"`.

- output_type:

  Character scalar. `"factor"` (default) for multiplicative factor, or
  `"percent"` for percentage change.

## Value

A numeric scalar:

- if `output_type = "factor"` (default): multiplicative factor

- if `output_type = "percent"`: percentage change

## Details

Data source: PSSRU Unit Costs of Health and Social Care
([doi:10.22024/UniKent/01.02.109563](https://doi.org/10.22024/UniKent/01.02.109563)
).

The 2023/24 figures are provisional and may be revised in later PSSRU
releases as additional data become available.

## Examples

``` r
nhscii("2019/20", "2023/24")
#> [1] 1.17693
nhscii(2020, 2024) # same as "2019/20" -> "2023/24"
#> [1] 1.17693
nhscii("2021/22", "2023/24", index = "pay", output_type = "percent")
#> [1] 12.55494
```
