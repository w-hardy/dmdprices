# dmdprices

An R package for looking up medicine prices from the
[NHS dm+d](https://www.nhsbsa.nhs.uk/pharmacies-gp-practices-and-appliance-contractors/dictionary-medicines-and-devices-dmd)
(Dictionary of Medicines and Devices), with tools for inflation adjustment
using the NHS Cost Inflation Index (NHS CII).

A **bundled dataset** (Week 34 2025, 14 August 2025) is included — no setup
required for immediate use.

---

## Installation

```r
devtools::install_github("w-hardy/dmdprices")
```

---

## Quick start

```r
library(dmdprices)

# Search medicine prices — uses bundled data, no setup needed
dmd_price_lookup("metformin")

# Adjust a cost for inflation between NHS financial years
inflate_nhscii(100, "2019/20", "2023/24")
```

---

## Interactive apps

No R required — use the hosted apps directly:

- [**dm+d Price Lookup**](articles/apps.html#dmd-price-lookup) — search
  medicine prices by name with partial, exact, or fuzzy matching
- [**NHS CII Cost Adjuster**](articles/apps.html#nhs-cii-cost-adjuster) —
  adjust costs between NHS financial years

Or run locally:

```r
run_dmd_price_lookup()
run_inflate_nhscii()
```

---

## Learn more

| Topic | Article |
|---|---|
| Getting started | [Introduction to dmdprices](articles/dmdprices.html) |
| Interactive apps | [Apps](articles/apps.html) |
| NHS Cost Inflation Index | [NHS CII adjustment](articles/nhscii.html) |
| Cost analysis in practice | [Cost analysis workflows](articles/cost_analysis_workflows.html) |
| Drug Tariff matching | [Drug Tariff matching](articles/drug_tariff_matching.html) |
| Advanced matching | [Advanced matching techniques](articles/advanced_matching.html) |
| Data sources & updates | [Data sources & updates](articles/data_sources_updates.html) |
| Troubleshooting | [Troubleshooting](articles/troubleshooting.html) |

---

## Data attribution

The `dmd_master` dataset is derived from the **NHS Dictionary of Medicines and
Devices (dm+d)**, Week 34 2025 release (14 August 2025), published by the
**NHS Business Services Authority (NHSBSA)**.

© Crown copyright. Licensed under the
[Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).

NHS CII rates are from the
[PSSRU Unit Costs of Health and Social Care](https://www.pssru.ac.uk/project-pages/unit-costs/),
published under the Open Government Licence.
