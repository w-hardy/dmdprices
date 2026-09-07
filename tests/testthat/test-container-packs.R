# Container-pack pricing and small-dose scaling for concentration preparations.
#
# Expected values are derived by hand from .fake_container_pack_db() (helper.R):
#   40 mg syringe  = 3000p / 10 = 300p     20 mg syringe = 2000p / 10 = 200p
#   300 mg vial    = 2500p (pack of 1)     inhaler (20 mg, 200 doses) = 150p
#   0.5 mg ampoule = 190p / 5 = 38p
# One optimisation item is one container. A pack of several containers is
# priced per container (pack price / containers per pack); whole-pack figures
# buy ceiling(containers / containers per pack) packs.

db <- .fake_container_pack_db()

# ── Multi-container packs ────────────────────────────────────────────────────

test_that("one container from a multi-container pack is priced per container", {
  res <- dmd_dose_optimise(
    "enoxaparin",
    dose = 40,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "cheapest"
  )
  expect_equal(nrow(res), 1L)
  expect_true(res$dose_exact)
  expect_equal(res$total_items, 1)
  expect_equal(res$cost_prorata_pence, 300)
  expect_equal(res$cost_whole_pack_pence, 3000)
  expect_equal(res$dose_cost_pence, 300)

  combo <- res$combination[[1]]
  expect_equal(nrow(combo), 1L)
  expect_equal(combo$ampp_snomed_code, "APP_SYR40")
  expect_equal(combo$count, 1L)
  expect_equal(combo$pack_size, 10)
  expect_equal(combo$packs_to_buy, 1L)
  expect_equal(combo$pack_price_pence, 3000)
  expect_equal(combo$per_item_price_pence, 300)
  expect_equal(combo$subtotal_prorata_pence, 300)
  expect_equal(combo$subtotal_whole_pack_pence, 3000)
})

test_that("several containers from one pack cost their pro-rata share", {
  res <- dmd_dose_optimise(
    "enoxaparin",
    dose = 80,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "cheapest"
  )
  expect_true(res$dose_exact)
  expect_equal(res$total_items, 2)
  expect_equal(res$cost_prorata_pence, 600)
  combo <- res$combination[[1]]
  expect_equal(combo$ampp_snomed_code, "APP_SYR40")
  expect_equal(combo$count, 2L)
  expect_equal(combo$packs_to_buy, 1L)
  expect_equal(combo$subtotal_whole_pack_pence, 3000)
})

test_that("containers beyond one pack buy a second whole pack", {
  # 440 mg = 11 x 40 mg syringes (3300p); every other exact build is dearer
  # (10 x 40 + 2 x 20 = 3400p; vial + 7 x 20 = 3900p).
  res <- dmd_dose_optimise(
    "enoxaparin",
    dose = 440,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "cheapest"
  )
  expect_true(res$dose_exact)
  expect_equal(res$total_items, 11)
  expect_equal(res$cost_prorata_pence, 3300)
  expect_equal(res$cost_whole_pack_pence, 6000)
  combo <- res$combination[[1]]
  expect_equal(combo$ampp_snomed_code, "APP_SYR40")
  expect_equal(combo$count, 11L)
  expect_equal(combo$packs_to_buy, 2L)
})

test_that("a single-container pack keeps the whole-container price", {
  # The inhaler's pack quantity (200 doses) is in the concentration's own
  # denominator unit, so the pack is one container of 20 mg at the pack price.
  res <- dmd_dose_optimise(
    "salbutamol",
    dose = 20,
    dose_unit = "mg",
    db = db,
    preparation = "inhaler",
    objective = "cheapest"
  )
  expect_equal(nrow(res), 1L)
  expect_true(res$dose_exact)
  expect_equal(res$cost_prorata_pence, 150)
  expect_equal(res$cost_whole_pack_pence, 150)
  combo <- res$combination[[1]]
  expect_equal(combo$ampp_snomed_code, "APP_INH")
  expect_equal(combo$count, 1L)
  expect_equal(combo$pack_size, 200)
  expect_equal(combo$packs_to_buy, 1L)
  expect_equal(combo$per_item_price_pence, 150)
})

test_that("vial sharing takes a fraction of one container's price", {
  # 30 mg: 0.75 of a 40 mg syringe (225p) beats 1.5 x 20 mg (300p) and 0.1 of
  # the 300 mg vial (250p).
  res <- dmd_dose_optimise(
    "enoxaparin",
    dose = 30,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "cheapest",
    can_split_vials = TRUE
  )
  expect_equal(nrow(res), 1L)
  expect_true(res$dose_exact)
  expect_equal(res$cost_prorata_pence, 225)
  expect_match(res$notes, "vial-sharing")
  combo <- res$combination[[1]]
  expect_equal(combo$ampp_snomed_code, "APP_SYR40")
  expect_equal(combo$count, 0.75)
  expect_equal(combo$per_item_price_pence, 300)
})

test_that("whole-pack dispensing of one container buys the whole pack", {
  res <- dmd_dose_optimise(
    "enoxaparin",
    dose = 40,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "cheapest",
    can_split = FALSE
  )
  expect_equal(res$combination[[1]]$ampp_snomed_code, "APP_SYR40")
  expect_equal(res$cost_whole_pack_pence, 3000)
  expect_equal(res$dose_cost_pence, 3000)
  expect_equal(
    dmd_dose_cost(
      "enoxaparin",
      dose = 40,
      dose_unit = "mg",
      db = db,
      preparation = "injection",
      can_split = FALSE
    ),
    3000
  )
})

test_that("vectorised costs price containers from multi-container packs", {
  expect_equal(
    dmd_dose_cost(
      "enoxaparin",
      dose = c(40, 80, 20),
      dose_unit = "mg",
      db = db,
      preparation = "injection"
    ),
    c(300, 600, 200)
  )
})

test_that("pack-level coins scale a multi-container pack by its containers", {
  pack_df <- tibble::tibble(
    denominator_unit = c(NA_character_, "ml", "ml"),
    per_item_dose = c(500, 1000, 40),
    pack_size = c(28, 100, 10),
    items_per_pack = c(28, 1, 10)
  )
  expect_equal(
    .build_pack_df(pack_df)$pack_dose,
    c(14000, 1000, 400)
  )
})

# ── Doses below the integer scale of a group's strengths ─────────────────────

test_that("a dose finer than the group's strengths is not silently dropped", {
  # 100 microgram against inhalers of 20 mg per container: the dose must be
  # scaled to an integer along with the strengths, then costed as one whole
  # container (the over-delivery policy does not govern whole containers).
  res <- dmd_dose_optimise(
    "salbutamol",
    dose = 100,
    dose_unit = "microgram",
    db = db,
    preparation = "inhaler",
    objective = "cheapest",
    quiet = TRUE
  )
  expect_equal(nrow(res), 1L)
  expect_equal(res$total_items, 1)
  expect_equal(res$dose_delivered, 20000)
  expect_false(res$dose_exact)
  expect_equal(res$cost_prorata_pence, 150)
  expect_match(res$notes, "over-delivery-policy-not-applied")
})

test_that("vectorised costs for doses finer than the strengths are returned", {
  expect_equal(
    dmd_dose_cost(
      "salbutamol",
      dose = c(100, 200, 20000),
      dose_unit = "microgram",
      db = db,
      preparation = "inhaler",
      quiet = TRUE
    ),
    c(150, 150, 150)
  )
})

test_that("the cost range sees every preparation group for a small dose", {
  # 100 microgram: one 500 microgram ampoule (38p) is the cheapest container;
  # the inhaler (150p) is the dearest.
  rng <- dmd_dose_cost_range(
    "salbutamol",
    dose = 100,
    dose_unit = "microgram",
    db = db,
    quiet = TRUE
  )
  expect_equal(rng$lo_pence, 38)
  expect_equal(rng$hi_pence, 150)
})

test_that("the integer scale makes the dose integral as well as the strengths", {
  expect_equal(.pick_scale_safe(c(12, 20, 40), 0.1), 10)
  expect_equal(.pick_scale_safe(c(0.5, 5), 0.1), 10)
  expect_equal(.pick_scale_safe(c(500, 1000), 750), 1)
})

test_that("a dose below the resolvable precision warns instead of vanishing", {
  expect_warning(
    res <- dmd_dose_optimise(
      "salbutamol",
      dose = 5e-8,
      dose_unit = "mg",
      db = db,
      preparation = "inhaler",
      objective = "cheapest",
      quiet = TRUE
    ),
    "precision"
  )
  expect_equal(nrow(res), 0L)
})
