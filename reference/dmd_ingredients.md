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

  `numeric`. Strength in canonical units: the canonical numerator (mass
  in mg, volume in ml, or biological activity as `"unit"`) per **one
  canonical denominator unit** for a concentration, or the canonical
  numerator alone otherwise. This is the same convention as
  [`dmd_parse_strength()`](https://w-hardy.github.io/dmdprices/reference/dmd_parse_strength.md)
  applies to product names, so "20 mg per 1 g" is `0.02` (mg per mg) and
  "500 mg per 50 ml" is `10` (mg per ml). `NA` for strengths recorded in
  units that have no mass equivalent (e.g. radioactivity in GBq/MBq,
  amount of substance in mmol, vaccine antigen units, or volumes such as
  microlitre) or whose denominator has no canonical unit (e.g. per hour
  for a patch). Such ingredients cannot be dose-optimised by mass via
  [`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md).

- strength_unit_canon:

  `character`. Canonical strength unit in slash form for a concentration
  (`"mg/mg"`, `"mg/ml"`, `"unit/ml"`), or the canonical numerator unit
  alone (`"mg"`); `NA` when the strength has no mass/volume/activity
  equivalent.

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

The bundled table is built from the same Week 15 2026 release as
[dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md)
and has 26,667 rows (`nrow(dmd_ingredients)`). `data-raw/dmd_master.R`
rebuilds both datasets.

A database loaded with
[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
carries its own `$ingredients` table, which is used in place of this
one. That table depends on optional files of the `dmdDataLoader` export.
Without `f_vmp_VpiType.csv` it is `NULL`, and the `ingredient` argument
of
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md)
returns no results, with a warning. Without `f_ingredient.csv` it is
built but `ingredient_name` is `NA`, so `ingredient` matches nothing.
Without `f_lookup_UoMHistoryInfoType.csv` its strength units are `NA`,
so `ingredient` skips every candidate as having a non-mass strength.

## See also

[dmd_master](https://w-hardy.github.io/dmdprices/reference/dmd_master.md),
[`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md),
[`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
