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
  # A container-count vial (its name states the 1 ml container) and a tablet:
  # no row takes the pack-quantity branch, so the canonicalisation step must
  # be skipped rather than assign a zero-length mapply() result (a list) into
  # the multiplier.
  enriched <- tibble::tibble(
    medicine = c("Drug 10mg/1ml solution for injection vials", "Drug 500mg tablets"),
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
  # ml in a container-count pack of 50 ml vials (the name states the volume).
  enriched <- tibble::tibble(
    medicine = c(
      "Drug 20mg/g cream",
      "Drug 5mg/ml solution",
      "Drug 500mg/50ml solution for infusion vials"
    ),
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

test_that("a per-gram unit dose targeted by ingredient holds the mass its name states", {
  .local_fresh_dose_cache()
  # 15 mg per g, in 0.25 g unit doses: 3.75 mg each, not 15 mg (one gram).
  targeted <- .targeted("Azythro", "Azythro substance")
  expect_equal(targeted$strength_canonical, 0.015)
  expect_equal(targeted$strength_unit_canon, "mg/mg")
  expect_equal(targeted$per_item_dose, 3.75)
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
  expect_equal(res$total_items, 4)
  expect_equal(res$dose_cost_pence, 4 * 699 / 6)
})

test_that("a container of a per-litre ingredient holds the volume its name states", {
  .local_fresh_dose_cache()
  # 9 g per litre: a 500 ml bag holds 4,500 mg, a 1 litre bag 9,000 mg, and a
  # bag of unstated size has no known amount.
  bags <- .targeted("Exsaline", "Sodium chloride")
  bags <- bags[order(bags$medicine, method = "radix"), , drop = FALSE]
  expect_equal(bags$medicine, c(
    "Exsaline 0.9% infusion 1litre bags",
    "Exsaline 0.9% infusion 500ml bags",
    "Exsaline 0.9% infusion bags"
  ))
  expect_equal(bags$strength_canonical, c(9, 9, 9))
  expect_equal(bags$strength_unit_canon, c("mg/ml", "mg/ml", "mg/ml"))
  expect_equal(bags$per_item_dose, c(9000, 4500, NA_real_))
  expect_equal(bags$items_per_pack, c(10, 10, 10))

  # 4.5 g: one 500 ml bag (189p) beats one 1 litre bag (300p); the bag of
  # unstated size is skipped with a warning.
  got <- .with_warnings(dmd_dose_optimise(
    "Exsaline",
    dose = 4.5,
    dose_unit = "g",
    db = vpi_db,
    ingredient = "Sodium chloride",
    objective = "cheapest"
  ))
  expect_equal(got$value$combination[[1]]$medicine, "Exsaline 0.9% infusion 500ml bags")
  expect_equal(got$value$dose_cost_pence, 189)
  expect_true(got$value$dose_exact)
  unknown <- Filter(
    function(w) inherits(w, "dmdprices_warning_unknown_container_amount"),
    got$conditions
  )
  expect_length(unknown, 1L)
  expect_equal(unknown[[1]]$medicines, "Exsaline 0.9% infusion bags")
})

test_that("ingredient targeting never reads the stored canonical columns", {
  .local_fresh_dose_cache()
  poisoned <- vpi_db
  poisoned$ingredients$strength_canonical <- -999
  poisoned$ingredients$strength_unit_canon <- "bogus"
  azy <- .targeted("Azythro", "Azythro substance", db = poisoned)
  expect_equal(azy$strength_canonical, 0.015)
  expect_equal(azy$strength_unit_canon, "mg/mg")
  expect_equal(azy$per_item_dose, 3.75)
  bags <- .targeted("Exsaline 0.9% infusion 1litre", "Sodium chloride", db = poisoned)
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

test_that("an ingredient table without the raw strength fields is refused", {
  .local_fresh_dose_cache()
  canon_only <- vpi_db
  canon_only$ingredients <- canon_only$ingredients[, c(
    "vmp_snomed_code", "ingredient_snomed_code", "ingredient_name",
    "strength_canonical", "strength_unit_canon"
  )]
  expect_snapshot(
    error = TRUE,
    .targeted("Rituximab", "Rituximab", db = canon_only)
  )
})

test_that(".per_item_dose() has one convention and no flag", {
  # A deliberate guard against reintroducing a per-source convention flag
  # (0.6.2's `canonical_pack_quantity`): the behaviour it stood for is
  # asserted above by the targeted and parsed rows agreeing.
  expect_named(formals(.per_item_dose), "enriched")
})

test_that(".container_amount() reads an unambiguous container size in the right dimension", {
  amount <- function(name, dim) .container_amount(name, dim)
  expect_equal(amount("Sodium chloride 0.9% infusion 500ml bags", "ml"), 500)
  expect_equal(amount("Generic Aminoplasmal 15% solution for infusion 1litre bottles", "ml"), 1000)
  expect_equal(amount("Drug 2mg/ml solution for infusion 1,000ml bags", "ml"), 1000)
  expect_equal(amount("Insulin 100units/ml solution for injection 3ml pre-filled pens", "ml"), 3)
  expect_equal(amount("Tirzepatide 12.5mg/0.6ml solution for injection 2.4ml pre-filled disposable devices", "ml"), 2.4)
  expect_equal(amount("Sodium phosphate 2.875g/500ml infusion 500ml polyethylene bottles", "ml"), 500)
  expect_equal(amount("Azithromycin 15mg/g eye drops 0.25g unit dose preservative free", "mg"), 250)
  # The wrong dimension, a strength denominator, a strength numerator and a
  # size with no container word are not container sizes.
  expect_equal(amount("Azithromycin 15mg/g eye drops 0.25g unit dose preservative free", "ml"), NA_real_)
  expect_equal(amount("Rituximab 500mg/50ml solution for infusion vials", "ml"), NA_real_)
  expect_equal(amount("Meropenem 1g powder for solution for injection vials", "mg"), NA_real_)
  expect_equal(amount("Morphine 10mg/ml solution for injection ampoules", "ml"), NA_real_)
  # Two different sizes are ambiguous; the same size twice is not.
  expect_equal(amount("Drug 1mg/ml solution 10ml vials and Drug 1mg/ml solution 20ml vials", "ml"), NA_real_)
  expect_equal(amount("Drug 1mg/ml solution 10ml vials and Drug 2mg/ml solution 10ml vials", "ml"), 10)
  expect_equal(amount(c("Drug 1mg/ml 5ml vials", NA), "ml"), c(5, NA_real_))
  expect_equal(amount(character(), "ml"), numeric())
})

test_that(".container_quantities() falls back to an explicit strength denominator only", {
  q <- .container_quantities("Rituximab 500mg/50ml solution for infusion vials", 50, "ml")
  expect_equal(q, list(ml = 50, mg = NA_real_))
  q <- .container_quantities("Salbutamol 500micrograms/1ml solution for injection ampoules", 1, "ml")
  expect_equal(q$ml, 1)
  q <- .container_quantities("Morphine 10mg/ml solution for injection ampoules", 1, "ml")
  expect_equal(q$ml, NA_real_)
  # A stated container size wins over the strength's own denominator.
  q <- .container_quantities("Tirzepatide 12.5mg/0.6ml solution for injection 2.4ml pre-filled disposable devices", 0.6, "ml")
  expect_equal(q$ml, 2.4)
  q <- .container_quantities("Sodium chloride 0.9% infusion 500ml bags", NA_real_, NA_character_)
  expect_equal(q, list(ml = 500, mg = NA_real_))
  q <- .container_quantities("Azithromycin 15mg/g eye drops 0.25g unit dose preservative free", 1, "g")
  expect_equal(q, list(ml = NA_real_, mg = 250))
  q <- .container_quantities(c("A 5mg/ml 2ml vials", "B 5mg/2ml vials"), c(1, 2), c("ml", "ml"))
  expect_equal(q$ml, c(2, 2))
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
