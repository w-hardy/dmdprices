# Per-item dose for concentration products sold as one container whose pack
# quantity is in a unit with a non-unit canonical factor (g -> mg, litre -> ml),
# and the one strength convention shared by parsed names and VPI data.
#
# strength_canonical is the canonical numerator per one canonical denominator
# unit whatever its source, so "20mg/g" is 0.02 mg per mg and a 60 g tube must
# count as 60000 mg, giving 1200 mg per tube (not 0.02 x 60 = 1.2 mg). The
# ingredient-targeting path brings the VPI's "20 mg per 1 g" to the same
# 0.02 mg per mg before the pack quantity is applied.
#
# The fixtures are .fake_per_gram_db() (helper.R): .fake_dose_db() plus a
# Delgocitinib 20mg/g cream in a 60 g tube and an Examplol 5mg/ml oral
# solution in a 1-litre pack, with a VPI table for the cream; and
# .fake_vpi_units_db() for the VPI unit cases.

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
    enriched$per_item_dose[order(enriched$medicine, method = "radix")],
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

  expect_identical(.per_item_dose(enriched[0, , drop = FALSE]), numeric(0))
})

test_that(".per_item_dose() measures a one-container pack in the strength's canonical unit", {
  # 0.02 mg per mg in a 60 g tube; 5 mg per ml in a 1 litre pack; 10 mg per
  # ml in a container-count pack of 50 ml vials.
  enriched <- tibble::tibble(
    strength_canonical = c(0.02, 5, 10),
    denominator_value = c(1, 1, 50),
    denominator_unit = c("g", "ml", "ml"),
    pack_size = c(60, 1, 10),
    unit = c("g", "litre", "vial")
  )
  expect_equal(.per_item_dose(enriched), c(1200, 5000, 500))
})

# ── Ingredient-targeting path ────────────────────────────────────────────────

test_that("ingredient targeting keeps dosing a per-gram tube from its VPI strength", {
  .local_fresh_dose_cache()
  # The VPI's 20 mg per 1 g is 0.02 mg per mg, times a 60 g (60,000 mg) tube
  # = 1200 mg per tube, so 150,000 mg is 125 tubes.
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

# ── Ingredient-targeting path: one strength convention ───────────────────────

vpi_db <- .fake_vpi_units_db()

# Candidates for `query` after ingredient targeting, without the session memo.
.targeted <- function(query, ingredient, db = vpi_db) {
  enriched <- .dmd_prepare_candidates(
    query = query,
    db = db,
    method = "partial",
    max_dist = 3,
    active_only = TRUE,
    price = "basic_price"
  )
  .apply_ingredient_targeting(enriched, db, ingredient)
}

test_that("a targeted strength is canonical per one canonical denominator unit, as parsed", {
  .local_fresh_dose_cache()
  parsed <- .per_gram_candidates("Delgocitinib")
  targeted <- .apply_ingredient_targeting(parsed, db, "Delgocitinib")
  expect_equal(targeted$strength_canonical, 0.02)
  expect_equal(targeted$strength_unit_canon, "mg/mg")
  expect_equal(targeted$strength_canonical, parsed$strength_canonical)
  expect_equal(targeted$strength_unit_canon, parsed$strength_unit_canon)
  expect_equal(targeted$per_item_dose, 1200)
})

test_that("a targeted vial keeps the container volume stated in its name", {
  .local_fresh_dose_cache()
  targeted <- .targeted("Rituximab", "Rituximab")
  targeted <- targeted[order(targeted$medicine, method = "radix"), , drop = FALSE]
  expect_equal(targeted$medicine, c(
    "Rituximab 100mg/10ml solution for infusion",
    "Rituximab 500mg/50ml solution for infusion"
  ))
  expect_equal(targeted$strength_canonical, c(10, 10))
  expect_equal(targeted$strength_unit_canon, c("mg/ml", "mg/ml"))
  expect_equal(targeted$per_item_dose, c(100, 500))

  # Five 100 mg vials (437,500p) undercut one 500 mg vial, on both paths.
  parsed <- dmd_dose_cost(
    "Rituximab",
    dose = 500,
    dose_unit = "mg",
    db = vpi_db,
    preparation = "infusion"
  )
  expect_equal(parsed, 437500)
  expect_equal(
    dmd_dose_cost(
      "Rituximab",
      dose = 500,
      dose_unit = "mg",
      db = vpi_db,
      preparation = "infusion",
      ingredient = "Rituximab"
    ),
    parsed
  )
})

test_that("a per-gram unit dose targeted by ingredient is dosed per gram, not per milligram", {
  .local_fresh_dose_cache()
  targeted <- .targeted("Azythro", "Azythro substance")
  expect_equal(targeted$strength_canonical, 0.015)
  expect_equal(targeted$strength_unit_canon, "mg/mg")
  expect_equal(targeted$per_item_dose, 15)
  res <- dmd_dose_optimise(
    "Azythro",
    dose = 15,
    dose_unit = "mg",
    db = vpi_db,
    ingredient = "Azythro substance",
    objective = "cheapest"
  )
  expect_equal(nrow(res), 1L)
  expect_true(res$dose_exact)
  expect_equal(res$total_items, 1)
  expect_equal(res$dose_cost_pence, 699 / 6)
})

test_that("a VPI denominator in grams or litres does not scale a container-count item by 1000", {
  .local_fresh_dose_cache()
  bags <- .targeted("Exsaline", "Sodium chloride")
  expect_equal(bags$strength_canonical, 9)
  expect_equal(bags$strength_unit_canon, "mg/ml")
  expect_equal(bags$per_item_dose, 9000)
  expect_equal(bags$items_per_pack, 10)
})

test_that("ingredient targeting never reads the stored canonical columns", {
  .local_fresh_dose_cache()
  poisoned <- vpi_db
  poisoned$ingredients$strength_canonical <- -999
  poisoned$ingredients$strength_unit_canon <- "bogus"
  azy <- .targeted("Azythro", "Azythro substance", db = poisoned)
  expect_equal(azy$strength_canonical, 0.015)
  expect_equal(azy$strength_unit_canon, "mg/mg")
  expect_equal(azy$per_item_dose, 15)
  bags <- .targeted("Exsaline", "Sodium chloride", db = poisoned)
  expect_equal(bags$strength_canonical, 9)
  expect_equal(bags$per_item_dose, 9000)
})

test_that("a targeted one-container pack is measured in the strength's canonical unit", {
  .local_fresh_dose_cache()
  spirit <- .targeted("Exspirit", "Methyl salicylate")
  expect_equal(spirit$strength_unit_canon, "ml/ml")
  expect_equal(spirit$per_item_dose, 1)
  expect_equal(spirit$items_per_pack, 1)

  ornithine <- .targeted("Exornithine", "Ornithine")
  expect_equal(ornithine$per_item_dose, 100000)

  oxygen <- .targeted("Exoxygen", "Oxygen")
  expect_equal(oxygen$per_item_dose, 2130000)
})

test_that("a VPI denominator with no canonical unit is skipped with a warning naming it", {
  .local_fresh_dose_cache()
  expect_snapshot(targeted <- .targeted("Expatch transdermal", "Expatchine"))
  expect_equal(nrow(targeted), 1L)
  expect_equal(targeted$strength_canonical, NA_real_)
  expect_equal(targeted$per_item_dose, NA_real_)
})

test_that("the non-mass warning names a bad numerator and a bad denominator together", {
  .local_fresh_dose_cache()
  expect_snapshot(targeted <- .targeted("Expatch", "Expatchine"))
  expect_equal(nrow(targeted), 2L)
  expect_equal(targeted$per_item_dose, c(NA_real_, NA_real_))
})

test_that("an ingredient table without canonical columns is targeted from its raw fields", {
  .local_fresh_dose_cache()
  raw_db <- vpi_db
  raw_db$ingredients$strength_canonical <- NULL
  raw_db$ingredients$strength_unit_canon <- NULL
  targeted <- .targeted("Rituximab", "Rituximab", db = raw_db)
  expect_equal(sort(targeted$per_item_dose), c(100, 500))
})

test_that(".per_item_dose() has one convention and no flag", {
  # A deliberate guard against reintroducing a per-source convention flag
  # (0.6.2's `canonical_pack_quantity`): the behaviour it stood for is
  # asserted above by the targeted and parsed rows agreeing.
  expect_named(formals(.per_item_dose), "enriched")
})

test_that(".canonical_strength() canonicalises each side and rejects what it cannot", {
  expect_equal(
    .canonical_strength(numeric(), character()),
    list(value = numeric(), unit = character())
  )
  # A scalar denominator recycles over a vector of numerators.
  can <- .canonical_strength(c(10, 20), c("mg", "mg"), 1, "g")
  expect_equal(can$value, c(0.01, 0.02))
  expect_equal(can$unit, c("mg/mg", "mg/mg"))
  # A denominator unit without a value means per one unit.
  expect_equal(.canonical_strength(10, "mg", NA_real_, "g")$value, 0.01)
  # Units are matched regardless of case.
  expect_equal(.canonical_strength(5, "MG", 1, "ML")$unit, "mg/ml")
  # No canonical form on either side: no strength.
  none <- list(value = NA_real_, unit = NA_character_)
  expect_equal(.canonical_strength(5, "GBq", 1, "ml"), none)
  expect_equal(.canonical_strength(5, "microgram", 1, "hour"), none)
  # A missing value, or a denominator that is not a positive quantity, is no
  # strength either, on both sides.
  expect_equal(.canonical_strength(NA_real_, "mg", 1, "ml"), none)
  expect_equal(.canonical_strength(5, "mg", 0, "ml"), none)
})

test_that("the bundled dmd_ingredients canonical columns follow the one convention", {
  ing <- dmdprices::dmd_ingredients
  # One row pinned by hand, independently of the helper: delgocitinib is
  # recorded as 20 mg per 1 g.
  delgo <- ing[ing$vmp_snomed_code %in% "44923111000001104", , drop = FALSE]
  expect_equal(nrow(delgo), 1L)
  expect_equal(delgo$strength_value, 20)
  expect_equal(delgo$denominator_unit, "g")
  expect_equal(delgo$strength_canonical, 0.02)
  expect_equal(delgo$strength_unit_canon, "mg/mg")
  # Data-sync check: the bundled columns were regenerated with the helper.
  can <- .canonical_strength(
    ing$strength_value,
    ing$strength_unit,
    ing$denominator_value,
    ing$denominator_unit
  )
  expect_equal(ing$strength_canonical, can$value)
  expect_equal(ing$strength_unit_canon, can$unit)
})
