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
# whole-<dmd_db> output can be snapshot-tested deterministically. It is
# display-only: the dose-candidate cache keys on the content of `$master`, so
# fixtures can share this timestamp without sharing cached results (#30).
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

# Fake dmd_db reproducing issue #23: a closed sublingual-tablet family whose
# strengths (0.2 / 0.4 / 2 / 8 mg) can build 3 mg exactly, while for a 3 mg
# request an over-delivering 4 mg build (2 x 2mg, 200p) is strictly cheaper than
# any exact build (400p), one 8 mg tablet is strictly fewest-items, and 11 mg is
# strictly dearest. Every objective therefore used to skip the exact 3 mg
# answer. Likewise a 0.4 mg request is under-cut by a single 2 mg tablet.
.fake_sublingual_db <- function(loaded_at = .fixed_loaded_at) {
  master <- tibble::tibble(
    medicine = c(
      "Buprenorphine 200microgram sublingual tablets sugar free",
      "Buprenorphine 400microgram sublingual tablets sugar free",
      "Buprenorphine 2mg sublingual tablets sugar free",
      "Buprenorphine 8mg sublingual tablets sugar free"
    ),
    pack_size = c(7, 7, 7, 7),
    unit = rep("tablet", 4),
    vmp_snomed_code = paste0("V", 1:4),
    vmpp_snomed_code = paste0("VPP", 1:4),
    drug_tariff_category = rep("Part VIIIA Category M", 4),
    # Per tablet: 0.2mg = 60p, 0.4mg = 200p, 2mg = 100p, 8mg = 700p.
    basic_price = c(420L, 1400L, 700L, 4900L),
    nhs_indicative_price = c(420L, 1400L, 700L, 4900L),
    price_basis = rep("NHS Indicative Price", 4),
    price_date = rep("2025-08-08", 4),
    ampp_name = c(
      "Buprenorphine 200microgram sublingual 7 tablet",
      "Buprenorphine 400microgram sublingual 7 tablet",
      "Buprenorphine 2mg sublingual 7 tablet",
      "Buprenorphine 8mg sublingual 7 tablet"
    ),
    ampp_snomed_code = paste0("APP", 1:4)
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

# Fake dmd_db for authoritative-combination tests (#8). Carries:
# - a dm+d-flagged combination whose NAME reads as a single strength (the
#   allergen-mix / factor-concentrate shape) plus its VPI ingredient rows;
# - a multi-strength "X and Y" pack name that dm+d does NOT flag, which the
#   name heuristic must keep skipping;
# - an ordinary single-ingredient tablet that must keep optimising.
.fake_flagged_combo_db <- function(loaded_at = .fixed_loaded_at) {
  master <- tibble::tibble(
    medicine = c(
      "Allergen mix 500micrograms/ml solution for skin prick test",
      "Testdrug 50mg tablets and Testdrug 100mg tablets",
      "Plaindrug 250mg tablets"
    ),
    pack_size = c(10, 60, 28),
    unit = c("ml", "tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2", "V3"),
    vmpp_snomed_code = c("VPP1", "VPP2", "VPP3"),
    drug_tariff_category = rep("Part VIIIA Category M", 3),
    basic_price = c(1200L, 900L, 150L),
    nhs_indicative_price = c(1200L, 900L, 150L),
    price_basis = rep("NHS Indicative Price", 3),
    price_date = rep("2025-08-08", 3),
    ampp_name = c(
      "Allergen mix skin prick test 10 ml",
      "Testdrug 50mg and 100mg 60 tablet",
      "Plaindrug 250mg 28 tablet"
    ),
    ampp_snomed_code = c("APP1", "APP2", "APP3"),
    is_combination = c(TRUE, FALSE, FALSE)
  )
  ingredients <- tibble::tibble(
    vmp_snomed_code = c("V1", "V1"),
    ingredient_snomed_code = c("I_grass", "I_tree"),
    ingredient_name = c("Grass pollen extract", "Tree pollen extract"),
    strength_value = c(300, 200),
    strength_unit = c("microgram", "microgram"),
    denominator_value = c(1, 1),
    denominator_unit = c("ml", "ml"),
    strength_canonical = c(0.3, 0.2),
    strength_unit_canon = c("mg/ml", "mg/ml")
  )
  structure(
    list(master = master, ingredients = ingredients, loaded_at = loaded_at),
    class = "dmd_db"
  )
}

# Fake dmd_db for container-pack pricing. Concentration preparations sold as
# packs of several containers (10 pre-filled syringes, 5 ampoules) alongside a
# single-container pack (one multidose vial) and an inhaler whose pack quantity
# is in the concentration's own denominator unit ("dose"), so that one item is
# one whole inhaler. Prices in pence:
# - 40 mg/0.4 ml syringes: pack of 10 at 3000  -> 300 per syringe
# - 20 mg/0.2 ml syringes: pack of 10 at 2000  -> 200 per syringe
# - 300 mg/3 ml multidose vial: pack of 1 at 2500
# - 100 microgram/dose inhaler: 200 doses (20 mg) at 150, one container
# - 500 microgram/1 ml ampoules: pack of 5 at 190 -> 38 per ampoule
.fake_container_pack_db <- function(loaded_at = .fixed_loaded_at) {
  master <- tibble::tibble(
    medicine = c(
      "Enoxaparin sodium 40mg/0.4ml solution for injection pre-filled syringes",
      "Enoxaparin sodium 20mg/0.2ml solution for injection pre-filled syringes",
      "Enoxaparin sodium 300mg/3ml solution for injection multidose vials",
      "Salbutamol 100micrograms/dose inhaler CFC free",
      "Salbutamol 500micrograms/1ml solution for injection ampoules"
    ),
    pack_size = c(10, 10, 1, 200, 5),
    unit = c(
      "pre-filled disposable injection",
      "pre-filled disposable injection",
      "vial",
      "dose",
      "ampoule"
    ),
    vmp_snomed_code = paste0("V", 1:5),
    vmpp_snomed_code = paste0("VPP", 1:5),
    drug_tariff_category = rep("Part VIIIA Category C", 5),
    basic_price = c(3000L, 2000L, 2500L, 150L, 190L),
    nhs_indicative_price = c(3000L, 2000L, 2500L, 150L, 190L),
    price_basis = rep("NHS Indicative Price", 5),
    price_date = rep("2025-08-08", 5),
    ampp_name = c(
      "Enoxaparin 40mg/0.4ml pre-filled syringes 10 pre-filled disposable injection",
      "Enoxaparin 20mg/0.2ml pre-filled syringes 10 pre-filled disposable injection",
      "Enoxaparin 300mg/3ml multidose vials 1 vial",
      "Salbutamol 100micrograms/dose inhaler 200 dose",
      "Salbutamol 500micrograms/1ml ampoules 5 ampoule"
    ),
    ampp_snomed_code = c("APP_SYR40", "APP_SYR20", "APP_VIAL300", "APP_INH", "APP_AMP")
  )
  structure(list(master = master, loaded_at = loaded_at), class = "dmd_db")
}

# Fake dmd_db for #27: names that carry more than one strength token. Names
# are real dm+d VMP names; rows and prices are fake.
# - eptacog alfa: a mass strength restated in activity units in brackets, as
#   1 / 2 / 5 mg syringes at 500 / 1000 / 2500 pence (a flat 500p per mg);
# - iohexol: a per-ml strength with the iodine content in brackets, a
#   competing same-dimension basis, so it stays skipped as a compound;
# - a titration pack and a co-pack, which stay skipped as multi-product packs.
.fake_multi_strength_db <- function(loaded_at = .fixed_loaded_at) {
  master <- tibble::tibble(
    medicine = c(
      "Eptacog alfa (activated) 1mg (50,000unit) powder and solvent for solution for injection pre-filled syringes",
      "Eptacog alfa (activated) 2mg (100,000unit) powder and solvent for solution for injection pre-filled syringes",
      "Eptacog alfa (activated) 5mg (250,000unit) powder and solvent for solution for injection pre-filled syringes",
      "Iohexol 755mg/ml (Iodine 350mg/ml) solution for injection 50ml bottles",
      "Danicopan 50mg tablets and Danicopan 100mg tablets",
      "Tixagevimab 150mg/1.5ml solution for injection vials and Cilgavimab 150mg/1.5ml solution for injection vials"
    ),
    pack_size = c(1, 1, 1, 10, 84, 1),
    unit = c(
      "pre-filled disposable injection",
      "pre-filled disposable injection",
      "pre-filled disposable injection",
      "bottle",
      "tablet",
      "pack"
    ),
    vmp_snomed_code = paste0("V", 1:6),
    vmpp_snomed_code = paste0("VPP", 1:6),
    drug_tariff_category = rep("Part VIIIA Category M", 6),
    basic_price = c(500L, 1000L, 2500L, 30000L, 900L, 1000L),
    nhs_indicative_price = c(500L, 1000L, 2500L, 30000L, 900L, 1000L),
    price_basis = rep("NHS Indicative Price", 6),
    price_date = rep("2025-08-08", 6),
    ampp_name = paste("Fake AMPP", 1:6),
    ampp_snomed_code = paste0("APP", 1:6),
    is_combination = rep(FALSE, 6)
  )
  structure(list(master = master, loaded_at = loaded_at), class = "dmd_db")
}

# Fake dmd_db for the per-item dose of concentration products sold as one
# container whose pack quantity is in a unit with a non-unit canonical factor
# (g -> mg, litre -> ml): .fake_dose_db() plus two one-container rows and a VPI
# table for the cream.
#   Delgocitinib 20mg/g cream, 60 g tube at 1000p      -> 1200 mg per tube
#   Examplol 5mg/ml oral solution, 1 litre at 2000p    -> 5000 mg per bottle
.fake_per_gram_db <- function(loaded_at = .fixed_loaded_at) {
  db <- .fake_dose_db(loaded_at = loaded_at)
  db$master <- rbind(
    db$master,
    tibble::tibble(
      medicine = c(
        "Delgocitinib 20mg/g cream",
        "Examplol 5mg/ml oral solution"
      ),
      pack_size = c(60, 1),
      unit = c("g", "litre"),
      vmp_snomed_code = c("V_DELGO", "V_EXAMPLOL"),
      vmpp_snomed_code = c("VPP_DELGO", "VPP_EXAMPLOL"),
      drug_tariff_category = rep("Part VIIIA Category C", 2),
      basic_price = c(1000L, 2000L),
      nhs_indicative_price = c(1000L, 2000L),
      price_basis = rep("NHS Indicative Price", 2),
      price_date = rep("2025-08-08", 2),
      ampp_name = c(
        "Delgocitinib 20mg/g cream (Brand A) 60 gram",
        "Examplol 5mg/ml oral solution (Brand A) 1 litre"
      ),
      ampp_snomed_code = c("APP_DELGO", "APP_EXAMPLOL")
    )
  )
  # VPI shape as in the bundled dmd_ingredients: raw numerator and denominator
  # fields, plus the canonical columns in the one convention (canonical
  # numerator per one canonical denominator unit).
  db$ingredients <- tibble::tibble(
    vmp_snomed_code = "V_DELGO",
    ingredient_snomed_code = "I_delgo",
    ingredient_name = "Delgocitinib",
    strength_value = 20,
    strength_unit = "mg",
    denominator_value = 1,
    denominator_unit = "g",
    strength_canonical = 0.02,
    strength_unit_canon = "mg/mg"
  )
  db
}

# Fake dmd_db for the unit handling of the ingredient-targeting path:
# .fake_dose_db() (its two rituximab infusion vials get VPI rows) plus products
# whose VPI denominator or pack unit has a non-unit canonical factor (g, litre)
# or no canonical form at all (hour). Names without a parseable strength stand
# for products the parser cannot dose (percentage strengths, no strength
# token), so ingredient targeting is their only route. The VPI table is in the
# dmd_ingredients shape, its canonical columns in the one convention: canonical
# numerator per one canonical denominator unit, slash form.
#   Rituximab 500mg/50ml and 100mg/10ml vials: VPI 10 mg per 1 ml
#     -> 500 and 100 mg per vial (the container volume comes from the name)
#   Azythro 15mg/g eye drops, 6 unit doses at 699p: VPI 15 mg per 1 g
#     -> 15 mg per unit dose (one stated denominator, 1 g)
#   Exsaline 0.9% infusion, 10 bags: VPI 9 g per 1 litre -> 9000 mg per bag
#   Exspirit cutaneous solution, 200 ml: VPI 5 ml per 1 litre -> 1 ml per bottle
#   Exornithine powder, 100 g: VPI 1 mg per 1 mg -> 100000 mg per tub
#   Exoxygen medical gas, 2130 litre: VPI 1 ml per 1 ml -> 2130000 ml
#   Expatch transdermal patches, 4 patches: VPI 5 microgram per 1 hour
#     -> no mass dose (the denominator has no canonical unit)
.fake_vpi_units_db <- function(loaded_at = .fixed_loaded_at) {
  db <- .fake_dose_db(loaded_at = loaded_at)
  db$master <- rbind(
    db$master,
    tibble::tibble(
      medicine = c(
        "Azythro 15mg/g eye drops 0.25g unit dose preservative free",
        "Exsaline 0.9% infusion bags",
        "Exsaline 0.9% infusion 500ml bags",
        "Exsaline 0.9% infusion 1litre bags",
        "Exspirit cutaneous solution",
        "Exornithine powder",
        "Exoxygen medical gas",
        "Expatch transdermal patches",
        "Expatch radio injection vials"
      ),
      pack_size = c(6, 10, 10, 10, 200, 100, 2130, 4, 1),
      unit = c(
        "unit dose", "bag", "bag", "bag", "ml", "g", "litre", "patch", "vial"
      ),
      vmp_snomed_code = c(
        "V_AZY", "V_SAL", "V_SAL5", "V_SAL1", "V_SPI", "V_ORN", "V_OXY",
        "V_PAT", "V_RAD"
      ),
      vmpp_snomed_code = c(
        "VPP_AZY", "VPP_SAL", "VPP_SAL5", "VPP_SAL1", "VPP_SPI", "VPP_ORN",
        "VPP_OXY", "VPP_PAT", "VPP_RAD"
      ),
      drug_tariff_category = rep("Part VIIIA Category C", 9),
      basic_price = c(
        699L, 1890L, 1890L, 3000L, 300L, 6292L, 1000L, 2000L, 5000L
      ),
      nhs_indicative_price = c(
        699L, 1890L, 1890L, 3000L, 300L, 6292L, 1000L, 2000L, 5000L
      ),
      price_basis = rep("NHS Indicative Price", 9),
      price_date = rep("2025-08-08", 9),
      ampp_name = c(
        "Azythro 15mg/g eye drops 6 unit dose",
        "Exsaline 0.9% infusion 10 bag",
        "Exsaline 0.9% infusion 500ml 10 bag",
        "Exsaline 0.9% infusion 1litre 10 bag",
        "Exspirit cutaneous solution 200 ml",
        "Exornithine powder 100 gram",
        "Exoxygen medical gas 2130 litre",
        "Expatch transdermal patches 4 patch",
        "Expatch radio injection 1 vial"
      ),
      ampp_snomed_code = c(
        "APP_AZY", "APP_SAL", "APP_SAL5", "APP_SAL1", "APP_SPI", "APP_ORN",
        "APP_OXY", "APP_PAT", "APP_RAD"
      )
    )
  )
  # The last two rows share an ingredient whose strength cannot be dosed by
  # mass: per hour for the patch, and in GBq for the radio injection.
  db$ingredients <- tibble::tibble(
    vmp_snomed_code = c(
      "11", "12", "V_AZY", "V_SAL", "V_SAL5", "V_SAL1", "V_SPI", "V_ORN",
      "V_OXY", "V_PAT", "V_RAD"
    ),
    ingredient_snomed_code = c(
      "I_rit", "I_rit", "I_azy", "I_nacl", "I_nacl", "I_nacl", "I_msal",
      "I_orn", "I_oxy", "I_pat", "I_pat"
    ),
    ingredient_name = c(
      "Rituximab", "Rituximab", "Azythro substance", "Sodium chloride",
      "Sodium chloride", "Sodium chloride", "Methyl salicylate", "Ornithine",
      "Oxygen", "Expatchine", "Expatchine"
    ),
    strength_value = c(10, 10, 15, 9, 9, 9, 5, 1, 1, 5, 5),
    strength_unit = c(
      "mg", "mg", "mg", "g", "g", "g", "ml", "mg", "ml", "microgram", "GBq"
    ),
    denominator_value = rep(1, 11),
    denominator_unit = c(
      "ml", "ml", "g", "litre", "litre", "litre", "litre", "mg", "ml", "hour",
      "ml"
    ),
    strength_canonical = c(
      10, 10, 0.015, 9, 9, 9, 0.005, 1, 1, NA_real_, NA_real_
    ),
    strength_unit_canon = c(
      "mg/ml", "mg/ml", "mg/mg", "mg/ml", "mg/ml", "mg/ml", "ml/ml", "mg/mg",
      "ml/ml", NA_character_, NA_character_
    )
  )
  db
}

# Fake dmd_db for products whose number of doses per pack is unknown: the
# strength is per dose or actuation but the pack is measured in ml or g, or
# the pack and the strength are in different physical units. Names are real
# dm+d VMP names (apart from Covivax); rows and prices are fake. Beside them,
# the packs whose dose count IS known and must keep costing:
#   Salbutamol 100micrograms/dose inhaler, 200 dose      -> one 20 mg container
#   Fluticasone 50micrograms/dose nasal spray, 150 dose  -> one 7.5 mg container
#   Benzydamine 150micrograms/dose oromucosal spray, 30 dose -> one 4.5 mg container
#   Morphine 10mg/5ml oral solution, 100 ml              -> one 200 mg bottle
#   Delgocitinib 20mg/g cream, 60 g                      -> one 1200 mg tube
#   Salbutamol 500micrograms/1ml ampoules, 5 ampoule     -> five 0.5 mg items
#   Covivax 30micrograms/0.3ml dose vials, 10 dose       -> ten 0.03 mg items
#   Tiotropium 18micrograms/dose capsules, 30 capsule    -> thirty 0.018 mg items
# Two rows only the ingredient path can classify: Nicospray (no strength in
# its name; VPI 1 mg per 1 dose, 13.2 ml) and Oilatine 5mg/ml lotion (parsed
# per ml, one 250 ml bottle; VPI 5 mg per 1 g, which the ml pack cannot count).
# Lidocaine 100mg lozenges (fake; 20 at 400p) sit beside the lidocaine spray so
# a preparation filter can exclude the spray.
# VPI rows cover nicotine (1 mg per 1 dose, both sprays), lidocaine (10 mg per
# 1 actuation), the salbutamol inhaler (100 microgram per 1 dose) and oilatine.
.fake_dose_count_db <- function(loaded_at = .fixed_loaded_at) {
  master <- tibble::tibble(
    medicine = c(
      "Nicotine 1mg/dose oromucosal spray sugar free",
      "Nicotine 1mg/dose oromucosal spray sugar free",
      "Lidocaine 10mg/dose spray sugar free",
      "Ispaghula husk 3.5g/dose effervescent granules gluten free sugar free",
      "Flurbiprofen 2.92mg/actuation oromucosal spray sugar free",
      "Clobetasol 500micrograms/g shampoo",
      "Salbutamol 100micrograms/dose inhaler CFC free",
      "Fluticasone 50micrograms/dose nasal spray",
      "Benzydamine 150micrograms/dose oromucosal spray sugar free",
      "Morphine 10mg/5ml oral solution",
      "Delgocitinib 20mg/g cream",
      "Salbutamol 500micrograms/1ml solution for injection ampoules",
      "Covivax 30micrograms/0.3ml dose suspension for injection multidose vials",
      "Tiotropium 18micrograms/dose inhalation powder capsules",
      "Nicospray oromucosal spray",
      "Oilatine 5mg/ml lotion",
      "Lidocaine 100mg lozenges"
    ),
    pack_size = c(
      13.2, 26.4, 50, 300, 15, 125, 200, 150, 30, 100, 60, 5, 10, 30, 13.2, 250,
      20
    ),
    unit = c(
      "ml", "ml", "ml", "g", "ml", "ml",
      "dose", "dose", "dose", "ml", "g", "ampoule", "dose", "capsule",
      "ml", "ml", "lozenge"
    ),
    vmp_snomed_code = c(
      "V_NIC", "V_NIC", "V_LID", "V_ISP", "V_FLU", "V_CLO",
      "V_INH", "V_NAS", "V_BEN", "V_MOR", "V_DEL", "V_AMP", "V_VAC", "V_CAP",
      "V_NSP", "V_OIL", "V_LOZ"
    ),
    vmpp_snomed_code = paste0("VPP", seq_len(17)),
    drug_tariff_category = rep("Part VIIIA Category C", 17),
    basic_price = c(
      1497L, 2329L, 629L, 800L, 500L, 1000L,
      150L, 300L, 400L, 300L, 1000L, 190L, 500L, 2000L, 1200L, 700L, 400L
    ),
    nhs_indicative_price = c(
      1497L, 2329L, 629L, 800L, 500L, 1000L,
      150L, 300L, 400L, 300L, 1000L, 190L, 500L, 2000L, 1200L, 700L, 400L
    ),
    price_basis = rep("NHS Indicative Price", 17),
    price_date = rep("2025-08-08", 17),
    ampp_name = c(
      "Nicorette QuickMist 1mg/dose mouthspray 13.2 ml",
      "Nicorette QuickMist 1mg/dose mouthspray 26.4 ml",
      "Xylocaine 10mg/dose spray 50 ml",
      "Ispaghula husk 3.5g/dose effervescent granules 300 gram",
      "Strefen Direct oromucosal spray 15 ml",
      "Clobetasol 500micrograms/g shampoo 125 ml",
      "Salbutamol 100micrograms/dose inhaler 200 dose",
      "Fluticasone 50micrograms/dose nasal spray 150 dose",
      "Benzydamine 150micrograms/dose oromucosal spray 30 dose",
      "Morphine 10mg/5ml oral solution 100 ml",
      "Delgocitinib 20mg/g cream 60 gram",
      "Salbutamol 500micrograms/1ml ampoules 5 ampoule",
      "Covivax multidose vials 10 dose",
      "Tiotropium 18micrograms/dose capsules 30 capsule",
      "Nicospray mouthspray 13.2 ml",
      "Oilatine lotion 250 ml",
      "Lidocaine 100mg lozenges 20 lozenge"
    ),
    ampp_snomed_code = paste0("APP", seq_len(17))
  )
  ingredients <- tibble::tibble(
    vmp_snomed_code = c("V_NIC", "V_LID", "V_INH", "V_NSP", "V_OIL"),
    ingredient_snomed_code = c("I_nic", "I_lid", "I_sal", "I_nic", "I_oil"),
    ingredient_name = c(
      "Nicotine", "Lidocaine", "Salbutamol", "Nicotine", "Oilatine"
    ),
    strength_value = c(1, 10, 100, 1, 5),
    strength_unit = c("mg", "mg", "microgram", "mg", "mg"),
    denominator_value = c(1, 1, 1, 1, 1),
    denominator_unit = c("dose", "actuation", "dose", "dose", "g"),
    strength_canonical = c(1, 10, 0.1, 1, 0.005),
    strength_unit_canon = c(
      "mg/dose", "mg/actuation", "mg/dose", "mg/dose", "mg/mg"
    )
  )
  structure(
    list(master = master, ingredients = ingredients, loaded_at = loaded_at),
    class = "dmd_db"
  )
}

# Fake dmd_db for the solver's grid semantics: one 1 mg strength, so every
# dose with a decimal part sits off the strengths' integer grid.
#   Testdrug 1mg tablets, 100 at 900p (9p each) and 10 at 100p (10p each)
#   Testdrug 1mg/1ml solution for injection vials, 10 at 1000p (100p each)
#   Testdrug 5mg/5ml solution for injection vials, 1 at 450p
.fake_grid_db <- function(loaded_at = .fixed_loaded_at) {
  master <- tibble::tibble(
    medicine = c(
      "Testdrug 1mg tablets",
      "Testdrug 1mg tablets",
      "Testdrug 1mg/1ml solution for injection vials",
      "Testdrug 5mg/5ml solution for injection vials"
    ),
    pack_size = c(100, 10, 10, 1),
    unit = c("tablet", "tablet", "vial", "vial"),
    vmp_snomed_code = c("V_TAB", "V_TAB", "V_VIAL1", "V_VIAL5"),
    vmpp_snomed_code = paste0("VPP", 1:4),
    drug_tariff_category = rep("Part VIIIA Category M", 4),
    basic_price = c(900L, 100L, 1000L, 450L),
    nhs_indicative_price = c(900L, 100L, 1000L, 450L),
    price_basis = rep("NHS Indicative Price", 4),
    price_date = rep("2025-08-08", 4),
    ampp_name = c(
      "Testdrug 1mg 100 tablet",
      "Testdrug 1mg 10 tablet",
      "Testdrug 1mg/1ml vials 10 vial",
      "Testdrug 5mg/5ml vials 1 vial"
    ),
    ampp_snomed_code = paste0("APP", 1:4)
  )
  structure(list(master = master, loaded_at = loaded_at), class = "dmd_db")
}

# Start a test with an empty dose-candidate cache (the memo and its remembered
# table key) and empty it again when the test ends, so nothing cached carries
# over between tests. Call it first in any test whose outcome depends on what
# the cache holds.
.local_fresh_dose_cache <- function(env = parent.frame()) {
  .forget_dose_cache()
  withr::defer(.forget_dose_cache(), envir = env)
  invisible()
}

# A group whose strengths the capped dose table cannot represent: 0.125 mg and
# 1 mg need a scale of 1000, but a 6000.125 mg dose caps it at 833, where
# 0.125 mg is 104.125 units. Two preparations (tablets, capsules) so that a
# call can drop more than one group.
.fake_unresolvable_db <- function(loaded_at = .fixed_loaded_at) {
  master <- tibble::tibble(
    medicine = c(
      "Finedrug 125microgram tablets",
      "Finedrug 1mg tablets",
      "Finedrug 125microgram capsules",
      "Finedrug 1mg capsules"
    ),
    pack_size = rep(28, 4),
    unit = c("tablet", "tablet", "capsule", "capsule"),
    vmp_snomed_code = paste0("V", 1:4),
    vmpp_snomed_code = paste0("VPP", 1:4),
    drug_tariff_category = rep("Part VIIIA Category M", 4),
    basic_price = c(100L, 900L, 110L, 950L),
    nhs_indicative_price = c(100L, 900L, 110L, 950L),
    price_basis = rep("NHS Indicative Price", 4),
    price_date = rep("2025-08-08", 4),
    ampp_name = paste(
      "Finedrug",
      c("125microgram", "1mg", "125microgram", "1mg"),
      "28",
      c("tablet", "tablet", "capsule", "capsule")
    ),
    ampp_snomed_code = paste0("APP", 1:4)
  )
  structure(list(master = master, loaded_at = loaded_at), class = "dmd_db")
}

# Evaluate `expr` with its warnings muffled and return its value together with
# the warning conditions and their messages, so tests can count and match them.
.with_warnings <- function(expr) {
  conditions <- list()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      conditions[[length(conditions) + 1L]] <<- w
      invokeRestart("muffleWarning")
    }
  )
  list(
    value = value,
    conditions = conditions,
    warnings = vapply(conditions, conditionMessage, character(1))
  )
}

# Fake dmd_db for the amount of drug per container (name-parsed path). A
# container-count pack of a concentration is dosed per container only when the
# name states the container's size: as a bare token in the denominator's
# dimension ("0.3ml unit dose", "2.4ml pre-filled disposable devices", "500ml
# bags"), or as an explicit numeric strength denominator ("10mg/1ml"). An
# implicit "per ml" with no token ("10mg/ml ... ampoules") has no known amount.
#   Dexamethasone 1.5mg/ml eye drops 0.3ml unit dose          -> 0.45 mg per unit
#   Tirzepatide 12.5mg/0.6ml ... 2.4ml pre-filled devices    -> 50 mg per device
#   Glucotest 50mg/ml solution for infusion 500ml bags       -> 25,000 mg per bag
#   Morphine 10mg/1ml solution for injection ampoules        -> 10 mg per ampoule
#   Morphine 10mg/ml solution for injection ampoules         -> unknown (skipped)
#   Morphine 10mg/5ml oral solution, 100 ml                  -> 200 mg bottle (pack)
#   Immunotest 2.5g/25ml vials and Hyalutest 1.25ml vials    -> 2,500 mg (own phrase)
#   Lidotest 10mg/ml ... ampoules 1/2 strength               -> unknown ("/2" is no denominator)
#   Semaglutest 0.25mg/0.37ml ... 1.5ml devices              -> 1.0135 mg (off the solver grid)
#   Aflitest 4mg/100microlitres vials                        -> 4 mg per vial
#   Heparitest 5,000units/1litre infusion bags               -> 5,000 units per bag
#   Mixtest 1mg/1ml, 2mg/2ml and 0.25mg/0.37ml 1.5ml vials   -> 1, 2 and 1.0135 mg
.fake_container_amount_db <- function(loaded_at = .fixed_loaded_at) {
  master <- tibble::tibble(
    medicine = c(
      "Dexamethasone 1.5mg/ml eye drops 0.3ml unit dose preservative free",
      "Tirzepatide 12.5mg/0.6ml solution for injection 2.4ml pre-filled disposable devices",
      "Glucotest 50mg/ml solution for infusion 500ml bags",
      "Morphine 10mg/1ml solution for injection ampoules",
      "Morphine 10mg/ml solution for injection ampoules",
      "Morphine 10mg/5ml oral solution",
      "Immunotest 2.5g/25ml solution for infusion vials and Hyalutest solution for infusion 1.25ml vials",
      "Lidotest 10mg/ml solution for injection ampoules 1/2 strength",
      "Semaglutest 0.25mg/0.37ml solution for injection 1.5ml pre-filled disposable devices",
      "Aflitest 4mg/100microlitres solution for injection vials",
      "Heparitest 5,000units/1litre infusion bags",
      "Mixtest 1mg/1ml solution for injection vials",
      "Mixtest 2mg/2ml solution for injection vials",
      "Mixtest 0.25mg/0.37ml solution for injection 1.5ml vials"
    ),
    pack_size = c(30, 4, 10, 10, 10, 100, 1, 10, 4, 1, 10, 1, 1, 1),
    unit = c(
      "unit dose", "pre-filled disposable injection", "bag", "ampoule",
      "ampoule", "ml", "vial", "ampoule",
      "pre-filled disposable injection", "vial", "bag", "vial", "vial", "vial"
    ),
    vmp_snomed_code = c(
      "V_DEX", "V_TIR", "V_GLU", "V_MOR1", "V_MOR0", "V_MORO",
      "V_IMM", "V_LID", "V_SEM", "V_AFL", "V_HEP", "V_MIX1", "V_MIX2",
      "V_MIX0"
    ),
    vmpp_snomed_code = paste0("VPP", seq_len(14)),
    drug_tariff_category = rep("Part VIIIA Category C", 14),
    basic_price = c(
      600L, 40000L, 2000L, 450L, 500L, 300L, 17250L, 500L, 29300L, 81600L,
      1000L, 1000L, 1500L, 2000L
    ),
    nhs_indicative_price = c(
      600L, 40000L, 2000L, 450L, 500L, 300L, 17250L, 500L, 29300L, 81600L,
      1000L, 1000L, 1500L, 2000L
    ),
    price_basis = rep("NHS Indicative Price", 14),
    price_date = rep("2025-08-08", 14),
    ampp_name = c(
      "Dexamethasone 1.5mg/ml eye drops 30 unit dose",
      "Tirzepatide 12.5mg/0.6ml 4 pre-filled disposable injection",
      "Glucotest 50mg/ml infusion 500ml 10 bag",
      "Morphine 10mg/1ml ampoules 10 ampoule",
      "Morphine 10mg/ml ampoules 10 ampoule",
      "Morphine 10mg/5ml oral solution 100 ml",
      "Immunotest 2.5g/25ml and Hyalutest 1.25ml 1 vial",
      "Lidotest 10mg/ml ampoules 10 ampoule",
      "Semaglutest 0.25mg/0.37ml 4 pre-filled disposable injection",
      "Aflitest 4mg/100microlitres 1 vial",
      "Heparitest 5,000units/1litre 10 bag",
      "Mixtest 1mg/1ml 1 vial",
      "Mixtest 2mg/2ml 1 vial",
      "Mixtest 0.25mg/0.37ml 1.5ml 1 vial"
    ),
    ampp_snomed_code = paste0("APP", seq_len(14))
  )
  structure(list(master = master, loaded_at = loaded_at), class = "dmd_db")
}
