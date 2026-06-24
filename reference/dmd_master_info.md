# Report metadata about a dm+d dataset

Returns a concise summary of key attributes for the bundled
[dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md)
dataset or a user-loaded
[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
database. Useful for confirming data freshness in analysis scripts and
Shiny app footers.

## Usage

``` r
dmd_master_info(db = dmdprices::dmd_master)
```

## Arguments

- db:

  A `<dmd_db>` object from
  [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md),
  or the bundled
  [dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md)
  tibble. Defaults to the bundled
  [dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md).

## Value

A list of class `"dmd_db_info"` with the following elements:

- `release_label`:

  Character. dm+d release label (e.g. `"Week 15 2026 (06 April 2026)"`).
  `NA` for user-loaded databases (use `loaded_at` instead).

- `loaded_at`:

  `POSIXct` timestamp recording when
  [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
  was called. `NA` for the bundled `dmd_master`.

- `n_ampps`:

  Number of distinct AMPPs (branded packs).

- `n_vmpps`:

  Number of distinct VMPPs.

- `n_vmps`:

  Number of distinct VMPs (generic medicines).

- `price_date_range`:

  Character vector `c(earliest, latest)` of `price_date` values present
  in the dataset. Both `NA` if the column is absent or entirely `NA`.

## Examples

``` r
dmd_master_info()
#> ✔ dm+d dataset: Week 15 2026 (06 April 2026)
#> • 23720 VMPs | 35706 VMPPs | 106292 AMPPs
#> • Price date: 2003-01-15 - 2025-08-14

if (FALSE) { # \dontrun{
db <- dmd_load("~/dmdDataLoader")
dmd_master_info(db)
} # }
```
