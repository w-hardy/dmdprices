# Fake dmd_db used by dose-optimisation tests. Covers:
# - two strengths of one preparation (metformin 500mg / 1000mg tablets)
# - a modified-release variant at different prices
# - an oral solution with mg/ml concentration
# - a solution-for-injection ampoule
# - a strength with NA basic_price but a nhs_indicative_price (fallback)
# - a concentration vial whose strength_canonical is a repeating decimal
#   (Rituximab 1400mg/11.7ml) to regression-test the per_item_dose fix
#
# `loaded_at` defaults to a fixed timestamp so print/format methods and any
# whole-<dmd_db> output can be snapshot-tested deterministically.
.fixed_loaded_at <- as.POSIXct("2025-08-08 09:00:00", tz = "UTC")

.fake_dose_db <- function(loaded_at = .fixed_loaded_at) {
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
      "Morphine 10mg/1ml solution for injection ampoules",
      "Rituximab 1400mg/11.7ml solution for injection",
      "Rituximab 500mg/50ml solution for infusion",
      "Rituximab 100mg/10ml solution for infusion"
    ),
    pack_size = c(28, 28, 28, 56, 28, 28, 100, 100, 10, 1, 1, 1),
    unit = c(
      "tablet",
      "tablet",
      "tablet",
      "tablet",
      "tablet",
      "tablet",
      "ml",
      "ml",
      "ml",
      "vial",
      "vial",
      "vial"
    ),
    vmp_snomed_code = as.character(seq_len(12)),
    vmpp_snomed_code = paste0("VPP", seq_len(12)),
    drug_tariff_category = rep("Part VIIIA Category M", 12),
    basic_price = c(
      100L,
      110L,
      180L,
      400L,
      420L,
      NA_integer_,
      300L,
      500L,
      250L,
      1344600L,
      476700L,
      87500L
    ),
    nhs_indicative_price = c(
      105L,
      120L,
      190L,
      410L,
      440L,
      95L,
      310L,
      510L,
      260L,
      1344600L,
      476700L,
      87500L
    ),
    price_basis = rep("NHS Indicative Price", 12),
    price_date = rep("2025-08-08", 12),
    ampp_name = c(
      "Metformin 500mg (Brand A) 28 tablet",
      "Metformin 500mg (Brand B) 28 tablet",
      "Metformin 1000mg (Brand A) 28 tablet",
      "Metformin 500mg MR (Brand A) 56 tablet",
      "Metformin 1000mg MR (Brand A) 28 tablet",
      "Metformin 100mg (Brand C) 28 tablet",
      "Morphine Oral Solution 10mg/5ml (Brand A) 100 ml",
      "Morphine Oral Solution 20mg/5ml (Brand A) 100 ml",
      "Morphine 10mg/1ml Solution for Injection 10 ml",
      "MabThera 1400mg/11.7ml solution for injection 11.7ml vial",
      "Rituximab 500mg/50ml solution for infusion 50ml vial",
      "Rituximab 100mg/10ml solution for infusion 10ml vial"
    ),
    ampp_snomed_code = paste0("APP", seq_len(12))
  )
  structure(list(master = master, loaded_at = loaded_at), class = "dmd_db")
}

# Fake dmd_db carrying ingredient (VPI) data, for combination dose-targeting
# tests. Two co-codamol combination strengths plus a single-ingredient codeine
# tablet — all containing codeine — and an `$ingredients` table giving each
# VMP's per-ingredient strengths.
.fake_ingredient_db <- function(loaded_at = .fixed_loaded_at) {
  master <- tibble::tibble(
    medicine = c(
      "Co-codamol 8mg/500mg tablets",
      "Co-codamol 30mg/500mg tablets",
      "Codeine phosphate 30mg tablets"
    ),
    pack_size = c(32, 30, 28),
    unit = c("tablet", "tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2", "V3"),
    vmpp_snomed_code = c("VPP1", "VPP2", "VPP3"),
    drug_tariff_category = rep("Part VIIIA Category M", 3),
    basic_price = c(100L, 200L, 150L),
    nhs_indicative_price = c(105L, 205L, 160L),
    price_basis = rep("NHS Indicative Price", 3),
    price_date = rep("2025-08-08", 3),
    ampp_name = c(
      "Co-codamol 8mg/500mg 32 tablet",
      "Co-codamol 30mg/500mg 30 tablet",
      "Codeine phosphate 30mg 28 tablet"
    ),
    ampp_snomed_code = c("APP1", "APP2", "APP3"),
    is_combination = c(TRUE, TRUE, FALSE)
  )
  ingredients <- tibble::tibble(
    vmp_snomed_code = c("V1", "V1", "V2", "V2", "V3"),
    ingredient_snomed_code = c(
      "I_cod", "I_para", "I_cod", "I_para", "I_cod"
    ),
    ingredient_name = c(
      "Codeine phosphate", "Paracetamol",
      "Codeine phosphate", "Paracetamol",
      "Codeine phosphate"
    ),
    strength_value = c(8, 500, 30, 500, 30),
    strength_unit = c("mg", "mg", "mg", "mg", "mg"),
    denominator_value = NA_real_,
    denominator_unit = NA_character_,
    strength_canonical = c(8, 500, 30, 500, 30),
    strength_unit_canon = c("mg", "mg", "mg", "mg", "mg")
  )
  structure(
    list(
      master = master,
      ingredients = ingredients,
      loaded_at = loaded_at
    ),
    class = "dmd_db"
  )
}
