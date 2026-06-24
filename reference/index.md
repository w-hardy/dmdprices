# Package index

## Price lookup

Query medicine prices from the dm+d

- [`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md)
  : Look up medicine prices from a dm+d database
- [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
  : Load a dm+d database from a dmdDataLoader output directory

## Dose optimisation

Find combinations of AMPPs that deliver a target dose

- [`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md)
  : Find dose combinations for a clinical dose
- [`dmd_dose_cost()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_cost.md)
  : Vectorised dose cost lookup
- [`dmd_dose_cost_range()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_cost_range.md)
  : Vectorised dose cost range lookup
- [`dmd_parse_strength()`](https://w-hardy.github.io/dmdprices/reference/dmd_parse_strength.md)
  : Parse a dm+d VMP name into drug stem, strength, and remainder

## Inflation adjustment

Adjust costs using NHS Cost Inflation Index (NHS CII)

- [`nhscii()`](https://w-hardy.github.io/dmdprices/reference/nhscii.md)
  : NHS Cost Inflation Index factor between two financial years
- [`inflate_nhscii()`](https://w-hardy.github.io/dmdprices/reference/inflate_nhscii.md)
  : Inflate or deflate a cost using NHS CII

## Shiny apps

Launch interactive apps locally

- [`run_dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/run_dmd_price_lookup.md)
  : Launch the dm+d price lookup Shiny app
- [`run_inflate_nhscii()`](https://w-hardy.github.io/dmdprices/reference/run_inflate_nhscii.md)
  : Launch the NHS CII cost adjuster Shiny app
- [`run_dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/run_dmd_dose_optimise.md)
  : Launch the dm+d dose optimiser Shiny app

## Data

Bundled datasets

- [`dmd_master`](https://w-hardy.github.io/dmdprices/reference/dmd_master.md)
  : NHS dm+d medicine pricing master table
- [`dmd_ingredients`](https://w-hardy.github.io/dmdprices/reference/dmd_ingredients.md)
  : NHS dm+d per-ingredient strengths
- [`dmd_master_info()`](https://w-hardy.github.io/dmdprices/reference/dmd_master_info.md)
  : Report metadata about a dm+d dataset

## Package

- [`dmdprices`](https://w-hardy.github.io/dmdprices/reference/dmdprices-package.md)
  [`dmdprices-package`](https://w-hardy.github.io/dmdprices/reference/dmdprices-package.md)
  : dmdprices: Look Up Medicine Prices from the NHS dm+d
