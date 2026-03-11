# Launch the dm+d price lookup Shiny app

Opens an interactive browser-based interface for querying medicine
prices from the bundled `dmd_master` dataset using
[`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md).

## Usage

``` r
run_dmd_price_lookup()
```

## Value

Starts the Shiny app (does not return a value).

## Examples

``` r
if (interactive()) {
  run_dmd_price_lookup()
}
```
