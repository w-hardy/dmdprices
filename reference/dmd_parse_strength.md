# Parse a dm+d VMP name into drug stem, strength, and remainder

Extracts a numeric strength and optional per-denominator concentration
(e.g. `mg/ml`, `microgram/dose`) from a VMP name. Also returns a
canonical form (mass in mg, volume in ml, biological activity as
`"unit"`).

## Usage

``` r
dmd_parse_strength(name)
```

## Arguments

- name:

  Character vector of VMP names.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per input, with columns: `drug_stem`, `strength_value`,
`strength_unit`, `denominator_value`, `denominator_unit`, `tail`,
`strength_canonical`, `strength_unit_canon`, `is_combination` (logical),
`n_components` (integer count of parsed ingredients), and `components`
(a list-column of per-ingredient tibbles with `value`, `unit`,
`canonical_value`, and `canonical_unit`). For combination products
`strength_value` / `strength_canonical` are `NA` because a single scalar
strength is not meaningful; use `components`.

## Details

Combination (multi-ingredient) products such as co-codamol
(`"8mg/500mg"`) or co-careldopa (`"25mg/100mg"`) are detected and their
individual ingredient strengths returned in the `components`
list-column, rather than being misread as a single mass-per-mass
concentration. A trailing volume/dose denominator on a combination
liquid (e.g. co-trimoxazole `"80mg/400mg/5ml"`) is captured in
`denominator_value` / `denominator_unit`.

## Examples

``` r
dmd_parse_strength(c(
  "Metformin 500mg tablets",
  "Morphine 10mg/5ml oral solution",
  "Salbutamol 100micrograms/dose inhaler CFC free"
))
#> # A tibble: 3 × 11
#>   drug_stem  strength_value strength_unit denominator_value denominator_unit
#>   <chr>               <dbl> <chr>                     <dbl> <chr>           
#> 1 Metformin             500 mg                           NA NA              
#> 2 Morphine               10 mg                            5 ml              
#> 3 Salbutamol            100 micrograms                    1 dose            
#> # ℹ 6 more variables: tail <chr>, strength_canonical <dbl>,
#> #   strength_unit_canon <chr>, is_combination <lgl>, n_components <int>,
#> #   components <list>

# Combination products expose per-ingredient strengths
res <- dmd_parse_strength("Co-codamol 8mg/500mg tablets")
res$is_combination
#> [1] TRUE
res$components[[1]]
#> # A tibble: 2 × 4
#>   value unit  canonical_value canonical_unit
#>   <dbl> <chr>           <dbl> <chr>         
#> 1     8 mg                  8 mg            
#> 2   500 mg                500 mg            
```
