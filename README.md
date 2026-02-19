# dmdprices

An R package for looking up medicine prices from the [NHS dm+d](https://www.nhsbsa.nhs.uk/pharmacies-gp-practices-and-appliance-contractors/dictionary-medicines-and-devices-dmd) (Dictionary of Medicines and Devices).

A **bundled dataset** (Week 34 2025, 14 August 2025) is included so that no
setup is required for immediate use. Users can also load a more recent dm+d
release from their own `dmdDataLoader` CSV output using `dmd_load()`.

Output columns mirror the **NHS Drug Tariff Part VIIIA** CSV format so that
dm+d prices and Drug Tariff files can be used together directly.

---

## Installation

```r
# install.packages("pak")
pak::pak("w-hardy/dmdprices")
```

Or install from a local clone:

```r
# install.packages("devtools")
devtools::install("path/to/dmdprices")
```

---

## Quick start — bundled data

No setup required. The bundled `dmd_master` dataset is used by default:

```r
library(dmdprices)

# Partial match — all metformin products
dmd_price_lookup("metformin")

# Exact VMP name
dmd_price_lookup("Metformin 500mg tablets", method = "exact")

# Fuzzy — tolerates typos
dmd_price_lookup("metfromin 500mg tablets", method = "fuzzy", max_dist = 4)

# Include rows with no price (e.g. centrally-funded products)
dmd_price_lookup("metformin", active_only = FALSE)

# Export
readr::write_csv(dmd_price_lookup("atenolol"), "atenolol_prices.csv")
```

Check which release is bundled:

```r
attr(dmd_master, "dmd_release_label")
#> [1] "Week 34 2025 (14 August 2025)"
```

---

## Using a more recent release

If you have the NHSBSA dm+d extract tool (`dmdDataLoader`), you can load a
newer release. The expected directory layout is:

```
dmdDataLoader/
└── csv/
    ├── f_vmp_VmpType.csv
    ├── f_vmpp_VmppType.csv
    ├── f_vmpp_DtInfoType.csv
    ├── f_ampp_AmppType.csv
    ├── f_ampp_PriceInfoType.csv
    ├── f_lookup_DtPayCatInfoType.csv
    └── f_lookup_PriceBasisInfoType.csv
```

```r
db <- dmd_load("path/to/dmdDataLoader")
#> ✔ dm+d database loaded at 2026-02-19 12:00
#> • 23 720 VMPs  |  35 706 VMPPs  |  106 292 AMPPs
#> • 8 799 Drug Tariff prices  |  106 292 NHS Indicative Prices

dmd_price_lookup("metformin", db = db)
```

Set a project-wide default path in `.Rprofile` to avoid repeating it:

```r
options(dmdprices.path = "~/dmdDataLoader")
# Then: dmd_load() with no arguments
```

---

## Output columns

| Column | Description |
|---|---|
| `Medicine` | VMP (generic) name |
| `Pack size` | Numeric pack quantity |
| `Unit` | Unit of measure (tablet, ml, capsule, …) |
| `VMP Snomed Code` | VMP SNOMED CT identifier |
| `VMPP Snomed Code` | VMPP SNOMED CT identifier |
| `Drug Tariff Category` | e.g. "Part VIIIA Category M" |
| `Basic Price` | Drug Tariff basic price (pence) |
| `NHS Indicative Price` | NHS Indicative Price (pence) |
| `Price Basis` | Basis of NHS Indicative Price |
| `Price Date` | Date of NHS Indicative Price |
| `AMPP Name` | Branded pack name |
| `AMPP Snomed Code` | AMPP SNOMED CT identifier |

Prices are in **pence**, matching the Drug Tariff CSV convention. One row is
returned per branded pack (AMPP); the `Basic Price` (Drug Tariff) is the same
for all brands of the same VMPP.

---

## Data attribution

The `dmd_master` dataset is derived from the **NHS Dictionary of Medicines and
Devices (dm+d)**, Week 34 2025 release (14 August 2025).

Published by the **NHS Business Services Authority (NHSBSA)**.

© Crown copyright. Licensed under the
[Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).

The dm+d is available from the NHSBSA TRUD service:
<https://isd.digital.nhs.uk/trud/users/guest/filters/0/categories/6>

---

## Development

```r
# Install dependencies
devtools::install_deps()

# Regenerate documentation
devtools::document()

# Run tests
devtools::test()

# Rebuild bundled data after a new dm+d release
# (edit dmd_loader_path in data-raw/dmd_master.R first)
source("data-raw/dmd_master.R")
```
