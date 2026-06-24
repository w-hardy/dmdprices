# NHS dm+d per-ingredient strengths

A tidy table of ingredient strengths built from the dm+d Virtual Product
Ingredient (VPI) extract, with one row per (VMP, ingredient). It
identifies the individual active ingredients — and their strengths — of
every VMP, including combination products such as co-codamol, enabling
ingredient-specific dose optimisation via
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md).

## Usage

``` r
dmd_ingredients
```

## Format

A tibble with one row per VMP/ingredient and 9 columns:

- vmp_snomed_code:

  `character`. SNOMED CT identifier for the VMP.

- ingredient_snomed_code:

  `character`. SNOMED CT identifier for the ingredient substance (ISID).

- ingredient_name:

  `character`. Ingredient substance name, e.g. `"Codeine phosphate"`.

- strength_value:

  `numeric`. Strength numerator value.

- strength_unit:

  `character`. Strength numerator unit (e.g. `"mg"`).

- denominator_value:

  `numeric`. Strength denominator value for concentrations, else `NA`.

- denominator_unit:

  `character`. Strength denominator unit (e.g. `"ml"`), else `NA`.

- strength_canonical:

  `numeric`. Strength in canonical units (mass in mg, volume in ml, or
  biological activity as `"unit"`), for cross-product comparison. `NA`
  for strengths recorded in units that have no mass equivalent (e.g.
  radioactivity in GBq/MBq, amount of substance in mmol, vaccine antigen
  units, or volumes such as microlitre). Such ingredients cannot be
  dose-optimised by mass via
  [`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md).

- strength_unit_canon:

  `character`. Canonical strength unit, or `NA` when the strength has no
  mass/volume/activity equivalent.

## Source

NHS Dictionary of Medicines and Devices (dm+d). Published by the NHS
Business Services Authority (NHSBSA).

© Crown copyright. Contains public sector information licensed under the
**Open Government Licence v3.0**.  
<https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/>

## Details

A VMP with two or more distinct ingredients is a combination product;
this is also surfaced as the `is_combination` column on a
[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
database's `$master` table.

The version bundled with the package may be **empty**: the VPI extract
is an optional part of a dm+d release and is not always present. Rebuild
the bundled data from a release that includes `f_vmp_VpiType.csv` (see
`data-raw/dmd_master.R`), or load a full release with
[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md),
to populate it. Check with `nrow(dmd_ingredients)`.

## See also

[dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md),
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md),
[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
