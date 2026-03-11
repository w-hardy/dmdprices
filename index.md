# dmdprices

An R package for looking up medicine prices from the [NHS
dm+d](https://www.nhsbsa.nhs.uk/pharmacies-gp-practices-and-appliance-contractors/dictionary-medicines-and-devices-dmd)
(Dictionary of Medicines and Devices), with tools for inflation
adjustment using the NHS Cost Inflation Index (NHS CII).

A **bundled dataset** (Week 34 2025, 14 August 2025) is included — no
setup required for immediate use.

**⚠️ Under development — not validated.** This package is under active
development and has not been formally validated. Outputs should be
independently verified before use in research or clinical
decision-making. Use at your own risk.

------------------------------------------------------------------------

## Installation

``` r
devtools::install_github("w-hardy/dmdprices")
```

------------------------------------------------------------------------

## Quick start

``` r
library(dmdprices)

# Search medicine prices — uses bundled data, no setup needed
dmd_price_lookup("metformin")

# Adjust a cost for inflation between NHS financial years
inflate_nhscii(100, "2019/20", "2023/24")
```

------------------------------------------------------------------------

## Interactive apps

No R required — use the hosted apps directly:

- [**dm+d Price
  Lookup**](https://w-hardy.github.io/dmdprices/articles/apps.html#dmd-price-lookup)
  — search medicine prices by name with partial, exact, or fuzzy
  matching
- [**NHS CII Cost
  Adjuster**](https://w-hardy.github.io/dmdprices/articles/apps.html#nhs-cii-cost-adjuster)
  — adjust costs between NHS financial years

Or run locally:

``` r
run_dmd_price_lookup()
run_inflate_nhscii()
```

------------------------------------------------------------------------

## Learn more

| Topic                     | Article                                                                                            |
|---------------------------|----------------------------------------------------------------------------------------------------|
| Getting started           | [Introduction to dmdprices](https://w-hardy.github.io/dmdprices/articles/dmdprices.md)             |
| Interactive apps          | [Apps](https://w-hardy.github.io/dmdprices/articles/apps.md)                                       |
| NHS Cost Inflation Index  | [NHS CII adjustment](https://w-hardy.github.io/dmdprices/articles/nhscii.md)                       |
| Cost analysis in practice | [Cost analysis workflows](https://w-hardy.github.io/dmdprices/articles/cost_analysis_workflows.md) |
| Drug Tariff matching      | [Drug Tariff matching](https://w-hardy.github.io/dmdprices/articles/drug_tariff_matching.md)       |
| Advanced matching         | [Advanced matching techniques](https://w-hardy.github.io/dmdprices/articles/advanced_matching.md)  |
| Data sources & updates    | [Data sources & updates](https://w-hardy.github.io/dmdprices/articles/data_sources_updates.md)     |
| Troubleshooting           | [Troubleshooting](https://w-hardy.github.io/dmdprices/articles/troubleshooting.md)                 |

------------------------------------------------------------------------

## Data attribution

The `dmd_master` dataset is derived from the **NHS Dictionary of
Medicines and Devices (dm+d)**, Week 34 2025 release (14 August 2025),
published by the **NHS Business Services Authority (NHSBSA)**.

© Crown copyright. Licensed under the [Open Government Licence
v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).

NHS CII rates are from Jones et al. (2025), [*Unit Costs of Health and
Social Care 2024
Manual*](https://doi.org/10.22024/UniKent/01.02.109563), published by
PSSRU (University of Kent) & Centre for Health Economics (University of
York). Licensed under [CC BY-NC-SA
4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
