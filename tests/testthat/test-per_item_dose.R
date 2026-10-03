# Per-item dose for concentration products sold as one container whose pack
# quantity is in a unit with a non-unit canonical factor (g -> mg, litre -> ml).
#
# Parsed names give strength_canonical per canonical denominator unit, so
# "20mg/g" is 0.02 mg per mg and a 60 g tube must count as 60000 mg, giving
# 1200 mg per tube (not 0.02 x 60 = 1.2 mg). VPI strengths used by ingredient
# targeting are stored per stated denominator (20 mg per 1 g), so that path
# keeps the raw pack quantity: 20 x 60 = 1200 mg.
#
# The fixture is .fake_dose_db() (helper.R) plus two one-container rows and a
# VPI table for the cream. Its `loaded_at` differs from the shared fixture's so
# the memoised candidate table is not reused across the two databases.
#   Delgocitinib 20mg/g cream, 60 g tube at 1000p      -> 1200 mg per tube
#   Examplol 5mg/ml oral solution, 1 litre at 2000p    -> 5000 mg per bottle

.fake_per_gram_db <- function(loaded_at = .fixed_loaded_at + 55) {
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
  # VPI shape as in the bundled dmd_ingredients: the numerator is canonical,
  # the denominator is as stated.
  db$ingredients <- tibble::tibble(
    vmp_snomed_code = "V_DELGO",
    ingredient_snomed_code = "I_delgo",
    ingredient_name = "Delgocitinib",
    strength_value = 20,
    strength_unit = "mg",
    denominator_value = 1,
    denominator_unit = "g",
    strength_canonical = 20,
    strength_unit_canon = "mg"
  )
  db
}

db <- .fake_per_gram_db()

# The enriched candidate table, without the session memo.
.per_gram_candidates <- function(query) {
  .dmd_prepare_candidates(
    query = query,
    db = db,
    method = "partial",
    max_dist = 3,
    active_only = TRUE,
    price = "basic_price"
  )
}

# ── Parsed-name path ─────────────────────────────────────────────────────────

test_that("a mass-per-gram cream sold as one tube is dosed per tube", {
  enriched <- .per_gram_candidates("Delgocitinib")
  expect_equal(enriched$per_item_dose, 1200)

  res <- dmd_dose_optimise(
    "Delgocitinib",
    dose = 1200,
    dose_unit = "mg",
    db = db,
    objective = "cheapest"
  )
  expect_equal(nrow(res), 1L)
  expect_true(res$dose_exact)
  expect_equal(res$total_items, 1)
  expect_equal(res$dose_cost_pence, 1000)
  combo <- res$combination[[1]]
  expect_equal(combo$ampp_snomed_code, "APP_DELGO")
  expect_equal(combo$count, 1L)
  expect_equal(combo$per_item_dose, 1200)
})

test_that("vectorised costs dose a per-gram tube per tube", {
  expect_equal(
    dmd_dose_cost(
      "Delgocitinib",
      dose = c(1200, 2400),
      dose_unit = "mg",
      db = db
    ),
    c(1000, 2000)
  )
})

test_that("a mg/ml solution in a 1-litre pack is dosed per litre", {
  enriched <- .per_gram_candidates("Examplol")
  expect_equal(enriched$per_item_dose, 5000)

  res <- dmd_dose_optimise(
    "Examplol",
    dose = 5000,
    dose_unit = "mg",
    db = db,
    objective = "cheapest"
  )
  expect_equal(nrow(res), 1L)
  expect_true(res$dose_exact)
  expect_equal(res$total_items, 1)
  expect_equal(res$dose_cost_pence, 2000)
})

test_that("a mg/ml bottle priced per ml is unchanged", {
  # 10mg/5ml and 20mg/5ml oral solutions in 100 ml bottles: 200 mg and 400 mg
  # per bottle; the ml pack quantity has a canonical factor of 1.
  enriched <- .per_gram_candidates("oral solution")
  enriched <- enriched[enriched$unit == "ml", , drop = FALSE]
  expect_equal(
    enriched$per_item_dose[order(enriched$medicine)],
    c(200, 400)
  )
})

# ── .per_item_dose() directly ────────────────────────────────────────────────

test_that(".per_item_dose() without one-container rows returns a numeric vector", {
  # A container-count vial and a tablet: no row takes the pack-quantity
  # branch, so the canonicalisation step must be skipped rather than assign
  # a zero-length mapply() result (a list) into the multiplier.
  enriched <- tibble::tibble(
    strength_canonical = c(10, 500),
    denominator_value = c(1, NA_real_),
    denominator_unit = c("ml", NA_character_),
    pack_size = c(5, 28),
    unit = c("vial", "tablet")
  )
  out <- .per_item_dose(enriched)
  expect_type(out, "double")
  expect_equal(out, c(10, 500))
  expect_identical(
    .per_item_dose(enriched, canonical_pack_quantity = FALSE),
    out
  )

  expect_identical(.per_item_dose(enriched[0, , drop = FALSE]), numeric(0))
})

test_that(".per_item_dose() canonicalises the pack quantity only when asked", {
  enriched <- tibble::tibble(
    strength_canonical = c(0.02, 5, 20),
    denominator_value = c(1, 1, 1),
    denominator_unit = c("g", "ml", "g"),
    pack_size = c(60, 1, 60),
    unit = c("g", "litre", "g")
  )
  expect_equal(.per_item_dose(enriched), c(1200, 5000, 1.2e6))
  expect_equal(
    .per_item_dose(enriched, canonical_pack_quantity = FALSE),
    c(1.2, 5, 1200)
  )
})

# ── Ingredient-targeting path ────────────────────────────────────────────────

test_that("ingredient targeting keeps dosing a per-gram tube from its VPI strength", {
  # 20 mg per 1 g x 60 g = 1200 mg per tube, so 150,000 mg is 125 tubes.
  # Canonicalising the pack quantity here as well would count each tube as
  # 1,200,000 mg and cost the dose as a single tube.
  res <- dmd_dose_optimise(
    "Delgocitinib",
    dose = 150000,
    dose_unit = "mg",
    db = db,
    ingredient = "Delgocitinib",
    objective = "cheapest"
  )
  expect_equal(nrow(res), 1L)
  expect_true(res$dose_exact)
  expect_equal(res$total_items, 125)
  expect_equal(res$dose_cost_pence, 125000)
  combo <- res$combination[[1]]
  expect_equal(combo$per_item_dose, 1200)
  expect_equal(combo$count, 125L)
})
