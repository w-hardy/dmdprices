# Launch the dm+d dose optimiser Shiny app

Opens an interactive browser-based interface for finding the cheapest or
minimum-item pack combination that delivers a specified dose, using
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md).

## Usage

``` r
run_dmd_dose_optimise()
```

## Value

Starts the Shiny app (does not return a value).

## Examples

``` r
if (interactive()) {
  run_dmd_dose_optimise()
}
```
