# Load a dm+d database from a dmdDataLoader output directory

Reads the pipe-delimited CSV files produced by the NHSBSA dm+d extract
tool from the `csv/` subdirectory of `path` and builds a single joined
pricing table. The returned object can be passed directly to
[`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md).

## Usage

``` r
dmd_load(path = getOption("dmdprices.path"))
```

## Arguments

- path:

  Path to the `dmdDataLoader` folder (the parent of `csv/`). Defaults to
  `getOption("dmdprices.path")`, allowing you to set a project-wide
  default via `options(dmdprices.path = "~/dmdDataLoader")`.

## Value

A `<dmd_db>` object: a list with the elements:

- `$master` — a
  [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
  row per AMPP (branded pack), containing Drug Tariff and NHS Indicative
  Price columns that mirror the Drug Tariff Part VIIIA CSV format. When
  ingredient data is available it also carries an `is_combination`
  logical column.

- `$ingredients` — a
  [tibble](https://tibble.tidyverse.org/reference/tibble.html) of
  per-ingredient strengths (one row per VMP/ingredient) built from the
  dm+d Virtual Product Ingredient (VPI) extract, or `NULL` if that
  extract was not present. Columns: `vmp_snomed_code`,
  `ingredient_snomed_code`, `ingredient_name`, `strength_value`,
  `strength_unit`, `denominator_value`, `denominator_unit`,
  `strength_canonical`, `strength_unit_canon`.

- `$loaded_at` — a `POSIXct` timestamp recording when the data was
  loaded.

## Examples

``` r
if (FALSE) { # \dontrun{
db <- dmd_load("~/dmdDataLoader")
db
} # }
```
