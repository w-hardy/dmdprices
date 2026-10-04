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

test_that("whole-pack dispensing buys the cheapest whole pack covering the dose", {
  # 40 mg with whole packs only: the ten-syringe 20 mg pack (2000p) is the
  # cheapest pack covering the dose, ahead of the ten-syringe 40 mg pack (3000p)
  # and the 300 mg vial (2500p). Choosing by pro-rata price (one 40 mg syringe
  # at 300p) and then reporting its whole pack (3000p) is not "cheapest".
  res <- dmd_dose_optimise(
    "enoxaparin",
    dose = 40,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "cheapest",
    can_split = FALSE
  )
  expect_equal(nrow(res), 1L)
  expect_equal(res$combination[[1]]$ampp_snomed_code, "APP_SYR20")
  expect_equal(res$combination[[1]]$packs_to_buy, 1L)
  expect_equal(res$cost_whole_pack_pence, 2000)
  expect_equal(res$dose_cost_pence, 2000)
  expect_equal(res$total_items, 1)
  expect_match(res$notes, "no-pack-splitting")
  expect_equal(
    dmd_dose_cost(
      "enoxaparin",
      dose = 40,
      dose_unit = "mg",
      db = db,
      preparation = "injection",
      can_split = FALSE
    ),
    2000
  )
})

test_that("whole-pack dispensing picks a single-container pack when it is cheaper", {
  # 500 mg with whole packs only: one 20 mg ten-pack (200 mg, 2000p) plus the
  # 300 mg vial (2500p) delivers exactly 500 mg for 4500p; every other cover is
  # dearer (two vials 5000p; a 40 mg pack plus a 20 mg pack 5000p; two 40 mg
  # packs 6000p; three 20 mg packs 6000p).
  res <- dmd_dose_optimise(
    "enoxaparin",
    dose = 500,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "cheapest",
    can_split = FALSE
  )
  expect_equal(res$dose_cost_pence, 4500)
  expect_equal(res$dose_delivered, 500)
  expect_equal(res$total_items, 2)
  expect_setequal(res$combination[[1]]$ampp_snomed_code, c("APP_SYR20", "APP_VIAL300"))
})

test_that("the cost range never puts the lower bound above the upper bound", {
  # 80 mg with whole packs only. Cheapest: one 20 mg ten-pack (2000p, 200 mg).
  # Dearest: the dearest cover delivering at most one largest pack dose
  # (400 mg) over the dose, i.e. up to 480 mg — two 20 mg ten-packs (400 mg,
  # 4000p) beat one 40 mg ten-pack (3000p) and the 300 mg vial (2500p).
  rng <- dmd_dose_cost_range(
    "enoxaparin",
    dose = 80,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    can_split = FALSE,
    quiet = TRUE
  )
  expect_lte(rng$lo_pence, rng$hi_pence)
  expect_equal(rng$lo_pence, 2000)
  expect_equal(rng$hi_pence, 4000)
})

test_that("a dearer exact-container product cannot invert the whole-pack cost range", {
  # The real-data shape of the defect: an 80 mg ten-syringe pack at 5513p is
  # the exact single-container build for 80 mg, so choosing by pro-rata price
  # (551.3p) and reporting its whole pack (5513p) exceeded the dearest cover
  # the dearest-pack path found (two 20 mg packs, 4000p). The local fixture
  # adds that product and keeps the shared fixture's `loaded_at`: the
  # candidate cache keys on table content, so the added product is seen (#30).
  .local_fresh_dose_cache()
  # Prime the cache with the shared fixture under the same query and settings,
  # so a key that ignored the added product would serve this range for `wide`.
  primed <- dmd_dose_cost_range(
    "enoxaparin",
    dose = 80,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    can_split = FALSE,
    quiet = TRUE
  )
  expect_equal(primed$hi_pence, 4000)

  master <- db$master
  master <- rbind(
    master,
    tibble::tibble(
      medicine = "Enoxaparin sodium 80mg/0.8ml solution for injection pre-filled syringes",
      pack_size = 10,
      unit = "pre-filled disposable injection",
      vmp_snomed_code = "V80",
      vmpp_snomed_code = "VPP80",
      drug_tariff_category = "Part VIIIA Category C",
      basic_price = 5513L,
      nhs_indicative_price = 5513L,
      price_basis = "NHS Indicative Price",
      price_date = "2025-08-08",
      ampp_name = "Enoxaparin 80mg/0.8ml pre-filled syringes 10 pre-filled disposable injection",
      ampp_snomed_code = "APP_SYR80"
    )
  )
  wide <- structure(
    list(master = master, loaded_at = .fixed_loaded_at),
    class = "dmd_db"
  )
  rng <- dmd_dose_cost_range(
    "enoxaparin",
    dose = 80,
    dose_unit = "mg",
    db = wide,
    preparation = "injection",
    can_split = FALSE,
    quiet = TRUE
  )
  expect_lte(rng$lo_pence, rng$hi_pence)
  # Cheapest cover: the 20 mg ten-pack (200 mg, 2000p). The dearest cover may
  # deliver up to one largest pack (800 mg) over the dose, i.e. at most 880 mg:
  # four 20 mg ten-packs (800 mg, 8000p) beat a 40 mg pack plus two 20 mg
  # packs (800 mg, 7000p), two vials plus a 20 mg pack (800 mg, 7000p) and the
  # 80 mg pack alone (800 mg, 5513p); anything with the 80 mg pack plus another
  # pack exceeds 880 mg.
  expect_equal(rng$lo_pence, 2000)
  expect_equal(rng$hi_pence, 8000)
})

test_that("fewest packs is counted in packs for a concentration group", {
  # 80 mg with whole packs only: one 20 mg ten-pack (200 mg) is one pack; so
  # is one 40 mg ten-pack (400 mg, dearer); min_items breaks the tie on cost.
  res <- dmd_dose_optimise(
    "enoxaparin",
    dose = 80,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "min_items",
    can_split = FALSE
  )
  expect_equal(res$total_items, 1)
  expect_equal(res$dose_cost_pence, 2000)
  expect_equal(res$combination[[1]]$packs_to_buy, 1L)
})

test_that("vial sharing takes precedence over whole-pack dispensing", {
  # can_split_vials = TRUE is decided before the pack routing, so the answer
  # is the same fraction of a container whether or not packs may be split.
  shared <- dmd_dose_optimise(
    "enoxaparin",
    dose = 30,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "cheapest",
    can_split = TRUE,
    can_split_vials = TRUE
  )
  whole <- dmd_dose_optimise(
    "enoxaparin",
    dose = 30,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "cheapest",
    can_split = FALSE,
    can_split_vials = TRUE
  )
  expect_match(whole$notes, "vial-sharing")
  expect_equal(whole$cost_prorata_pence, shared$cost_prorata_pence)
  expect_equal(whole$combination[[1]]$count, 0.75)
})

test_that("the dearest container build prices multi-container packs per container", {
  # 40 mg, containers whole (the default): the cheapest exact build is one
  # 40 mg syringe (300p). Whole containers are exempt from the over-delivery
  # policy, so the dearest build may deliver up to one largest container
  # (300 mg) over the dose: seventeen 20 mg syringes (340 mg) at 200p each,
  # 3400p — priced per container, where before this fix each syringe carried
  # its whole pack's price (17 x 2000p = 34,000p).
  rng <- dmd_dose_cost_range(
    "enoxaparin",
    dose = 40,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    quiet = TRUE
  )
  expect_equal(rng$lo_pence, 300)
  expect_equal(rng$hi_pence, 3400)
  dearest <- dmd_dose_optimise(
    "enoxaparin",
    dose = 40,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "most_expensive",
    quiet = TRUE
  )
  expect_equal(dearest$total_items, 17)
  expect_equal(dearest$combination[[1]]$per_item_price_pence, 200)
  expect_equal(dearest$combination[[1]]$packs_to_buy, 2L)
})

test_that("ingredient-targeted candidates price multi-container packs per container", {
  # A combination product sold as ten 0.4 ml pre-filled syringes at 3000p,
  # dosed on one of its ingredients (40 mg per syringe): one syringe is
  # 3000p / 10 = 300p and buys one pack.
  master <- tibble::tibble(
    medicine = "Coamix 40mg/0.4ml solution for injection pre-filled syringes",
    pack_size = 10,
    unit = "pre-filled disposable injection",
    vmp_snomed_code = "V1",
    vmpp_snomed_code = "VPP1",
    drug_tariff_category = "Part VIIIA Category C",
    basic_price = 3000L,
    nhs_indicative_price = 3000L,
    price_basis = "NHS Indicative Price",
    price_date = "2025-08-08",
    ampp_name = "Coamix 40mg/0.4ml pre-filled syringes 10 pre-filled disposable injection",
    ampp_snomed_code = "APP_COMIX",
    is_combination = TRUE
  )
  ingredients <- tibble::tibble(
    vmp_snomed_code = c("V1", "V1"),
    ingredient_snomed_code = c("I_a", "I_b"),
    ingredient_name = c("Coamix substance", "Other substance"),
    strength_value = c(40, 10),
    strength_unit = c("mg", "mg"),
    denominator_value = c(0.4, 0.4),
    denominator_unit = c("ml", "ml"),
    strength_canonical = c(100, 25),
    strength_unit_canon = c("mg/ml", "mg/ml")
  )
  ing_db <- structure(
    list(master = master, ingredients = ingredients, loaded_at = .fixed_loaded_at),
    class = "dmd_db"
  )
  res <- dmd_dose_optimise(
    "coamix",
    dose = 40,
    dose_unit = "mg",
    db = ing_db,
    ingredient = "Coamix substance",
    objective = "cheapest",
    quiet = TRUE
  )
  expect_equal(nrow(res), 1L)
  expect_equal(res$total_items, 1)
  expect_equal(res$cost_prorata_pence, 300)
  combo <- res$combination[[1]]
  expect_equal(combo$per_item_price_pence, 300)
  expect_equal(combo$packs_to_buy, 1L)
  expect_equal(combo$subtotal_whole_pack_pence, 3000)
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
  expect_equal(.pick_scale_safe(c(12, 20, 40), 0.1), 1)
  expect_equal(.pick_scale_safe(c(0.5, 5), 0.1), 10)
  expect_equal(.pick_scale_safe(c(500, 1000), 750), 1)
})

test_that("a dose below the smallest strength is covered by one container", {
  # 5e-8 mg against a 20 mg inhaler: the smallest total at or above the dose
  # is one whole inhaler; no exact combination exists, so dose_exact is FALSE.
  expect_no_warning(
    res <- dmd_dose_optimise(
      "salbutamol",
      dose = 5e-8,
      dose_unit = "mg",
      db = db,
      preparation = "inhaler",
      objective = "cheapest",
      over_delivery = "minimise"
    )
  )
  expect_equal(nrow(res), 1L)
  expect_equal(res$total_items, 1)
  expect_equal(res$cost_prorata_pence, 150)
  expect_false(res$dose_exact)

  # Whole inhalers are exempt from the over-delivery policy, so "forbid"
  # returns the same inhaler with the exemption noted, and no warning.
  expect_no_warning(
    res <- dmd_dose_optimise(
      "salbutamol",
      dose = 5e-8,
      dose_unit = "mg",
      db = db,
      preparation = "inhaler",
      objective = "cheapest"
    )
  )
  expect_equal(nrow(res), 1L)
  expect_equal(res$cost_prorata_pence, 150)
  expect_match(res$notes, "over-delivery-policy-not-applied")
})

# ── The dose never raises the scale beyond what keeps the DP small ───────────

test_that("a dose with finer decimals than the strengths keeps the strengths' scale", {
  # 133.333 mg against 500 / 5000 mg tablets: the strengths need no scaling,
  # and the dose sits off their grid, so the smallest total at or above it is
  # one 500 mg tablet at 100p / 28 = 3.571429p. Scaling the dose to full
  # precision instead would scale the 5000 mg coin with it, blow the DP past
  # its 5,000,000-cell limit and return NA.
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

test_that("a very fine dose keeps the strengths' scale and one inhaler covers it", {
  # 0.25 microgram against 12 / 20 / 40 mg inhalers: the strengths' scale is
  # 1 and the dose is not raised onto a finer grid, so the DP stays small and
  # one whole inhaler is the answer.
  expect_equal(.pick_scale_safe(c(12, 20, 40), 0.00025), 1)
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

# Collect every warning a call raises, muffling them, so counts are exact.
.collect_warnings <- function(expr) {
  seen <- character()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      seen <<- c(seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = seen)
}

# A group whose strengths the capped dose table cannot represent: 0.125 mg and
# 1 mg need a scale of 1000, but a 6000.125 mg dose caps it at 833, where
# 0.125 mg is 104.125 units. Two preparations (tablets, capsules) so that a
# call can drop more than one group.
.fake_unresolvable_db <- function() {
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
    ampp_name = paste("Finedrug", c("125microgram", "1mg", "125microgram", "1mg"), "28", c("tablet", "tablet", "capsule", "capsule")),
    ampp_snomed_code = paste0("APP", 1:4)
  )
  structure(list(master = master, loaded_at = .fixed_loaded_at), class = "dmd_db")
}

test_that("the precision warning is raised exactly once by the cost range", {
  got <- .collect_warnings(dmd_dose_cost_range(
    "finedrug",
    dose = 6000.125,
    dose_unit = "mg",
    db = .fake_unresolvable_db(),
    preparation = "tablet",
    over_delivery = "minimise"
  ))
  expect_length(grep("precision", got$warnings), 1L)
  expect_true(is.na(got$value$lo_pence))
  expect_true(is.na(got$value$hi_pence))
})

test_that("one unresolved-dose warning per call names every dropped group", {
  # Two groups (tablets and capsules) cannot be represented for 6000.125 mg;
  # the default objective pair must not double the warning and the second
  # group must not be lost from it.
  got <- .collect_warnings(dmd_dose_optimise(
    "finedrug",
    dose = 6000.125,
    dose_unit = "mg",
    db = .fake_unresolvable_db(),
    over_delivery = "minimise"
  ))
  expect_equal(nrow(got$value), 0L)
  expect_length(grep("precision", got$warnings), 1L)
  expect_match(got$warnings[grep("precision", got$warnings)], "tablet")
  expect_match(got$warnings[grep("precision", got$warnings)], "capsule")
})

test_that("quiet = TRUE silences the unresolved-dose warning", {
  got <- .collect_warnings(dmd_dose_optimise(
    "finedrug",
    dose = 6000.125,
    dose_unit = "mg",
    db = .fake_unresolvable_db(),
    preparation = "tablet",
    objective = "cheapest",
    over_delivery = "minimise",
    quiet = TRUE
  ))
  expect_equal(nrow(got$value), 0L)
  expect_length(got$warnings, 0L)
})

test_that("a vector of unresolved doses raises the warning once", {
  got <- .collect_warnings(dmd_dose_cost(
    "finedrug",
    dose = rep(6000.125, 5),
    dose_unit = "mg",
    db = .fake_unresolvable_db(),
    preparation = "tablet",
    over_delivery = "minimise"
  ))
  expect_true(all(is.na(got$value)))
  expect_length(grep("precision", got$warnings), 1L)
})

test_that("a fine dose against coarse strengths is priced at the strengths' scale", {
  # Strengths 0.01 mg and 5000 mg, dose 0.006 mg. The strengths' own scale is
  # 100 (0.01 * 100 = 1); the dose is 0.6 units, off the grid, so the smallest
  # total at or above it is one 0.01 mg tablet at 100p / 28.
  master <- tibble::tibble(
    medicine = c("Finedrug 10microgram tablets", "Finedrug 5g tablets"),
    pack_size = c(28, 28),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VPP1", "VPP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(100L, 900L),
    nhs_indicative_price = c(100L, 900L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c("Finedrug 10microgram 28 tablet", "Finedrug 5g 28 tablet"),
    ampp_snomed_code = c("APP1", "APP2")
  )
  wide <- structure(
    list(master = master, loaded_at = .fixed_loaded_at),
    class = "dmd_db"
  )
  expect_equal(.pick_scale_safe(c(0.01, 5000), 0.006), 100)
  got <- .collect_warnings(dmd_dose_cost(
    "finedrug",
    dose = 0.006,
    dose_unit = "mg",
    db = wide,
    over_delivery = "minimise",
    quiet = TRUE
  ))
  expect_equal(got$value, 100 / 28)
  expect_length(got$warnings, 0L)
})
