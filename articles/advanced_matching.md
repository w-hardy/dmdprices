# Advanced Matching Techniques

## Overview

The basic
[`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md)
function supports three match methods: `"partial"`, `"exact"`, and
`"fuzzy"`. This vignette covers advanced techniques for difficult
matching scenarios.

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

## The three built-in methods

### 1. Partial matching (default)

Matches any medicine name containing all your search terms,
case-insensitive.

``` r
# Very forgiving
dmd_price_lookup("metformin", method = "partial")
#> # A tibble: 271 × 12
#>    medicine                     pack_size unit  vmp_snomed_code vmpp_snomed_code
#>    <chr>                            <dbl> <chr> <chr>           <chr>           
#>  1 Alogliptin 12.5mg / Metform…        56 tabl… 23637211000001… 236325110000011…
#>  2 Alogliptin 12.5mg / Metform…        56 tabl… 23637211000001… 236325110000011…
#>  3 Alogliptin 12.5mg / Metform…        56 tabl… 23637211000001… 236325110000011…
#>  4 Canagliflozin 50mg / Metfor…        60 tabl… 28049211000001… 280241110000011…
#>  5 Canagliflozin 50mg / Metfor…        60 tabl… 28049311000001… 280222110000011…
#>  6 Dapagliflozin 5mg / Metform…        56 tabl… 24054611000001… 240184110000011…
#>  7 Dapagliflozin 5mg / Metform…        56 tabl… 24054611000001… 240184110000011…
#>  8 Dapagliflozin 5mg / Metform…        56 tabl… 24054711000001… 240180110000011…
#>  9 Empagliflozin 12.5mg / Metf…        56 tabl… 30318111000001… 301756110000011…
#> 10 Empagliflozin 12.5mg / Metf…        60 tabl… 30318111000001… 378531110000011…
#> # ℹ 261 more rows
#> # ℹ 7 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>
```

**Use when:** - You don’t know the exact name - You want all related
products - Searching broad categories

### 2. Exact matching

Requires the full VMP (Virtual Medicinal Product) name.

``` r
# Strict—must match the canonical dm+d name exactly
dmd_price_lookup("Metformin 500mg tablets", method = "exact")
#> # A tibble: 49 × 12
#>    medicine                pack_size unit   vmp_snomed_code   vmpp_snomed_code
#>    <chr>                       <dbl> <chr>  <chr>             <chr>           
#>  1 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  2 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  3 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  4 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  5 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  6 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  7 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  8 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  9 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#> 10 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#> # ℹ 39 more rows
#> # ℹ 7 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>
```

**Use when:** - You have clean, standardized data - You want to avoid
false matches - Building reproducible workflows

### 3. Fuzzy matching

Uses Levenshtein distance to tolerate typos and minor variations.

``` r
# Tolerates ~2-3 character differences
dmd_price_lookup("metformin 500 mg tabets", method = "fuzzy", max_dist = 3)
#> # A tibble: 49 × 12
#>    medicine                pack_size unit   vmp_snomed_code   vmpp_snomed_code
#>    <chr>                       <dbl> <chr>  <chr>             <chr>           
#>  1 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  2 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  3 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  4 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  5 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  6 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  7 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  8 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#>  9 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#> 10 Metformin 500mg tablets        28 tablet 42084911000001109 1320811000001101
#> # ℹ 39 more rows
#> # ℹ 7 more variables: drug_tariff_category <chr>, basic_price <int>,
#> #   nhs_indicative_price <int>, price_basis <chr>, price_date <chr>,
#> #   ampp_name <chr>, ampp_snomed_code <chr>
```

**Parameters:** - `max_dist`: Maximum character distance (default 2) -
Lower = stricter (fewer false matches) - Higher = more permissive
(catches typos)

## Advanced scenario 1: Matching branded to generic names

You have a list of branded products but need generic (VMP) prices.

``` r
# Branded product name from prescriptions
branded_medicines <- c(
  "Glucophage (Metformin 500mg tablets)",
  "Lisinopril 10mg tablets (various)",
  "Atorvastatin 20mg tablets (Actavis)"
)

# Extract the core medicine (parentheses are noise)
core_names <- str_extract(branded_medicines, "^[^(]+")  # Text before (
core_names <- str_trim(core_names)

# Look up the generic VMP
results <- lapply(core_names, function(med) {
  dmd_price_lookup(med, method = "fuzzy", max_dist = 3)
})
#> Warning: No medicines found matching "Glucophage" with method =
#> "fuzzy".

# Extract the canonical VMP names
vmp_names <- sapply(results, function(r) {
  if (nrow(r) > 0) r$medicine[[1]] else NA_character_
})

vmp_names
#> [1] NA                          "Fosinopril 10mg tablets"  
#> [3] "Atorvastatin 10mg tablets"
```

## Advanced scenario 2: Standardizing supplier codes to medicines

You have internal supplier codes and need to match to dm+d.

``` r
# Internal mapping table
supplier_codes <- data.frame(
  supplier_code = c("SUPP001", "SUPP002", "SUPP003"),
  our_name = c(
    "paracetamol 500mg",
    "ibuprofen 200mg",
    "aspirin 75mg"
  )
)

# Match using fuzzy matching
supplier_codes <- supplier_codes |>
  mutate(
    dmd_match = sapply(our_name, function(med) {
      result <- dmd_price_lookup(med, method = "fuzzy", max_dist = 3)
      if (nrow(result) > 0) result$medicine[[1]] else NA_character_
    }),
    dmd_price_pence = sapply(our_name, function(med) {
      result <- dmd_price_lookup(med, method = "fuzzy", max_dist = 3)
      if (nrow(result) > 0) result$basic_price[[1]] else NA_real_
    })
  )
#> Warning: There were 6 warnings in `mutate()`.
#> The first warning was:
#> ℹ In argument: `dmd_match = sapply(...)`.
#> Caused by warning:
#> ! No medicines found matching "paracetamol 500mg" with method = "fuzzy".
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 5 remaining warnings.

supplier_codes
#>   supplier_code          our_name dmd_match dmd_price_pence
#> 1       SUPP001 paracetamol 500mg      <NA>              NA
#> 2       SUPP002   ibuprofen 200mg      <NA>              NA
#> 3       SUPP003      aspirin 75mg      <NA>              NA
```

## Advanced scenario 3: Batch processing with quality checks

Processing many medicines and tracking which matched poorly.

``` r
# Large medicine list (simulated)
medicine_list <- c(
  "Metformin 500mg tablets",
  "Lisinopril 10mg tablets",
  "Amlodipine 5mg tablets",
  "Fluoxetine 20mg capsules",
  "Omeprazole 20mg capsules",
  "xyz_fake_medicine"  # Will fail to match
)

# Batch lookup with error handling
batch_results <- data.frame(
  input_name = medicine_list,
  matched_vmp = NA_character_,
  price_pence = NA_real_,
  match_confidence = NA_character_,
  matched = NA
)

for (i in seq_along(medicine_list)) {
  result <- dmd_price_lookup(
    medicine_list[i],
    method = "fuzzy",
    max_dist = 3
  )
  
  if (nrow(result) > 0) {
    batch_results$matched_vmp[i] <- result$medicine[[1]]
    batch_results$price_pence[i] <- result$basic_price[[1]]
    batch_results$match_confidence[i] <- "High"  # fuzzy matched
    batch_results$matched[i] <- TRUE
  } else {
    batch_results$matched[i] <- FALSE
  }
}
#> Warning: No medicines found matching "Omeprazole 20mg capsules"
#> with method = "fuzzy".
#> Warning: No medicines found matching "xyz_fake_medicine" with
#> method = "fuzzy".

batch_results
#>                 input_name              matched_vmp price_pence
#> 1  Metformin 500mg tablets  Metformin 500mg tablets          58
#> 2  Lisinopril 10mg tablets  Fosinopril 10mg tablets         511
#> 3   Amlodipine 5mg tablets  Amlodipine 10mg tablets          62
#> 4 Fluoxetine 20mg capsules Fluoxetine 10mg capsules         466
#> 5 Omeprazole 20mg capsules                     <NA>          NA
#> 6        xyz_fake_medicine                     <NA>          NA
#>   match_confidence matched
#> 1             High    TRUE
#> 2             High    TRUE
#> 3             High    TRUE
#> 4             High    TRUE
#> 5             <NA>   FALSE
#> 6             <NA>   FALSE
```

**Quality report:**

``` r
batch_results |>
  summarise(
    total_medicines = n(),
    matched = sum(matched, na.rm = TRUE),
    unmatched = sum(!matched, na.rm = TRUE),
    match_rate = paste0(round(100 * mean(matched), 1), "%")
  )
#>   total_medicines matched unmatched match_rate
#> 1               6       4         0       400%
```

## Advanced scenario 4: Handling strength/form ambiguity

A medicine exists in multiple strengths; you need the right one.

``` r
# Partial search returns all strengths
all_atorvastatin <- dmd_price_lookup("atorvastatin", method = "partial")

all_atorvastatin |>
  select(medicine, pack_size, unit, basic_price) |>
  slice(1:6)  # Show first 6
#> # A tibble: 6 × 4
#>   medicine                                      pack_size unit   basic_price
#>   <chr>                                             <dbl> <chr>        <int>
#> 1 Atorvastatin 10mg chewable tablets sugar free        30 tablet        1380
#> 2 Atorvastatin 10mg tablets                            28 tablet          55
#> 3 Atorvastatin 10mg tablets                            28 tablet          55
#> 4 Atorvastatin 10mg tablets                            28 tablet          55
#> 5 Atorvastatin 10mg tablets                            28 tablet          55
#> 6 Atorvastatin 10mg tablets                            28 tablet          55
```

**Filter to the strength you want:**

``` r
# You specifically want 20mg tablets
target <- all_atorvastatin |>
  filter(
    str_detect(medicine, "20mg"),
    str_detect(medicine, "tablets")
  )

target |>
  select(medicine, basic_price)
#> # A tibble: 29 × 2
#>    medicine                                      basic_price
#>    <chr>                                               <int>
#>  1 Atorvastatin 20mg chewable tablets sugar free        2640
#>  2 Atorvastatin 20mg tablets                              62
#>  3 Atorvastatin 20mg tablets                              62
#>  4 Atorvastatin 20mg tablets                              62
#>  5 Atorvastatin 20mg tablets                              62
#>  6 Atorvastatin 20mg tablets                              62
#>  7 Atorvastatin 20mg tablets                              62
#>  8 Atorvastatin 20mg tablets                              62
#>  9 Atorvastatin 20mg tablets                              62
#> 10 Atorvastatin 20mg tablets                              62
#> # ℹ 19 more rows
```

## Advanced scenario 5: Tracking price changes

Look up the same medicine over time with version control.

``` r
# Suppose you've recorded metformin prices monthly
# (This is simulated; in reality you'd load old dm+d versions)
price_history <- data.frame(
  month = c(
    "2023-01", "2023-02", "2023-03",
    "2024-01", "2024-02", "2024-03"
  ),
  price_pence = c(
    145, 147, 148,
    152, 155, 158
  )
)

# Add pence-to-pound conversion
price_history <- price_history |>
  mutate(price_pounds = price_pence / 100)

price_history
#>     month price_pence price_pounds
#> 1 2023-01         145         1.45
#> 2 2023-02         147         1.47
#> 3 2023-03         148         1.48
#> 4 2024-01         152         1.52
#> 5 2024-02         155         1.55
#> 6 2024-03         158         1.58
```

**Calculate month-on-month change:**

``` r
price_history <- price_history |>
  mutate(
    previous_price = lag(price_pence),
    change_pence = price_pence - previous_price,
    pct_change = round(100 * (change_pence / previous_price), 2),
    .after = price_pence
  )

price_history |>
  select(month, price_pence, change_pence, pct_change)
#>     month price_pence change_pence pct_change
#> 1 2023-01         145           NA         NA
#> 2 2023-02         147            2       1.38
#> 3 2023-03         148            1       0.68
#> 4 2024-01         152            4       2.70
#> 5 2024-02         155            3       1.97
#> 6 2024-03         158            3       1.94
```

## Advanced scenario 6: Fuzzy matching with manual review

For critical systems, allow fuzzy matches but flag for review.

``` r
# Function: fuzzy match with confidence scoring
fuzzy_match_scored <- function(medicine_name, db = dmd_master, max_dist = 2) {
  result <- dmd_price_lookup(medicine_name, method = "fuzzy", max_dist = max_dist, db = db)
  
  if (nrow(result) == 0) {
    return(data.frame(
      input = medicine_name,
      matched = FALSE,
      vmp_name = NA_character_,
      price = NA_real_,
      requires_review = TRUE,
      reason = "No match found"
    ))
  }
  
  # Flag if multiple matches or high Levenshtein distance
  requires_review <- nrow(result) > 1 || max_dist > 2
  
  data.frame(
    input = medicine_name,
    matched = TRUE,
    vmp_name = result$medicine[[1]],
    price = result$basic_price[[1]],
    requires_review = requires_review,
    reason = if (nrow(result) > 1) "Multiple matches" else "Fuzzy match"
  )
}

# Test
test_medicines <- c(
  "Metformin 500mg tablets",
  "paracetmol 500mg",  # Typo
  "xyz_fake"
)

matches <- lapply(test_medicines, fuzzy_match_scored) |>
  bind_rows()
#> Warning: No medicines found matching "paracetmol 500mg" with
#> method = "fuzzy".
#> Warning: No medicines found matching "xyz_fake" with method =
#> "fuzzy".

matches
#>                     input matched                vmp_name price requires_review
#> 1 Metformin 500mg tablets    TRUE Metformin 500mg tablets    58            TRUE
#> 2        paracetmol 500mg   FALSE                    <NA>    NA            TRUE
#> 3                xyz_fake   FALSE                    <NA>    NA            TRUE
#>             reason
#> 1 Multiple matches
#> 2   No match found
#> 3   No match found
```

**Filter for review:**

``` r
matches |>
  filter(requires_review | !matched) |>
  select(input, matched, reason)
#>                     input matched           reason
#> 1 Metformin 500mg tablets    TRUE Multiple matches
#> 2        paracetmol 500mg   FALSE   No match found
#> 3                xyz_fake   FALSE   No match found
```

## Advanced scenario 7: Partial matching with results filtering

Use partial search but filter results intelligently.

``` r
# You want all ibuprofen products, but not creams/gels
all_ibuprofen <- dmd_price_lookup("ibuprofen", method = "partial")

# Filter to oral forms only
oral_ibuprofen <- all_ibuprofen |>
  filter(
    unit %in% c("tablet", "capsule", "liquid", "suspension"),
    !str_detect(str_to_lower(medicine), "cream|gel|topical|ointment")
  )

oral_ibuprofen |>
  select(medicine, pack_size, unit, basic_price) |>
  arrange(medicine)
#> # A tibble: 177 × 4
#>    medicine                                          pack_size unit  basic_price
#>    <chr>                                                 <dbl> <chr>       <int>
#>  1 Ibuprofen 100mg chewable capsules                        12 caps…         385
#>  2 Ibuprofen 200mg / Codeine 12.8mg tablets                 16 tabl…          NA
#>  3 Ibuprofen 200mg / Codeine 12.8mg tablets                 24 tabl…         634
#>  4 Ibuprofen 200mg / Codeine 12.8mg tablets                 32 tabl…         806
#>  5 Ibuprofen 200mg / Codeine 12.8mg tablets                 32 tabl…         806
#>  6 Ibuprofen 200mg / Phenylephrine 5mg tablets              16 tabl…          NA
#>  7 Ibuprofen 200mg / Pseudoephedrine hydrochloride …        12 tabl…         339
#>  8 Ibuprofen 200mg / Pseudoephedrine hydrochloride …        24 tabl…         521
#>  9 Ibuprofen 200mg capsules                                 10 caps…          NA
#> 10 Ibuprofen 200mg capsules                                 12 caps…          NA
#> # ℹ 167 more rows
```

## Best practices for difficult matches

### 1. Always define your matching logic upfront

``` r
matching_rules <- list(
  method = "fuzzy",           # Use fuzzy for typo tolerance
  max_dist = 2,               # Strict but reasonable
  exclude_patterns = c(
    "cream", "gel",           # Exclude topicals
    "injection",              # Only interested in oral
    "solution"
  ),
  include_only = c(
    "tablets", "capsules",
    "suspension", "liquid"
  )
)
```

### 2. Document match quality in your results

``` r
# Add a "match_quality" column
quality_results <- batch_results |>
  mutate(
    match_quality = case_when(
      !matched ~ "unmatched",
      is.na(price_pence) ~ "no_price",
      TRUE ~ "good"
    ),
    .after = matched
  )

quality_results
#>                 input_name              matched_vmp price_pence
#> 1  Metformin 500mg tablets  Metformin 500mg tablets          58
#> 2  Lisinopril 10mg tablets  Fosinopril 10mg tablets         511
#> 3   Amlodipine 5mg tablets  Amlodipine 10mg tablets          62
#> 4 Fluoxetine 20mg capsules Fluoxetine 10mg capsules         466
#> 5 Omeprazole 20mg capsules                     <NA>          NA
#> 6        xyz_fake_medicine                     <NA>          NA
#>   match_confidence matched match_quality
#> 1             High    TRUE          good
#> 2             High    TRUE          good
#> 3             High    TRUE          good
#> 4             High    TRUE          good
#> 5             <NA>   FALSE     unmatched
#> 6             <NA>   FALSE     unmatched
```

### 3. Log unmatched items for investigation

``` r
unmatched_log <- batch_results |>
  filter(!matched) |>
  mutate(
    investigated = FALSE,
    notes = NA_character_
  ) |>
  select(input_name, investigated, notes)

# Save for manual review
write.csv(unmatched_log, "unmatched_medicines_review.csv", row.names = FALSE)
```

### 4. Test on a small sample first

``` r
# Before processing thousands, validate on 20-30
test_sample <- head(medicine_list, 10)
test_results <- lapply(test_sample, dmd_price_lookup, method = "fuzzy")
# Review results manually before proceeding
```

## Comparing match methods

``` r
test_name <- "metformin 500 mg"

# Exact
exact <- dmd_price_lookup(test_name, method = "exact")
#> Warning: No medicines found matching "metformin 500 mg" with
#> method = "exact".
cat("Exact:", nrow(exact), "results\n")
#> Exact: 0 results

# Partial
partial <- dmd_price_lookup(test_name, method = "partial")
#> Warning: No medicines found matching "metformin 500 mg" with
#> method = "partial".
cat("Partial:", nrow(partial), "results\n")
#> Partial: 0 results

# Fuzzy
fuzzy <- dmd_price_lookup(test_name, method = "fuzzy", max_dist = 2)
#> Warning: No medicines found matching "metformin 500 mg" with
#> method = "fuzzy".
cat("Fuzzy:", nrow(fuzzy), "results\n")
#> Fuzzy: 0 results
```

## Performance tips

For large batches (1000+ medicines):

``` r
# Use vectorized operations where possible
medicines <- c("medicine1", "medicine2", ..., "medicine1000")

# Faster: use sapply with built-in parallelization
system.time({
  results <- sapply(medicines, dmd_price_lookup, method = "exact")
})

# For very large batches, consider:
# 1. Splitting into chunks of 100-200
# 2. Using parallel::lapply() with multiple cores
# 3. Pre-filtering your list to remove obvious non-matches
```

## Further reading

- Basic usage:
  [`vignette("dmdprices")`](https://w-hardy.github.io/dmdprices/articles/dmdprices.md)
- Price reconciliation:
  [`vignette("drug_tariff_matching")`](https://w-hardy.github.io/dmdprices/articles/drug_tariff_matching.md)
- Troubleshooting:
  [`vignette("troubleshooting")`](https://w-hardy.github.io/dmdprices/articles/troubleshooting.md)
