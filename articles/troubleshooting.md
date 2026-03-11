# Troubleshooting

## Common problems and solutions

``` r
library(dmdprices)
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
library(stringr)
```

------------------------------------------------------------------------

## “My medicine is not found”

### Symptom

``` r
dmd_price_lookup("aspirin")
# Returns 0 rows, or wrong medicine
```

### Diagnosis

**Step 1: Try different match methods**

``` r
# Method 1: Exact (strict)
exact <- dmd_price_lookup("aspirin 75mg tablets", method = "exact")
nrow(exact)
#> [1] 9

# Method 2: Partial (forgiving)
partial <- dmd_price_lookup("aspirin 75mg", method = "partial")
nrow(partial)
#> [1] 54

# Method 3: Fuzzy (typo-tolerant)
fuzzy <- dmd_price_lookup("aspirin 75mg tablets", method = "fuzzy", max_dist = 3)
nrow(fuzzy)
#> [1] 19
```

**Step 2: Check the exact dm+d name**

dm+d names follow a strict format: `Medicine Strength Unit`

``` r
# Search for similar names
dmd_price_lookup("aspirin", method = "partial") |>
  select(medicine) |>
  distinct()
#> # A tibble: 35 × 1
#>    medicine                         
#>    <chr>                            
#>  1 Aspirin 100mg/5ml oral solution  
#>  2 Aspirin 100mg/5ml oral suspension
#>  3 Aspirin 150mg suppositories      
#>  4 Aspirin 15mg/5ml oral solution   
#>  5 Aspirin 15mg/5ml oral suspension 
#>  6 Aspirin 225mg/5ml oral solution  
#>  7 Aspirin 225mg/5ml oral suspension
#>  8 Aspirin 25mg capsules            
#>  9 Aspirin 25mg/5ml oral solution   
#> 10 Aspirin 25mg/5ml oral suspension 
#> # ℹ 25 more rows
```

**Step 3: Verify strength and unit**

``` r
# You might be using non-standard strength notation
# Try with different formats:
# - "75mg" vs "75 mg"
# - "tablet" vs "tablets"
# - Full strength name vs abbreviation

test_names <- c(
  "aspirin 75mg tablets",
  "aspirin 75 mg tablet",
  "aspirin 75mg",
  "Aspirin"
)

results <- lapply(test_names, dmd_price_lookup, method = "fuzzy", max_dist = 3)
#> Warning: No medicines found matching "aspirin 75mg" with method
#> = "fuzzy".
#> Warning: No medicines found matching "Aspirin" with method =
#> "fuzzy".
names(results) <- test_names

# Show which worked
working <- sapply(results, nrow) > 0
working
#> aspirin 75mg tablets aspirin 75 mg tablet         aspirin 75mg 
#>                 TRUE                 TRUE                FALSE 
#>              Aspirin 
#>                FALSE
```

### Solutions

**If the medicine genuinely doesn’t exist:**

1.  **It might be delisted** — Check older versions of dm+d (use
    [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md))
2.  **It might be brand-new** — Wait for next weekly dm+d update
3.  **It might use a different name** — Search for therapeutic
    equivalent
4.  **It’s very new or specialty** — Check NHSBSA TRUD directly

**If it exists but you can’t find it:**

- Use `method = "fuzzy"` with `max_dist = 3` to be more permissive
- Remove pack size and try again:
  `dmd_price_lookup("aspirin", method = "partial")`
- Try the brand name vs generic name
- Check for hyphenation: “co-amoxiclav” vs “coamoxiclav”

------------------------------------------------------------------------

## “There is no price for this medicine”

### Symptom

``` r
result <- dmd_price_lookup("vaccine")
result$basic_price  # All NA
```

### Diagnosis

Many medicines have no Drug Tariff or NHS Indicative prices. Common
reasons:

``` r
# Check which medicines have NO price at all
no_price <- dmd_master |>
  filter(is.na(basic_price) & is.na(nhs_indicative_price))

nrow(no_price)
#> [1] 13900

# These are typically centrally procured or specialty medicines
sample_no_price <- no_price |>
  select(medicine) |>
  slice(1:5)

sample_no_price
#> # A tibble: 5 × 1
#>   medicine                                                                  
#>   <chr>                                                                     
#> 1 Generic Kilkof oral solution                                              
#> 2 Mirikizumab 200mg/2ml solution for injection pre-filled disposable devices
#> 3 Ciprofloxacin 200mg/100ml infusion polyethylene bottles                   
#> 4 Ciprofloxacin 400mg/200ml infusion polyethylene bottles                   
#> 5 Moxifloxacin 400mg/250ml infusion polyethylene bottles
```

### Common reasons for missing prices

| Reason                           | Examples                       | Solution                      |
|----------------------------------|--------------------------------|-------------------------------|
| **Centrally procured**           | Vaccines, infusions, biologics | Contact NHS procurement       |
| **Specialty/rare disease**       | Some cancer drugs              | Price via NICE/special scheme |
| **Confidential price agreement** | Some biosimilars               | Contact supplier              |
| **Recently added**               | Brand new medicine             | Check back next month         |
| **About to be delisted**         | Obsolete/replaced              | Use therapeutic equivalent    |

### Solutions

**If you need a price:**

``` r
# Option 1: Use NHS Indicative instead of Drug Tariff
result <- dmd_price_lookup("medicine", active_only = FALSE)
#> Warning: No medicines found matching "medicine" with method =
#> "partial".

# Try to use NHS Indicative
price <- result$nhs_indicative_price

# Option 2: Search for therapeutic equivalent
# If Medicine A has no price, find Medicine B (same class)
equivalent <- dmd_price_lookup("similar_medicine", method = "fuzzy")
#> Warning: No medicines found matching "similar_medicine" with
#> method = "fuzzy".

# Option 3: Record as "missing" in your analysis
# and document why
missing_price_medicines <- c("vaccine", "specialty_biologic")
```

**For analysis:**

``` r
# Decide upfront how to handle missing prices
analysis <- dmd_master |>
  mutate(
    analysis_price = case_when(
      !is.na(basic_price) ~ basic_price,
      !is.na(nhs_indicative_price) ~ nhs_indicative_price,
      TRUE ~ NA_real_
    ),
    price_status = case_when(
      !is.na(analysis_price) ~ "Available",
      TRUE ~ "Missing"
    )
  )

# Report this clearly
analysis |>
  count(price_status)
#> # A tibble: 2 × 2
#>   price_status      n
#>   <chr>         <int>
#> 1 Available    104296
#> 2 Missing       13900
```

------------------------------------------------------------------------

## “Why is the price different from Drug Tariff?”

### Symptom

Drug Tariff says £1.50, but dmdprices shows £1.45

### Diagnosis

Prices update monthly; the bundled data is ~2-4 weeks old.

``` r
# Check when the bundled data was released
attr(dmd_master, "dmd_release_label")
#> [1] "Week 34 2025 (14 August 2025)"
```

### Solutions

**For time-sensitive work:**

1.  **Load the latest dm+d** with
    [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
2.  **Download Drug Tariff CSV** from NHSBSA directly
3.  **Check the price_date** column for NHS Indicative

**For academic/reproducible work:**

1.  Document which release you used
2.  Lock the version in your code/environment
3.  Include release date in your methodology

------------------------------------------------------------------------

## “My lookup is very slow”

### Symptom

``` r
# Takes many seconds for each lookup
for (med in 1000_medicines) {
  dmd_price_lookup(med)  # Slow!
}
```

### Diagnosis

[`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md)
searches the entire dm+d for each call. With 1000+ medicines, this
accumulates.

### Solutions

**Option 1: Pre-filter before searching**

``` r
# Instead of searching for each medicine individually,
# get all matches once and filter
all_statins <- dmd_price_lookup("statin", method = "partial")
atorvastatin_20mg <- all_statins |>
  filter(str_detect(medicine, "Atorvastatin 20mg"))
```

**Option 2: Use batch processing**

``` r
medicines <- c("medicine1", "medicine2", ..., "medicine1000")

# Vectorized (faster than loop)
results <- lapply(medicines, dmd_price_lookup, method = "exact")
results_df <- bind_rows(results)
```

**Option 3: Cache results**

``` r
# Save lookup results to avoid re-searching
if (!file.exists("medicine_cache.rds")) {
  medicine_cache <- lapply(
    unique(medicines),
    dmd_price_lookup,
    method = "fuzzy"
  )
  saveRDS(medicine_cache, "medicine_cache.rds")
} else {
  medicine_cache <- readRDS("medicine_cache.rds")
}
```

------------------------------------------------------------------------

## “Why is fuzzy matching giving weird results?”

### Symptom

``` r
# Searching for common medicine gives unrelated results
dmd_price_lookup("atorvastatin", method = "fuzzy", max_dist = 5)
```

### Diagnosis

`max_dist` is the maximum character distance (Levenshtein distance).
Higher values are too permissive.

### Solutions

**Use stricter `max_dist`:**

``` r
# Too permissive (max_dist = 5)
loose <- dmd_price_lookup("atorvastatin", method = "fuzzy", max_dist = 5)
#> Warning: No medicines found matching "atorvastatin" with method
#> = "fuzzy".

# Better (max_dist = 2)
strict <- dmd_price_lookup("atorvastatin", method = "fuzzy", max_dist = 2)
#> Warning: No medicines found matching "atorvastatin" with method
#> = "fuzzy".

nrow(strict)
#> [1] 0
```

**Recommended `max_dist` values:**

| max_dist | Use case                           |
|----------|------------------------------------|
| 0-1      | Very strict; only obvious typos    |
| 2-3      | **Recommended** for most use       |
| 4-5      | Only if you have very messy data   |
| \>5      | Don’t use (too many false matches) |

------------------------------------------------------------------------

## “How do I know if dm+d has been updated?”

### Symptom

You’re unsure whether you have the latest medicine data.

### Solution

**Check the bundled release date:**

``` r
# Shows when this data was released
attr(dmd_master, "dmd_release_label")
#> [1] "Week 34 2025 (14 August 2025)"
```

**Check NHSBSA TRUD:**

    https://isd.digital.nhs.uk/trud/users/guest/filters/0/categories/6

(Updated every Thursday)

**If more than 3 weeks old, reload:**

``` r
# If you have the dmdDataLoader CSV files
new_dm_d <- dmd_load("~/path/to/dmdDataLoader")

# Or wait for next package update
```

------------------------------------------------------------------------

## “I’m getting errors when inflating costs”

### Symptom

``` r
nhscii("2025/26", "2026/27")  # Error: from_year not in available range
```

### Diagnosis

NHS CII rates are only available for specific financial years (currently
2015/16–2023/24).

### Solutions

**Check available years:**

``` r
# Valid range
nhscii("2015/16", "2015/16")  # Returns 1 (valid)
#> [1] 1

# Invalid year
# nhscii("2024/25", "2025/26")  # Would error
```

**Wait for updates:**

The 2024/25 rates will be published in the PSSRU 2025 manual (likely
late 2024).

**For future years, use estimates:**

``` r
# Use latest available rate as proxy
latest_rate <- nhscii("2022/23", "2023/24", output_type = "percent")

# Simple projection: assume same rate continues
projected_2024_25_rate <- latest_rate  # Placeholder

# Use in calculation
nhscii("2023/24", "2023/24") * (1 + projected_2024_25_rate / 100)
```

------------------------------------------------------------------------

## “How do I report which data I used?”

### Solution

Create a reproducibility statement:

``` r
# Capture metadata
analysis_metadata <- list(
  analysis_date = Sys.Date(),
  
  dmd = list(
    source = "NHS dm+d (bundled)",
    release = attr(dmd_master, "dmd_release_label")
  ),
  
  prices = list(
    source = "Drug Tariff + NHS Indicative",
    priority = "Drug Tariff, fallback to Indicative"
  ),
  
  inflation = list(
    source = "PSSRU Unit Costs",
    doi = "10.22024/UniKent/01.02.109563",
    coverage = "2015/16 to 2023/24"
  ),
  
  package = list(
    name = "dmdprices",
    version = as.character(packageVersion("dmdprices"))
  )
)

# Include in your report
str(analysis_metadata)
#> List of 5
#>  $ analysis_date: Date[1:1], format: "2026-03-11"
#>  $ dmd          :List of 2
#>   ..$ source : chr "NHS dm+d (bundled)"
#>   ..$ release: chr "Week 34 2025 (14 August 2025)"
#>  $ prices       :List of 2
#>   ..$ source  : chr "Drug Tariff + NHS Indicative"
#>   ..$ priority: chr "Drug Tariff, fallback to Indicative"
#>  $ inflation    :List of 3
#>   ..$ source  : chr "PSSRU Unit Costs"
#>   ..$ doi     : chr "10.22024/UniKent/01.02.109563"
#>   ..$ coverage: chr "2015/16 to 2023/24"
#>  $ package      :List of 2
#>   ..$ name   : chr "dmdprices"
#>   ..$ version: chr "0.3.0"
```

**Sample text for your methodology:**

> Medicine prices were obtained from the NHS dm+d (Week 34 2025) via the
> dmdprices R package. Drug Tariff prices (pence) were used where
> available; NHS Indicative prices were used as fallback. Historical
> costs were adjusted to 2023/24 prices using the NHS Cost Inflation
> Index (PSSRU Unit Costs of Health and Social Care, 2023).

------------------------------------------------------------------------

## “I found a bug. What do I do?”

### Before reporting

1.  **Check data freshness** — Load latest dm+d with
    [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
2.  **Try a different match method** — exact vs partial vs fuzzy
3.  **Check the official sources** — Confirm price on NHSBSA TRUD

### How to report

Report issues on the GitHub repository:  
📍 <https://github.com/w-hardy/dmdprices/issues>

Include: - What you were trying to do - What you expected - What
actually happened - Example code that reproduces the issue - Your
dmdprices version: `packageVersion("dmdprices")`

------------------------------------------------------------------------

## Getting help

**In R:**

``` r
?dmd_price_lookup     # Function help
?nhscii               # NHS CII help

# Browse vignettes
vignette("dmdprices")
browseVignettes("dmdprices")
```

**Documentation:**

- [`vignette("drug_tariff_matching")`](https://w-hardy.github.io/dmdprices/articles/drug_tariff_matching.md)
  — Understanding prices
- [`vignette("cost_analysis_workflows")`](https://w-hardy.github.io/dmdprices/articles/cost_analysis_workflows.md)
  — Using prices in analysis
- [`vignette("data_sources_updates")`](https://w-hardy.github.io/dmdprices/articles/data_sources_updates.md)
  — Where data comes from
- [`vignette("advanced_matching")`](https://w-hardy.github.io/dmdprices/articles/advanced_matching.md)
  — Complex matching scenarios

**External resources:**

- NHSBSA Drug Tariff:
  <https://www.nhsbsa.nhs.uk/pharmacies-gp-practices-and-appliance-contractors/drug-tariff>
- dm+d on TRUD: <https://isd.digital.nhs.uk/trud>
- PSSRU Unit Costs: <https://www.pssru.ac.uk/project-pages/unit-costs/>
