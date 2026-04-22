library(dmdprices)

# Fake dmd_db used by dose-optimisation tests. Covers:
# - two strengths of one preparation (metformin 500mg / 1000mg tablets)
# - a modified-release variant at different prices
# - an oral solution with mg/ml concentration
# - a solution-for-injection ampoule
# - a strength with NA basic_price but a nhs_indicative_price (fallback)
.fake_dose_db <- function() {
  master <- tibble::tibble(
    medicine = c(
      "Metformin 500mg tablets",
      "Metformin 500mg tablets",
      "Metformin 1000mg tablets",
      "Metformin 500mg modified-release tablets",
      "Metformin 1000mg modified-release tablets",
      "Metformin 100mg tablets",
      "Morphine 10mg/5ml oral solution",
      "Morphine 20mg/5ml oral solution",
      "Morphine 10mg/1ml solution for injection ampoules"
    ),
    pack_size = c(28, 28, 28, 56, 28, 28, 100, 100, 10),
    unit = c("tablet", "tablet", "tablet", "tablet", "tablet", "tablet",
             "ml", "ml", "ml"),
    vmp_snomed_code = as.character(seq_len(9)),
    vmpp_snomed_code = paste0("VPP", seq_len(9)),
    drug_tariff_category = rep("Part VIIIA Category M", 9),
    basic_price = c(100L, 110L, 180L, 400L, 420L, NA_integer_,
                    300L, 500L, 250L),
    nhs_indicative_price = c(105L, 120L, 190L, 410L, 440L, 95L,
                             310L, 510L, 260L),
    price_basis = rep("NHS Indicative Price", 9),
    price_date = rep("2025-08-08", 9),
    ampp_name = c(
      "Metformin 500mg (Brand A) 28 tablet",
      "Metformin 500mg (Brand B) 28 tablet",
      "Metformin 1000mg (Brand A) 28 tablet",
      "Metformin 500mg MR (Brand A) 56 tablet",
      "Metformin 1000mg MR (Brand A) 28 tablet",
      "Metformin 100mg (Brand C) 28 tablet",
      "Morphine Oral Solution 10mg/5ml (Brand A) 100 ml",
      "Morphine Oral Solution 20mg/5ml (Brand A) 100 ml",
      "Morphine 10mg/1ml Solution for Injection 10 ml"
    ),
    ampp_snomed_code = paste0("APP", seq_len(9))
  )
  structure(list(master = master, loaded_at = Sys.time()), class = "dmd_db")
}
