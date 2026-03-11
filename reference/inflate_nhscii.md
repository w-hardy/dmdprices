# Inflate or deflate a cost using NHS CII

Adjusts a cost value from one financial year to another using
[`nhscii()`](https://w-hardy.github.io/dmdprices/reference/nhscii.md).

## Usage

``` r
inflate_nhscii(cost, from_year, to_year, index = "pay_and_prices")
```

## Arguments

- cost:

  Numeric vector of finite costs.

- from_year:

  Financial year in `"YYYY/YY"` format or numeric end-year.

- to_year:

  Financial year in `"YYYY/YY"` format or numeric end-year.

- index:

  Character scalar. One of `"pay_and_prices"` (default), `"pay"`, or
  `"prices"`.

## Value

Numeric vector of costs adjusted to `to_year`.

## Examples

``` r
inflate_nhscii(100, "2019/20", "2023/24")
#> [1] 117.693
inflate_nhscii(c(100, 250), from_year = 2020, to_year = 2024, index = "prices")
#> [1] 113.7004 284.2509
```
