# Data Sources and Updates

## Overview

`dmdprices` combines data from three authoritative NHS sources. This
vignette explains where the data comes from, how often it updates, and
how to stay current.

``` r

library(dmdprices)
```

## The three data sources

### 1. NHS dm+d (Dictionary of Medicines and Devices)

**What it is:** The authoritative UK medicine and device dictionary,
maintained by the NHSBSA.

**Update frequency:** Weekly (every Thursday)

**Content:**

- Virtual Medicinal Products (VMPs) — generic medicines
- Virtual Medicinal Product Packs (VMPPs) — packs/strengths
- Actual Medicinal Products (AMPs) — branded products
- SNOMED CT codes for each
- Links to Drug Tariff and NHS Indicative Prices

**Coverage:** All medicines approved for use in UK NHS

**Access:** NHSBSA TRUD (Technology Reference Data Update) service

📍 <https://isd.digital.nhs.uk/trud>

**In dmdprices:**

``` r

# The bundled dataset
data(dmd_master)

attr(dmd_master, "dmd_release_label")
#> [1] "Week 15 2026 (06 April 2026)"

nrow(dmd_master)
#> [1] 118196
```

### 2. Drug Tariff

**What it is:** Official reimbursement prices for community pharmacies
in England.

**Update frequency:** Monthly (published mid-month)

**Content:**

- Basic prices (pence)
- Drug Tariff part and category
- Uplift and discount schedules

**Published by:** NHSBSA

**Access:** NHSBSA website

📍
<https://www.nhsbsa.nhs.uk/pharmacies-gp-practices-and-appliance-contractors/drug-tariff>

**Important notes:**

- England only (Scotland/Wales have separate arrangements)
- Prices typically lower due to cost-containment policies
- Updated monthly; old prices may not reflect current reimbursement

**In dmdprices:** Column `basic_price`

### 3. NHS Indicative Prices

**What it is:** Reference prices for hospital and NHS secondary care
purchasing.

**Update frequency:** Quarterly

**Content:**

- Indicative prices (pence)
- Basis of price (DT = Drug Tariff, MIMS, other)
- Date price became effective

**Published by:** NHS England

**Access:** NHS England Cost Collection

📍
<https://www.england.nhs.uk/publication/national-cost-collection-ncc/>

**Important notes:**

- Indicative only (hospitals negotiate contracts)
- Broader supply chain reflected
- Usually higher than Drug Tariff (due to distribution markup)

**In dmdprices:** Columns `nhs_indicative_price`, `price_basis`,
`price_date`

## NHS Cost Inflation Index (NHS CII)

**What it is:** Annual inflation rates for health and social care costs,
published by the PSSRU.

**Update frequency:** Annually (usually in autumn/winter for the next
year)

**Content:**

- Pay inflation rates
- Price inflation rates
- Combined pay+prices indices
- Coverage: Currently 2015/16–2023/24

**Published by:** Personal Social Services Research Unit (PSSRU),
University of Kent

**Access:** PSSRU website

📍 <https://www.pssru.ac.uk/project-pages/unit-costs/>

**In dmdprices:** Function
[`nhscii()`](https://w-hardy.github.io/dmdprices/reference/nhscii.md)

``` r

# Example: current rates available
nhscii("2015/16", "2023/24", index = "prices")
#> [1] 1.204231
```

**Note:** 2023/24 figures are provisional per the 2025 PSSRU manual.
Later releases may revise these values.

## How often should you update?

### Use bundled data if:

- You’re doing academic analysis (reproducibility matters)
- Your project isn’t time-sensitive
- You’re learning the package

### Load fresh dm+d if:

- You’re running operational systems (pharmacy, procurement)
- You need current Drug Tariff prices
- New medicines are important to your analysis
- More than 3 months have passed

### Update NHS CII if:

- You’re inflating costs to future years
- New PSSRU manual has been published
- Your analysis year has changed

## Checking which versions you’re using

### dm+d release

``` r

# Check bundled data release
attr(dmd_master, "dmd_release_label")
#> [1] "Week 15 2026 (06 April 2026)"

# Check when it was packaged
attr(dmd_master, "package_date")
#> NULL
```

### When did you last download fresh data?

``` r

# If you've loaded a fresh dm+d via dmd_load()
# Metadata is attached to the returned object
# db <- dmd_load("path/to/dmdDataLoader")
# attr(db, "load_date")
```

### NHS CII coverage

``` r

# The rates currently available
# (from the .nhscii_rates internal object)
# Coverage: 2015/16 to 2023/24
# Use nhscii() with any year in that range

nhscii("2015/16", "2015/16")  # Should return 1
#> [1] 1
```

## Reproducibility and audit trails

### Document your data in every analysis

``` r

# Create a data audit section in your report
data_audit <- list(
  analysis_date = Sys.Date(),
  
  dmd_source = list(
    source = "dmdprices bundled dataset",
    release = attr(dmd_master, "dmd_release_label"),
    medicines_total = nrow(dmd_master)
  ),
  
  inflation_source = list(
    source = "PSSRU Unit Costs of Health and Social Care",
    doi = "10.22024/UniKent/01.02.115569",
    coverage = "2014/15 to 2024/25 (2024/25 provisional)"
  )
)

str(data_audit)
#> List of 3
#>  $ analysis_date   : Date[1:1], format: "2026-06-24"
#>  $ dmd_source      :List of 3
#>   ..$ source         : chr "dmdprices bundled dataset"
#>   ..$ release        : chr "Week 15 2026 (06 April 2026)"
#>   ..$ medicines_total: int 118196
#>  $ inflation_source:List of 3
#>   ..$ source  : chr "PSSRU Unit Costs of Health and Social Care"
#>   ..$ doi     : chr "10.22024/UniKent/01.02.115569"
#>   ..$ coverage: chr "2014/15 to 2024/25 (2024/25 provisional)"
```

### Save metadata with your results

``` r

# Include in your output file
metadata <- data.frame(
  item = c(
    "Analysis date",
    "dm+d release",
    "NHS CII index",
    "Package version"
  ),
  value = c(
    as.character(Sys.Date()),
    attr(dmd_master, "dmd_release_label"),
    "pay_and_prices",
    as.character(packageVersion("dmdprices"))
  )
)

metadata
#>              item                        value
#> 1   Analysis date                   2026-06-24
#> 2    dm+d release Week 15 2026 (06 April 2026)
#> 3   NHS CII index               pay_and_prices
#> 4 Package version                        0.5.0
```

## Update workflow example

If you’re doing regular analyses, here’s a recommended workflow:

``` r

# 1. Once per quarter: refresh dm+d
my_dm_d <- dmd_load("~/dmdDataLoader")  # Download fresh release
saveRDS(my_dm_d, "data/dm_d_current.rds")

# 2. Check if NHS CII needs updating
# Visit https://www.pssru.ac.uk and check if new manual is available
# (Current package covers through 2023/24; update when 2024/25 rates published)

# 3. In your analysis scripts:
dm_d <- readRDS("data/dm_d_current.rds")
medicine_cost <- dmd_price_lookup("Metformin 500mg", db = dm_d)

# 4. Record versions
analysis_metadata <- list(
  dm_d_release = attr(dm_d, "dmd_release_label"),
  cii_latest_year = "2023/24",  # Update when new rates available
  analysis_date = Sys.Date()
)
```

## Official data feeds (for developers)

If you’re building on `dmdprices`, here are direct feeds:

### dm+d download

    https://isd.digital.nhs.uk/trud/users/guest/filters/0/categories/6

(Free registration required)

### Drug Tariff CSV

    https://www.nhsbsa.nhs.uk/pharmacies-gp-practices-and-appliance-contractors/drug-tariff

(Monthly archive available)

### NHS Indicative Prices

    https://www.england.nhs.uk/publication/national-cost-collection-ncc/

### PSSRU Unit Costs

    https://www.pssru.ac.uk/project-pages/unit-costs/

## Licensing and attribution

### dm+d

© Crown copyright. Licensed under the Open Government Licence v3.0  
📍
<https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/>

**Citation:**

    NHS Business Services Authority (2025). Dictionary of Medicines and 
    Devices (dm+d). Available: https://isd.digital.nhs.uk/trud

### Drug Tariff and NHS Indicative Prices

Published by NHSBSA and NHS England respectively. No special licence
required for analysis (educational/research use).

**Citation:**

    NHS Business Services Authority (2025). Drug Tariff. Available: 
    https://www.nhsbsa.nhs.uk/pharmacies-gp-practices-and-appliance-contractors/drug-tariff

### NHS CII

Licensed under [Creative Commons Attribution-NonCommercial-ShareAlike
4.0 International (CC BY-NC-SA
4.0)](https://creativecommons.org/licenses/by-nc-sa/4.0/).

**Citation:**

    Jones KC, Weatherly H, Barker A, Birch S, Castelli A, Dargan A, Findlay D, Hinde S, Markham S, Smith D, Teo H (2026). Unit Costs of Health and Social Care 2025 Manual. Technical report. Personal Social Services Research Unit (University of Kent) & Centre for Health Economics (University of York), Kent, UK. https://doi.org/10.22024/UniKent/01.02.115569

## Maintaining the bundled data (for package maintainers)

End users never need this — the package ships with a ready-to-use
dataset. This section is for maintainers refreshing the bundled
`dmd_master` and `dmd_ingredients` datasets to a newer dm+d release.

### Rebuilding

The datasets are rebuilt from a local dmdDataLoader CSV export of a dm+d
release by `data-raw/dmd_master.R`:

1.  Download a dm+d release and produce the dmdDataLoader `csv/` export.

2.  Edit the release metadata (`dmd_release_week/year/date`) and
    `dmd_loader_path` at the top of `data-raw/dmd_master.R`.

3.  From the package root, run:

    ``` r

    source("data-raw/dmd_master.R")
    ```

    This rebuilds and saves **both** `data/dmd_master.rda` and
    `data/dmd_ingredients.rda`.

4.  Update the release label/date in `R/data.R` (the `dmd_master` /
    `dmd_ingredients` roxygen) and in `DESCRIPTION`, then run
    `devtools::document()`.

5.  Run `devtools::test()` and `devtools::check()`.

The script reads these CSV files: `f_vmp_VmpType.csv`,
`f_vmpp_VmppType.csv`, `f_vmpp_DtInfoType.csv`, `f_ampp_AmppType.csv`,
`f_ampp_PriceInfoType.csv`, `f_lookup_DtPayCatInfoType.csv`,
`f_lookup_PriceBasisInfoType.csv`, plus the optional ingredient files
`f_vmp_VpiType.csv`, `f_ingredient.csv`, and
`f_lookup_UoMHistoryInfoType.csv` (which add the `$ingredients` table,
the `is_combination` flag, and unit labels). **dm+d occasionally renames
these files between releases.** If the loader errors with “Expected file
not found”, update the filename in both `R/dmd_load.R` and
`data-raw/dmd_master.R` (the column specs live in `.col_names` in
`R/utils.R`).

### Verifying a rebuild

Confirm every pack unit resolved to a label rather than a raw SNOMED
code:

``` r

sum(grepl("^[0-9]+$", dmd_master$unit))   # should be 0
```

If this is non-zero, the listed codes are missing from the
unit-of-measure lookup — see UoM mapping below.

### Unit-of-measure (UoM) mapping

In the raw dm+d data, pack units (`dmd_master$unit`) are SNOMED codes.
`.build_master()` (`R/utils.R`) resolves them to readable labels in two
layers, in order:

1.  **`.uom_labels`** — a small curated map of the units that matter for
    *dose costing*. These use short, **canonicalisable** labels (`"mg"`,
    `"ml"`, `"g"`, `"dose"`, `"unit"`, `"tablet"`, …) that
    `.canonicalise_unit()` understands, so the optimiser can match a
    pack’s unit against a product’s concentration denominator — e.g. an
    inhaler’s `…/dose`, so one inhaler is costed as its full actuation
    count rather than a single actuation.
2.  **The dm+d UoM lookup** (`f_lookup_UoMHistoryInfoType.csv`,
    `CD → DESC`) — a fallback supplying a readable label for every other
    code (devices, dressings, containers …). These are display-only and
    need not canonicalise.

To add or change a mapping:

- If the unit affects **dosing** (a concentration pack unit such as
  `dose`, `actuation`, `ml`, or `g`), add it to `.uom_labels` with a
  short label that `.canonicalise_unit()` recognises (see `.unit_table`
  in `R/parse_strength.R`). Curated entries take precedence over the
  lookup.
- If the unit is **display-only** (a container or device), nothing is
  needed — the lookup `DESC` is applied automatically on rebuild.

Both layers run at **build time**, so changes only reach the shipped
data when `data-raw/dmd_master.R` is re-run.

## Troubleshooting data issues

### “Why is this medicine missing?”

1.  Check if it’s in dm+d (might be new, delisted, or historical)
2.  Try fuzzy matching with `method = "fuzzy"`
3.  Search TRUD directly for the SNOMED code

### “Why is there no price?”

See vignette “Working with Drug Tariff and NHS Indicative Prices” for
common reasons:

- Centrally procured (vaccines, infusions)
- Specialty/rare disease medicine
- Recently added to formulary
- Price confidentiality (some agreements)

### “Why does my price differ from the Drug Tariff?”

1.  Different month/edition (Tariff updated monthly)
2.  Bundled data may be 1-3 months old
3.  Load fresh dm+d with
    [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)

## Further reading

- NHS CII and inflation:
  [`vignette("nhscii")`](https://w-hardy.github.io/dmdprices/articles/nhscii.md)
- Working with prices:
  [`vignette("drug_tariff_matching")`](https://w-hardy.github.io/dmdprices/articles/drug_tariff_matching.md)
- Cost analysis workflows:
  [`vignette("cost_analysis_workflows")`](https://w-hardy.github.io/dmdprices/articles/cost_analysis_workflows.md)
