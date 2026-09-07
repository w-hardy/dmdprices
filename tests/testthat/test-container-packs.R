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
  # 100 microgram against inhalers of 20 mg per container: the scale must be
  # raised until the dose is one unit, then the dose costed as one whole
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

test_that("the integer scale keeps the dose at least one unit", {
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

# ── The dose never raises the scale beyond what keeps the DP small ───────────

test_that("a dose with finer decimals than the strengths keeps the strengths' scale", {
  # 133.333 mg against 500 / 5000 mg tablets: the strengths need no scaling,
  # so the dose is taken to the nearest whole unit (133 mg) exactly as 0.6.0
  # did, and the smallest over-delivering build is one 500 mg tablet at
  # 100p / 28 = 3.571429p. Scaling the dose to full precision instead would
  # scale the 5000 mg coin with it, blow the DP past its 5,000,000-cell
  # limit and return NA.
  master <- tibble::tibble(
    medicine = c("Testdrug 500mg tablets", "Testdrug 5000mg tablets"),
    pack_size = c(28, 28),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VPP1", "VPP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(100L, 900L),
    nhs_indicative_price = c(100L, 900L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c("Testdrug 500mg 28 tablet", "Testdrug 5000mg 28 tablet"),
    ampp_snomed_code = c("APP1", "APP2")
  )
  coarse <- structure(
    list(master = master, loaded_at = .fixed_loaded_at),
    class = "dmd_db"
  )
  expect_equal(.pick_scale_safe(c(500, 5000), 133.333), 1)
  expect_equal(
    dmd_dose_cost(
      "testdrug",
      dose = 133.333,
      dose_unit = "mg",
      db = coarse,
      over_delivery = "minimise",
      quiet = TRUE
    ),
    100 / 28
  )
})

test_that("a very fine dose raises the scale only until it is one unit", {
  # 0.25 microgram against 12 / 20 / 40 mg inhalers: the scale is raised by
  # powers of ten until the dose is at least one unit (0.00025 * 10000 = 2.5),
  # not until it is an exact integer (100,000), so the DP stays small and one
  # whole inhaler is still the answer.
  expect_equal(.pick_scale_safe(c(12, 20, 40), 0.00025), 10000)
  res <- dmd_dose_optimise(
    "salbutamol",
    dose = 0.25,
    dose_unit = "microgram",
    db = db,
    preparation = "inhaler",
    objective = "cheapest",
    quiet = TRUE
  )
  expect_equal(nrow(res), 1L)
  expect_equal(res$total_items, 1)
  expect_equal(res$cost_prorata_pence, 150)
})

test_that("the precision warning is raised once by the cost range", {
  expect_warning(
    rng <- dmd_dose_cost_range(
      "salbutamol",
      dose = 5e-8,
      dose_unit = "mg",
      db = db,
      preparation = "inhaler",
      quiet = TRUE
    ),
    "precision"
  )
  expect_true(is.na(rng$lo_pence))
})
