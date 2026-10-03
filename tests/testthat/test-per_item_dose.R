# Per-item dose for concentration products sold as one container whose pack
# quantity is in a unit with a non-unit canonical factor (g -> mg, litre -> ml).
#
# Parsed names give strength_canonical per canonical denominator unit, so
# "20mg/g" is 0.02 mg per mg and a 60 g tube must count as 60000 mg, giving
# 1200 mg per tube (not 0.02 x 60 = 1.2 mg). VPI strengths used by ingredient
# targeting are stored per stated denominator (20 mg per 1 g), so that path
# keeps the raw pack quantity: 20 x 60 = 1200 mg.
#
# The fixture is .fake_per_gram_db() (helper.R): .fake_dose_db() plus a
# Delgocitinib 20mg/g cream in a 60 g tube and an Examplol 5mg/ml oral
# solution in a 1-litre pack, with a VPI table for the cream.

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
  .local_fresh_dose_cache()
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
  .local_fresh_dose_cache()
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
  .local_fresh_dose_cache()
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
  .local_fresh_dose_cache()
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
