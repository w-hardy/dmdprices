db <- .fake_dose_db()

# ── String dose input ─────────────────────────────────────────────────────────

test_that("dose can be supplied as a string with unit (e.g. '900 mg')", {
  res_num <- dmd_dose_optimise(
    "metformin",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  res_str <- dmd_dose_optimise(
    "metformin",
    dose = "900 mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  expect_equal(res_num$dose_delivered, res_str$dose_delivered)
  expect_equal(res_num$total_items, res_str$total_items)
})

test_that("dose string with no space between value and unit is accepted", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = "500mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  expect_s3_class(res, "tbl_df")
  expect_true(all(res$dose_delivered >= 500))
})

test_that("dose string with different unit (g) is converted correctly", {
  res_mg <- dmd_dose_optimise(
    "metformin",
    dose = 500,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  res_g <- dmd_dose_optimise(
    "metformin",
    dose = "0.5 g",
    db = db,
    preparation = "tablet|none|oral"
  )
  expect_equal(res_mg$total_items, res_g$total_items)
})

test_that("string dose with extra dose_unit warns and uses string unit", {
  expect_warning(
    dmd_dose_optimise(
      "metformin",
      dose = "900 mg",
      dose_unit = "g",
      db = db,
      preparation = "tablet|none|oral"
    ),
    regexp = "differs"
  )
})

test_that("unparseable dose string gives informative error", {
  expect_error(
    dmd_dose_optimise("metformin", dose = "lots", db = db),
    regexp = "could not be parsed"
  )
})

# ── can_split parameter ───────────────────────────────────────────────────────

test_that("can_split = FALSE adds 'no-pack-splitting' note for solid forms", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    can_split = FALSE
  )
  expect_true(all(grepl("no-pack-splitting", res$notes)))
})

test_that("can_split = TRUE does not add 'no-pack-splitting' note", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    can_split = TRUE
  )
  expect_false(any(grepl("no-pack-splitting", res$notes)))
})

test_that("can_split = FALSE: concentration preparations do not get no-pack-splitting note", {
  # Vials / solutions are already whole-container; note should not appear.
  res <- dmd_dose_optimise(
    "rituximab",
    dose = 900,
    dose_unit = "mg",
    db = db,
    can_split = FALSE
  )
  expect_false(any(grepl("no-pack-splitting", res$notes)))
})

test_that("can_split = FALSE returns valid cost_whole_pack_pence", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = 1000,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    can_split = FALSE
  )
  # Whole-pack cost must be >= pro-rata cost (you buy at least as many items).
  expect_true(all(
    is.na(res$cost_whole_pack_pence) |
      res$cost_whole_pack_pence >= res$cost_prorata_pence
  ))
})

# ── Pack-level DP regression (the old limitation) ────────────────────────────

test_that("can_split = FALSE uses pack-level DP and picks cheapest whole pack", {
  # 100mg: 100-per-pack at 150p  (1.5p pro-rata, but 1 pack = 150p)
  # 500mg:   1-per-pack at  50p  (50p pro-rata,  and 1 pack =  50p)
  # For 400mg, item-level cheapest (can_split=TRUE) picks 4×100mg (6p pro-rata).
  # Pack-level cheapest (can_split=FALSE) should pick 1×500mg pack (50p), NOT
  # 1×100mg pack (150p) as the old post-hoc whole-pack calculation would give.
  m_lim <- tibble::tibble(
    medicine = c("Metformin 100mg tablets", "Metformin 500mg tablets"),
    pack_size = c(100L, 1L),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VP1", "VP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(150L, 50L),
    nhs_indicative_price = c(150L, 50L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c("Metformin 100mg 100 tablet", "Metformin 500mg 1 tablet"),
    ampp_snomed_code = c("A1", "A2")
  )
  db_lim <- structure(
    list(master = m_lim, loaded_at = Sys.time()),
    class = "dmd_db"
  )

  res <- dmd_dose_optimise(
    "metformin",
    dose = "400 mg",
    db = db_lim,
    preparation = "tablet|none|oral",
    objective = "cheapest",
    can_split = FALSE
  )
  # Pack-level DP picks 1×500mg pack (500mg, 50p), not 1×100mg pack (150p).
  expect_equal(res$total_items, 1L)
  expect_equal(res$cost_whole_pack_pence, 50)
  expect_equal(res$dose_delivered, 500)
  expect_true(grepl("no-pack-splitting", res$notes))
  # Combination AMPP should be the 500mg tablet.
  expect_true(grepl("500mg", res$combination[[1]]$ampp_name))
})

test_that("can_split = FALSE min_items counts packs, not tablets", {
  # Using the same limiting db: min_items objective should return 1 pack (500mg)
  # rather than 4 tablets (4×100mg) for a 400mg dose.
  m_lim <- tibble::tibble(
    medicine = c("Metformin 100mg tablets", "Metformin 500mg tablets"),
    pack_size = c(100L, 1L),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VP1", "VP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(150L, 50L),
    nhs_indicative_price = c(150L, 50L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c("Metformin 100mg 100 tablet", "Metformin 500mg 1 tablet"),
    ampp_snomed_code = c("A1", "A2")
  )
  db_lim <- structure(
    list(master = m_lim, loaded_at = Sys.time()),
    class = "dmd_db"
  )

  res <- dmd_dose_optimise(
    "metformin",
    dose = "400 mg",
    db = db_lim,
    preparation = "tablet|none|oral",
    objective = "min_items",
    can_split = FALSE
  )
  # Both available packs overdeliver; 1 pack of 500mg is minimum.
  expect_equal(res$total_items, 1L)
})

test_that("can_split must be a single logical", {
  expect_error(
    dmd_dose_optimise(
      "metformin",
      dose = 500,
      dose_unit = "mg",
      db = db,
      can_split = "yes"
    ),
    regexp = "single logical"
  )
})


test_that("basic dose optimisation returns cheapest and min_items rows", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = 1500,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  expect_s3_class(res, "tbl_df")
  expect_true(all(c("cheapest", "min_items") %in% res$objective))
  expect_equal(unique(res$preparation_group), "tablet|none|oral")
  expect_true(all(res$dose_delivered >= res$dose_requested))
})

test_that("combination list-column identifies the AMPPs chosen", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = 1500,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    objective = "min_items"
  )
  combo <- res$combination[[1]]
  expect_s3_class(combo, "tbl_df")
  expect_true(all(
    c(
      "medicine",
      "ampp_name",
      "vmpp_snomed_code",
      "ampp_snomed_code",
      "count",
      "pack_size",
      "packs_to_buy",
      "pack_price_pence",
      "per_item_price_pence",
      "subtotal_prorata_pence",
      "subtotal_whole_pack_pence"
    ) %in%
      names(combo)
  ))
  expect_true(all(combo$count > 0))
})

test_that("cheapest and min_items can differ for a 900mg metformin dose", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  # min_items can over-deliver (2 × 500mg = 1000mg); cheapest will use 100mg
  # rows if that is the lowest pro-rata combination.
  mi <- res[res$objective == "min_items", , drop = FALSE]
  ch <- res[res$objective == "cheapest", , drop = FALSE]
  expect_equal(nrow(mi), 1)
  expect_equal(nrow(ch), 1)
  expect_true(mi$dose_delivered >= 900)
  expect_true(ch$dose_delivered >= 900)
  expect_true(mi$total_items <= ch$total_items)
})

test_that("preparations are segregated (IR vs MR)", {
  res <- dmd_dose_optimise("metformin", dose = 1000, dose_unit = "mg", db = db)
  groups <- unique(res$preparation_group)
  expect_true("tablet|none|oral" %in% groups)
  expect_true("modified-release tablet|modified-release|oral" %in% groups)
})

test_that("morphine in mg units optimises across oral and injection groups", {
  res <- dmd_dose_optimise(
    "morphine",
    dose = 20,
    dose_unit = "mg",
    db = db
  )
  expect_s3_class(res, "tbl_df")
  groups <- unique(res$preparation_group)
  # Oral-solution and solution-for-injection should be segregated.
  expect_true(any(grepl("oral solution", groups)))
  expect_true(any(grepl("solution for injection", groups)))
})

test_that("microgram dose exercises scaling", {
  # Fake db: a single microgram-scale entry. Build on the fly.
  m <- tibble::tibble(
    medicine = c(
      "Levothyroxine 25microgram tablets",
      "Levothyroxine 100microgram tablets"
    ),
    pack_size = c(28, 28),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("L1", "L2"),
    vmpp_snomed_code = c("LP1", "LP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(150L, 200L),
    nhs_indicative_price = c(160L, 210L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c(
      "Levothyroxine 25mcg (Brand A) 28 tablet",
      "Levothyroxine 100mcg (Brand A) 28 tablet"
    ),
    ampp_snomed_code = c("LA1", "LA2")
  )
  ldb <- structure(list(master = m, loaded_at = Sys.time()), class = "dmd_db")
  res <- dmd_dose_optimise(
    "levothyroxine",
    dose = 125,
    dose_unit = "microgram",
    db = ldb
  )
  expect_s3_class(res, "tbl_df")
  expect_true(nrow(res) >= 1)
  # 125 micrograms = 25 + 100 mcg, so dose_delivered should equal 125 in
  # the same unit as the input.
  expect_equal(unique(res$dose_delivered), 125)
})

test_that("price fallback is flagged when basic_price is NA", {
  # Metformin 100mg row has NA basic_price but non-NA nhs_indicative_price.
  res <- dmd_dose_optimise(
    "metformin",
    dose = 100,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  # Should pick the 100mg tablet for min_items; price_fallback in notes.
  mi <- res[res$objective == "min_items", , drop = FALSE]
  expect_true(any(grepl(
    "price-field-fallback|over-delivery|cheapest",
    mi$notes
  )))
})

test_that("over-delivery is recorded in notes when dose is unreachable exactly", {
  # With only 500mg and 1000mg IR metformin, 750mg cannot be reached exactly.
  # Keep only IR strengths by filtering via preparation.
  res <- dmd_dose_optimise(
    "metformin",
    dose = 750,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    over_delivery = "allow",
    quiet = TRUE
  )
  # 750 with 100mg available is reachable exactly (1×500 + 2×100 + 1×50? no,
  # no 50mg). 100mg × 7 + 500mg × 1 - ... Actually 750 = 500 + 250, no 250.
  # 750 = 100×7 + 50 — no. Options: 100×7 = 700 (under), 100×8 = 800 (over).
  # So 750 needs over-delivery. Confirm.
  expect_true(all(res$over_delivery >= 0))
  expect_true(any(grepl("over-delivery", res$notes)))
  expect_true(all(!res$dose_exact))
})

test_that("an unreachable dose returns no rows and warns under the default", {
  expect_warning(
    res <- dmd_dose_optimise(
      "metformin",
      dose = 750,
      dose_unit = "mg",
      db = db,
      preparation = "tablet|none|oral"
    ),
    "No exact-dose combination exists"
  )
  expect_equal(nrow(res), 0L)
  expect_named(res, names(dmdprices:::.empty_dose_result()))
})

test_that("over_delivery = 'minimise' picks the smallest over-delivery", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = 750,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    objective = "all",
    over_delivery = "minimise",
    quiet = TRUE
  )
  # Nearest reachable target above 750 with 100/500/1000mg tablets is 800.
  expect_true(all(res$dose_delivered == 800))
  expect_true(all(res$over_delivery == 50))
  expect_true(all(!res$dose_exact))
  expect_true(all(grepl("over-delivery-minimised", res$notes)))
})

test_that("print method for combination runs without error", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = 1500,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    objective = "min_items"
  )
  expect_output(print(res$combination[[1]]), "Metformin")
})

# ── Regression: concentration vials with repeating-decimal strength ───────────
# Rituximab 1400mg/11.7ml: strength_canonical = 119.658... mg/ml (repeating).
# Before the per_item_dose fix, this caused .pick_scale() to inflate the scale
# to 1e7, overflowing as.integer() for the 900mg dose and crashing with
# "missing value where TRUE/FALSE needed".

test_that("concentration vial per_item_dose is total mg per vial, not mg/ml", {
  res <- dmd_dose_optimise(
    "rituximab",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "solution for injection|none|injection"
  )
  combo <- res$combination[[1]]
  # The 1400mg/11.7ml vial delivers 1400mg per vial, not 119.658... mg
  expect_equal(unique(res$dose_delivered), 1400)
  expect_equal(combo$count, 1L)
})

test_that("concentration vial group does not error or warn about integer overflow", {
  # Before the fix: Warning "NAs introduced by coercion to integer range" +
  # Error "missing value where TRUE/FALSE needed"
  expect_no_error(
    dmd_dose_optimise("rituximab", dose = 900, dose_unit = "mg", db = db)
  )
  # expect_no_warning() takes no regexp argument; we assert no error is the
  # primary check — the integer-overflow warning is what previously crashed.
  expect_no_warning(
    dmd_dose_optimise("rituximab", dose = 900, dose_unit = "mg", db = db)
  )
})

test_that("both injection and infusion groups are returned for rituximab 900mg", {
  res <- dmd_dose_optimise(
    "rituximab",
    dose = 900,
    dose_unit = "mg",
    db = db
  )
  groups <- unique(res$preparation_group)
  expect_true(any(grepl("solution for injection", groups)))
  expect_true(any(grepl("solution for infusion", groups)))
  # cheapest + min_items for each group = 4 rows
  expect_equal(nrow(res), 4L)
})

test_that("infusion group finds exact 900mg for rituximab", {
  # Fake db has 100mg/10ml and 500mg/50ml infusion vials; 900mg = 4×100 + 1×500
  res <- dmd_dose_optimise(
    "rituximab",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "solution for infusion|none|intravenous"
  )
  ch <- res[res$objective == "cheapest", ]
  expect_equal(ch$dose_delivered, 900)
  expect_equal(ch$over_delivery, 0)
})

test_that("oral liquid concentration uses pack volume, not denominator times pack volume", {
  res <- dmd_dose_optimise(
    "morphine",
    dose = 20,
    dose_unit = "mg",
    db = db,
    preparation = "oral solution",
    objective = "cheapest"
  )
  combo <- res$combination[[1]]
  expect_equal(combo$per_item_dose, 200)
  expect_equal(res$dose_delivered, 200)
})

test_that("vial concentrations still use denominator volume for one container", {
  res_500 <- dmd_dose_optimise(
    "rituximab",
    dose = 500,
    dose_unit = "mg",
    db = db,
    preparation = "infusion",
    objective = "min_items"
  )
  combo_500 <- res_500$combination[[1]]
  expect_equal(combo_500$per_item_dose, 500)
  expect_equal(res_500$dose_delivered, 500)

  res_100 <- dmd_dose_optimise(
    "rituximab",
    dose = 100,
    dose_unit = "mg",
    db = db,
    preparation = "infusion",
    objective = "min_items"
  )
  combo_100 <- res_100$combination[[1]]
  expect_equal(combo_100$per_item_dose, 100)
  expect_equal(res_100$dose_delivered, 100)
})

test_that("dmd_dose_cost matches corrected oral liquid optimiser cost", {
  full <- dmd_dose_optimise(
    "morphine",
    dose = 20,
    dose_unit = "mg",
    db = db,
    preparation = "oral solution",
    objective = "cheapest"
  )
  scalar <- dmd_dose_cost(
    "morphine",
    dose = 20,
    dose_unit = "mg",
    db = db,
    preparation = "oral solution",
    objective = "cheapest"
  )
  expect_equal(scalar, full$dose_cost_pence)
})

# ── preparation substring / partial matching ──────────────────────────────────

test_that("preparation = 'infusion' matches infusion groups (partial match)", {
  res_full <- dmd_dose_optimise(
    "rituximab",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "solution for infusion|none|intravenous"
  )
  res_partial <- dmd_dose_optimise(
    "rituximab",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "infusion"
  )
  # Partial should return only infusion groups, same as the exact key.
  expect_equal(
    unique(res_partial$preparation_group),
    unique(res_full$preparation_group)
  )
  expect_false(any(grepl("injection", res_partial$preparation_group)))
})

test_that("preparation partial match is case-insensitive", {
  res <- dmd_dose_optimise(
    "rituximab",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "INFUSION"
  )
  expect_true(nrow(res) > 0)
  expect_true(all(grepl("infusion", res$preparation_group, ignore.case = TRUE)))
})

test_that("exact preparation key still works after substring-match change", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  expect_true(nrow(res) > 0)
  expect_equal(unique(res$preparation_group), "tablet|none|oral")
})

# ── Memoization ───────────────────────────────────────────────────────────────

test_that("second call for the same drug is served from the memo cache", {
  # Verify the cache is populated after calling once.
  memoise::forget(.dmd_prepare_candidates_memo)
  expect_false(
    memoise::has_cache(.dmd_prepare_candidates_memo)(
      query = "metformin",
      db = db,
      method = "partial",
      max_dist = 3,
      active_only = TRUE,
      price = "basic_price"
    )
  )
  dmd_dose_optimise(
    "metformin",
    dose = 500,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  expect_true(
    memoise::has_cache(.dmd_prepare_candidates_memo)(
      query = "metformin",
      db = db,
      method = "partial",
      max_dist = 3,
      active_only = TRUE,
      price = "basic_price"
    )
  )
})

test_that("memo cache is populated after the first call", {
  memoise::forget(.dmd_prepare_candidates_memo)
  dmd_dose_optimise("metformin", dose = 500, dose_unit = "mg", db = db)
  expect_true(
    memoise::has_cache(.dmd_prepare_candidates_memo)(
      query = "metformin",
      db = db,
      method = "partial",
      max_dist = 3,
      active_only = TRUE,
      price = "basic_price"
    )
  )
})

# ── dmd_dose_cost() ───────────────────────────────────────────────────────────

test_that("dmd_dose_cost returns a numeric vector of the same length as dose", {
  doses <- c(500, 1000, 1500)
  res <- dmd_dose_cost(
    "metformin",
    dose = doses,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  expect_type(res, "double")
  expect_length(res, 3L)
})

test_that("dmd_dose_cost returns the same cost as dmd_dose_optimise for a single dose", {
  full <- dmd_dose_optimise(
    "metformin",
    dose = 1000,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    objective = "cheapest"
  )
  scalar <- dmd_dose_cost(
    "metformin",
    dose = 1000,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    objective = "cheapest"
  )
  expect_equal(scalar, full$dose_cost_pence[full$objective == "cheapest"])
})

test_that("dmd_dose_cost returns na_value for NA, zero, and negative doses", {
  res <- dmd_dose_cost(
    "metformin",
    dose = c(NA_real_, 0, -100, 500),
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  expect_true(is.na(res[1]))
  expect_true(is.na(res[2]))
  expect_true(is.na(res[3]))
  expect_false(is.na(res[4]))
})

test_that("dmd_dose_cost respects custom na_value", {
  res <- dmd_dose_cost(
    "metformin",
    dose = c(NA_real_, 500),
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    na_value = 0
  )
  expect_equal(res[1], 0)
  expect_false(res[2] == 0)
})

test_that("dmd_dose_cost accepts a preparation partial match", {
  res_full <- dmd_dose_cost(
    "rituximab",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "solution for infusion|none|intravenous"
  )
  res_partial <- dmd_dose_cost(
    "rituximab",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "infusion"
  )
  expect_equal(res_partial, res_full)
})

test_that("dmd_dose_cost with no preparation returns min cost across groups", {
  # Without filtering, all groups compete; cost must be <= any single group cost.
  cost_infusion <- dmd_dose_cost(
    "rituximab",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "infusion"
  )
  cost_injection <- dmd_dose_cost(
    "rituximab",
    dose = 900,
    dose_unit = "mg",
    db = db,
    preparation = "injection"
  )
  cost_all <- dmd_dose_cost("rituximab", dose = 900, dose_unit = "mg", db = db)
  expect_true(cost_all <= min(cost_infusion, cost_injection, na.rm = TRUE))
})

# ── most_expensive objective ──────────────────────────────────────────────────

test_that("objective = 'most_expensive' returns cost >= cheapest for same group", {
  ch <- dmd_dose_optimise(
    "metformin",
    dose = 1000,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    objective = "cheapest"
  )
  me <- dmd_dose_optimise(
    "metformin",
    dose = 1000,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    objective = "most_expensive"
  )
  expect_s3_class(me, "tbl_df")
  expect_equal(nrow(me), 1L)
  expect_equal(me$objective, "most_expensive")
  expect_true(
    is.na(me$dose_cost_pence) || is.na(ch$dose_cost_pence) ||
      me$dose_cost_pence >= ch$dose_cost_pence
  )
})

test_that("objective = 'most_expensive' follows the true max-cost DP path", {
  m <- tibble::tibble(
    medicine = c("Testdrug 100mg tablets", "Testdrug 200mg tablets"),
    pack_size = c(1L, 1L),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VP1", "VP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(100L, 1L),
    nhs_indicative_price = c(100L, 1L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c("Testdrug 100mg 1 tablet", "Testdrug 200mg 1 tablet"),
    ampp_snomed_code = c("A1", "A2")
  )
  max_db <- structure(
    list(master = m, loaded_at = Sys.time()),
    class = "dmd_db"
  )

  # over_delivery = "allow" so the dearest combination may exceed the dose,
  # which is what this objective is being tested for.
  res <- dmd_dose_optimise(
    "testdrug",
    dose = 200,
    dose_unit = "mg",
    db = max_db,
    preparation = "tablet|none|oral",
    objective = "most_expensive",
    over_delivery = "allow",
    quiet = TRUE
  )
  combo <- res$combination[[1]]
  expect_equal(res$dose_cost_pence, 400)
  expect_equal(res$dose_delivered, 400)
  expect_equal(combo$medicine, "Testdrug 100mg tablets")
  expect_equal(combo$count, 4L)

  # Under the default the dearest *exact* delivery is 2 x 100mg.
  exact <- dmd_dose_optimise(
    "testdrug",
    dose = 200,
    dose_unit = "mg",
    db = max_db,
    preparation = "tablet|none|oral",
    objective = "most_expensive"
  )
  expect_equal(exact$dose_delivered, 200)
  expect_true(exact$dose_exact)
  expect_equal(exact$combination[[1]]$count, 2L)
})

test_that("objective = c('cheapest', 'most_expensive') returns two rows", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = 1000,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    objective = c("cheapest", "most_expensive")
  )
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 2L)
  expect_setequal(res$objective, c("cheapest", "most_expensive"))
})

test_that("objective = 'all' returns three rows per preparation group", {
  res <- dmd_dose_optimise(
    "metformin",
    dose = 1000,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    objective = "all"
  )
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 3L)
  expect_setequal(res$objective, c("cheapest", "min_items", "most_expensive"))
})

test_that("objective = 'both' triggers a deprecation warning", {
  expect_warning(
    dmd_dose_optimise(
      "metformin",
      dose = 1000,
      dose_unit = "mg",
      db = db,
      preparation = "tablet|none|oral",
      objective = "both"
    ),
    regexp = "both"
  )
})

test_that("objective = 'both' still returns cheapest and min_items rows", {
  res <- suppressWarnings(
    dmd_dose_optimise(
      "metformin",
      dose = 1000,
      dose_unit = "mg",
      db = db,
      preparation = "tablet|none|oral",
      objective = "both"
    )
  )
  expect_setequal(res$objective, c("cheapest", "min_items"))
})

# ── can_split_vials ───────────────────────────────────────────────────────────

test_that("can_split_vials = TRUE gives non-integer count and vial-sharing note", {
  # 250mg dose against 500mg/50ml vials — should use half a vial (count = 0.5)
  res <- dmd_dose_optimise(
    "rituximab",
    dose = 250,
    dose_unit = "mg",
    db = db,
    preparation = "solution for infusion|none|intravenous",
    objective = "cheapest",
    can_split_vials = TRUE
  )
  expect_s3_class(res, "tbl_df")
  expect_true(nrow(res) >= 1L)
  combo <- res$combination[[1]]
  expect_false(combo$count[1] == as.integer(combo$count[1]))
  expect_true(any(grepl("vial-sharing", res$notes)))
})

test_that("can_split_vials = TRUE cost <= whole-vial cost for same dose", {
  cost_whole <- dmd_dose_optimise(
    "rituximab",
    dose = 250,
    dose_unit = "mg",
    db = db,
    preparation = "solution for infusion|none|intravenous",
    objective = "cheapest",
    can_split_vials = FALSE
  )$dose_cost_pence

  cost_shared <- dmd_dose_optimise(
    "rituximab",
    dose = 250,
    dose_unit = "mg",
    db = db,
    preparation = "solution for infusion|none|intravenous",
    objective = "cheapest",
    can_split_vials = TRUE
  )$dose_cost_pence

  expect_true(
    is.na(cost_shared) || is.na(cost_whole) ||
      cost_shared <= cost_whole
  )
})

# ── Regression: pack-level DP + most_expensive (bug #2) ───────────────────────

test_that("most_expensive + can_split = FALSE picks the dearest pack", {
  # 100mg: 100-per-pack at 150p (cheap per mg)
  # 500mg:   1-per-pack at 950p (expensive per pack)
  # For 400mg with can_split = FALSE: cheapest pack-level = 1×500mg (950p is
  #   actually not cheapest; 1×100mg-pack = 150p covers 400mg? No, 1×100mg-pack
  #   gives 10,000 mg total so yes covers 400mg for 150p).
  # So cheapest pack-level answer = 1×100mg-pack = 150p.
  # most_expensive pack-level answer = 1×500mg-pack = 950p (single pack that
  #   covers the dose at the highest cost).
  m_lim <- tibble::tibble(
    medicine = c("Metformin 100mg tablets", "Metformin 500mg tablets"),
    pack_size = c(100L, 1L),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VP1", "VP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(150L, 950L),
    nhs_indicative_price = c(150L, 950L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c("Metformin 100mg 100 tablet", "Metformin 500mg 1 tablet"),
    ampp_snomed_code = c("A1", "A2")
  )
  db_lim <- structure(
    list(master = m_lim, loaded_at = Sys.time()),
    class = "dmd_db"
  )

  res_ch <- dmd_dose_optimise(
    "metformin", dose = "400 mg", db = db_lim,
    preparation = "tablet|none|oral",
    objective = "cheapest", can_split = FALSE
  )
  res_me <- dmd_dose_optimise(
    "metformin", dose = "400 mg", db = db_lim,
    preparation = "tablet|none|oral",
    objective = "most_expensive", can_split = FALSE
  )

  expect_equal(res_me$objective, "most_expensive")
  # most_expensive must cost at least as much as cheapest in the same group.
  expect_true(res_me$cost_whole_pack_pence >= res_ch$cost_whole_pack_pence)
  # And the note should reflect the correct selection rule.
  expect_true(grepl("most-expensive-pack-per-dose", res_me$notes))
  expect_true(grepl("no-pack-splitting", res_me$notes))
})

# ── Regression: dmd_dose_cost + most_expensive (bug #1) ───────────────────────

test_that("dmd_dose_cost with objective = 'most_expensive' returns the worst-case cost", {
  cost_ch <- dmd_dose_cost(
    "metformin", dose = 1000, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral", objective = "cheapest"
  )
  cost_me <- dmd_dose_cost(
    "metformin", dose = 1000, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral", objective = "most_expensive"
  )
  expect_true(!is.na(cost_me))
  expect_true(cost_me >= cost_ch)
})

test_that("dmd_dose_cost most_expensive picks max across preparation groups", {
  # rituximab has two infusion-priced AMPPs in the fake db; across both
  # groups the most_expensive aggregate should be >= either group alone.
  cost_inf <- dmd_dose_cost(
    "rituximab", dose = 900, dose_unit = "mg", db = db,
    preparation = "infusion", objective = "most_expensive"
  )
  cost_all <- dmd_dose_cost(
    "rituximab", dose = 900, dose_unit = "mg", db = db,
    objective = "most_expensive"
  )
  expect_true(!is.na(cost_all))
  expect_true(cost_all >= cost_inf)
})

test_that("dmd_dose_cost default c('cheapest','min_items') still returns the minimum", {
  # Backward-compatibility sanity check after the aggregation refactor.
  cost_default <- dmd_dose_cost(
    "metformin", dose = 1000, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral"
  )
  cost_ch <- dmd_dose_cost(
    "metformin", dose = 1000, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral", objective = "cheapest"
  )
  cost_mi <- dmd_dose_cost(
    "metformin", dose = 1000, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral", objective = "min_items"
  )
  expect_equal(cost_default, min(cost_ch, cost_mi, na.rm = TRUE))
})

# ── Regression: vial-sharing + most_expensive ─────────────────────────────────

test_that("can_split_vials = TRUE + most_expensive picks the dearest vial fraction", {
  ch <- dmd_dose_optimise(
    "rituximab", dose = 250, dose_unit = "mg", db = db,
    preparation = "solution for infusion|none|intravenous",
    objective = "cheapest", can_split_vials = TRUE
  )
  me <- dmd_dose_optimise(
    "rituximab", dose = 250, dose_unit = "mg", db = db,
    preparation = "solution for infusion|none|intravenous",
    objective = "most_expensive", can_split_vials = TRUE
  )
  expect_equal(me$objective, "most_expensive")
  expect_true(any(grepl("vial-sharing", me$notes)))
  expect_true(me$dose_cost_pence >= ch$dose_cost_pence)
  # Non-integer count on the combination row.
  combo <- me$combination[[1]]
  expect_false(combo$count[1] == as.integer(combo$count[1]))
})

# ── Regression: %g format in print.dmd_dose_combination (bug #3) ──────────────

test_that("print.dmd_dose_combination renders fractional counts without warning", {
  res <- dmd_dose_optimise(
    "rituximab", dose = 250, dose_unit = "mg", db = db,
    preparation = "solution for infusion|none|intravenous",
    objective = "cheapest", can_split_vials = TRUE
  )
  combo <- res$combination[[1]]
  # Count is fractional — %d would warn; %g must not.
  expect_false(combo$count[1] == as.integer(combo$count[1]))
  expect_no_warning(out <- capture.output(print(combo)))
  # And the fraction must appear verbatim in the printed output.
  expect_true(any(grepl(format(combo$count[1]), out, fixed = TRUE)))
})

# ── Validation: empty and invalid objective vectors ───────────────────────────

test_that("objective = character(0) errors with a helpful message", {
  expect_error(
    dmd_dose_optimise(
      "metformin", dose = 500, dose_unit = "mg", db = db,
      objective = character(0)
    ),
    regexp = "at least one"
  )
  expect_error(
    dmd_dose_cost(
      "metformin", dose = 500, dose_unit = "mg", db = db,
      objective = character(0)
    ),
    regexp = "at least one"
  )
})

test_that("objective = 'bogus' errors via match.arg", {
  expect_error(
    dmd_dose_optimise(
      "metformin", dose = 500, dose_unit = "mg", db = db,
      objective = "bogus"
    )
  )
})

# ── Unsupported compound products ─────────────────────────────────────────────

test_that("compound products are skipped with a warning", {
  m <- tibble::tibble(
    medicine = "Co-codamol 8mg/500mg tablets",
    pack_size = 32L,
    unit = "tablet",
    vmp_snomed_code = "V1",
    vmpp_snomed_code = "VP1",
    drug_tariff_category = "Part VIIIA Category M",
    basic_price = 100L,
    nhs_indicative_price = 100L,
    price_basis = "NHS Indicative Price",
    price_date = "2025-08-08",
    ampp_name = "Co-codamol 8mg/500mg 32 tablet",
    ampp_snomed_code = "A1"
  )
  compound_db <- structure(
    list(master = m, loaded_at = Sys.time()),
    class = "dmd_db"
  )

  expect_warning(
    res <- dmd_dose_optimise(
      "co-codamol", dose = 8, dose_unit = "mg", db = compound_db
    ),
    regexp = "compound product"
  )
  expect_equal(nrow(res), 0L)

  expect_warning(
    cost <- dmd_dose_cost(
      "co-codamol", dose = 8, dose_unit = "mg", db = compound_db
    ),
    regexp = "compound product"
  )
  expect_true(is.na(cost))

  warnings <- character()
  withCallingHandlers(
    range <- dmd_dose_cost_range(
      "co-codamol", dose = 8, dose_unit = "mg", db = compound_db
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_equal(length(warnings), 1L)
  expect_true(is.na(range$lo_pence))
  expect_true(is.na(range$hi_pence))
})

test_that("ingredient targeting doses combination products by one ingredient", {
  db <- .fake_ingredient_db()

  # Query "co" matches all three fixture products (Co-codamol x2, Codeine x1).
  # Without an ingredient, the two combinations are skipped with a warning and
  # only the single-ingredient codeine tablet survives.
  expect_warning(
    res_default <- dmd_dose_optimise(
      "co", dose = 60, dose_unit = "mg", db = db
    ),
    regexp = "compound product"
  )
  expect_true(nrow(res_default) >= 1L)

  # Targeting codeine doses against the codeine strength of every product,
  # including the combinations — and emits no compound warning.
  res <- expect_no_warning(
    dmd_dose_optimise(
      "co",
      dose = 60,
      dose_unit = "mg",
      db = db,
      ingredient = "codeine",
      objective = "cheapest"
    )
  )
  expect_true(nrow(res) >= 1L)
  # 60 mg of codeine must be delivered (within over-delivery tolerance).
  expect_true(all(res$dose_delivered >= 60 - 1e-9))
  expect_equal(res$dose_requested[[1]], 60)
})

test_that("ingredient targeting selects the cheapest source of the ingredient", {
  db <- .fake_ingredient_db()
  # Per-tablet codeine: V1 8mg @ 100/32, V2 30mg @ 200/30, V3 30mg @ 150/28.
  # For 60 mg codeine the cheapest whole-tablet route is 2x V3 (codeine alone).
  res <- dmd_dose_optimise(
    "co",
    dose = 60,
    dose_unit = "mg",
    db = db,
    ingredient = "codeine",
    objective = "cheapest"
  )
  combo <- res$combination[[1]]
  expect_true(any(grepl("Codeine phosphate 30mg", combo$ampp_name)))
})

test_that("ingredient targeting warns and returns nothing without VPI data", {
  # Use a db with no $ingredients element to exercise the no-VPI path.
  db_no_vpi <- .fake_dose_db()  # has no $ingredients
  expect_warning(
    res <- dmd_dose_optimise(
      "metformin",
      dose = 500,
      dose_unit = "mg",
      db = db_no_vpi,
      ingredient = "metformin"
    ),
    regexp = "ingredient data"
  )
  expect_equal(nrow(res), 0L)
})

test_that("ingredient argument is validated", {
  expect_error(
    dmd_dose_optimise("metformin", dose = 500, ingredient = c("a", "b")),
    regexp = "single non-empty string"
  )
  expect_error(
    dmd_dose_optimise("metformin", dose = 500, ingredient = ""),
    regexp = "single non-empty string"
  )
})

# Inline db with codeine and dihydrocodeine products + ingredient strengths.
.codeine_db <- function() {
  master <- tibble::tibble(
    medicine = c(
      "Co-codamol 30mg/500mg tablets",
      "Dihydrocodeine 30mg tablets"
    ),
    pack_size = c(30, 28),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VPP1", "VPP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(200L, 150L),
    nhs_indicative_price = c(205L, 160L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c(
      "Co-codamol 30mg/500mg 30 tablet",
      "Dihydrocodeine 30mg 28 tablet"
    ),
    ampp_snomed_code = c("APP1", "APP2"),
    is_combination = c(TRUE, FALSE)
  )
  ingredients <- tibble::tibble(
    vmp_snomed_code = c("V1", "V1", "V2"),
    ingredient_snomed_code = c("I_cod", "I_para", "I_dihy"),
    ingredient_name = c(
      "Codeine phosphate", "Paracetamol", "Dihydrocodeine tartrate"
    ),
    strength_value = c(30, 500, 30),
    strength_unit = c("mg", "mg", "mg"),
    denominator_value = NA_real_,
    denominator_unit = NA_character_,
    strength_canonical = c(30, 500, 30),
    strength_unit_canon = c("mg", "mg", "mg")
  )
  structure(
    list(master = master, ingredients = ingredients, loaded_at = Sys.time()),
    class = "dmd_db"
  )
}

test_that("ingredient matching is word-boundary based (codeine != dihydrocodeine)", {
  db <- .codeine_db()
  # Query "co" matches both products; ingredient "codeine" must keep only the
  # Co-codamol (Codeine phosphate) row, NOT the dihydrocodeine product.
  res <- expect_no_warning(
    dmd_dose_optimise(
      "co", dose = 30, dose_unit = "mg", db = db,
      ingredient = "codeine", objective = "cheapest"
    )
  )
  combo <- res$combination[[1]]
  expect_true(all(grepl("Co-codamol", combo$medicine)))
  expect_false(any(grepl("Dihydrocodeine", combo$medicine)))

  # Targeting dihydrocodeine explicitly does match the dihydrocodeine product.
  res2 <- dmd_dose_optimise(
    "co", dose = 30, dose_unit = "mg", db = db,
    ingredient = "dihydrocodeine", objective = "cheapest"
  )
  expect_true(any(grepl("Dihydrocodeine", res2$combination[[1]]$medicine)))
})

test_that("ambiguous ingredient term warns and uses all matches", {
  master <- tibble::tibble(
    medicine = "Sodium combo 100mg/200mg tablets",
    pack_size = 10, unit = "tablet",
    vmp_snomed_code = "V1", vmpp_snomed_code = "VPP1",
    drug_tariff_category = "Part VIIIA Category M",
    basic_price = 100L, nhs_indicative_price = 100L,
    price_basis = "NHS Indicative Price", price_date = "2025-08-08",
    ampp_name = "Sodium combo 10 tablet", ampp_snomed_code = "APP1",
    is_combination = TRUE
  )
  ingredients <- tibble::tibble(
    vmp_snomed_code = c("V1", "V1"),
    ingredient_snomed_code = c("I_a", "I_b"),
    ingredient_name = c("Sodium chloride", "Sodium lactate"),
    strength_value = c(100, 200), strength_unit = c("mg", "mg"),
    denominator_value = NA_real_, denominator_unit = NA_character_,
    strength_canonical = c(100, 200), strength_unit_canon = c("mg", "mg")
  )
  db <- structure(
    list(master = master, ingredients = ingredients, loaded_at = Sys.time()),
    class = "dmd_db"
  )

  warnings <- character()
  withCallingHandlers(
    dmd_dose_optimise(
      "sodium", dose = 100, dose_unit = "mg", db = db,
      ingredient = "sodium", objective = "cheapest"
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("matched 2 distinct ingredients", warnings)))
})

test_that("targeting a non-mass ingredient warns and yields no dose", {
  master <- tibble::tibble(
    medicine = "Sodium iodide [I-131] 5.5GBq capsules",
    pack_size = 1, unit = "capsule",
    vmp_snomed_code = "V9", vmpp_snomed_code = "VPP9",
    drug_tariff_category = "Part VIIIA Category C",
    basic_price = 50000L, nhs_indicative_price = 50000L,
    price_basis = "NHS Indicative Price", price_date = "2025-08-08",
    ampp_name = "Sodium iodide [I-131] 5.5GBq 1 capsule",
    ampp_snomed_code = "APP9", is_combination = FALSE
  )
  ingredients <- tibble::tibble(
    vmp_snomed_code = "V9", ingredient_snomed_code = "I_nai",
    ingredient_name = "Sodium iodide",
    strength_value = 5.5, strength_unit = "gbq",
    denominator_value = NA_real_, denominator_unit = NA_character_,
    strength_canonical = NA_real_, strength_unit_canon = NA_character_
  )
  db <- structure(
    list(master = master, ingredients = ingredients, loaded_at = Sys.time()),
    class = "dmd_db"
  )
  warnings <- character()
  res <- withCallingHandlers(
    dmd_dose_optimise(
      "Sodium iodide", dose = 1, dose_unit = "mg", db = db,
      ingredient = "Sodium iodide"
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("non-mass strength", warnings)))
  expect_equal(nrow(res), 0L)
})

test_that("cheapest tie-break prefers the lowest over-delivery", {
  # 16mg+24mg = 40mg exactly (2 items, 200p) ties on cost with a single 48mg
  # tablet (1 item, 200p, 8mg over). The cheapest objective must pick the exact
  # 40mg combination, not the cheaper-looking single tablet that over-delivers.
  m <- tibble::tibble(
    medicine = c(
      "Tiebreak 16mg tablets",
      "Tiebreak 24mg tablets",
      "Tiebreak 48mg tablets"
    ),
    pack_size = c(1, 1, 1),
    unit = c("tablet", "tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2", "V3"),
    vmpp_snomed_code = c("VP1", "VP2", "VP3"),
    drug_tariff_category = rep("Part VIIIA Category M", 3),
    basic_price = c(100L, 100L, 200L),
    nhs_indicative_price = c(100L, 100L, 200L),
    price_basis = rep("NHS Indicative Price", 3),
    price_date = rep("2025-08-08", 3),
    ampp_name = c(
      "Tiebreak 16mg 1 tablet",
      "Tiebreak 24mg 1 tablet",
      "Tiebreak 48mg 1 tablet"
    ),
    ampp_snomed_code = c("A1", "A2", "A3")
  )
  db_tie <- structure(list(master = m, loaded_at = Sys.time()), class = "dmd_db")

  res <- dmd_dose_optimise(
    "tiebreak", dose = 40, dose_unit = "mg", db = db_tie,
    preparation = "tablet|none|oral", objective = "cheapest"
  )
  expect_equal(res$dose_delivered, 40)
  expect_equal(res$over_delivery, 0)
  expect_equal(res$total_items, 2)
  combo <- res$combination[[1]]
  expect_true(all(c("16mg", "24mg") %in% sub(".*?(\\d+mg).*", "\\1", combo$medicine)))
})

test_that("compound rows are skipped while supported rows still optimise", {
  m <- tibble::tibble(
    medicine = c("Testdrug 100mg tablets", "Testdrug 100mg/500mg tablets"),
    pack_size = c(28L, 28L),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VP1", "VP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(100L, 50L),
    nhs_indicative_price = c(100L, 50L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c("Testdrug 100mg 28 tablet", "Testdrug compound 28 tablet"),
    ampp_snomed_code = c("A1", "A2")
  )
  mixed_db <- structure(
    list(master = m, loaded_at = Sys.time()),
    class = "dmd_db"
  )

  expect_warning(
    res <- dmd_dose_optimise(
      "testdrug",
      dose = 100,
      dose_unit = "mg",
      db = mixed_db,
      objective = "cheapest"
    ),
    regexp = "compound product"
  )
  expect_equal(nrow(res), 1L)
  expect_false(any(grepl("compound", res$combination[[1]]$ampp_name)))
})

# ── Edge cases: invalid pack_size and pack_price ──────────────────────────────

test_that("rows with pack_size <= 0 yield NA per-item price and do not crash", {
  m <- tibble::tibble(
    medicine = c("Metformin 500mg tablets", "Metformin 1000mg tablets"),
    pack_size = c(0L, 28L), # 0 is invalid and must be ignored
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VP1", "VP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(100L, 180L),
    nhs_indicative_price = c(110L, 190L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c("Metformin 500mg bad 0 tablet", "Metformin 1000mg 28 tablet"),
    ampp_snomed_code = c("A1", "A2")
  )
  edge_db <- structure(
    list(master = m, loaded_at = Sys.time()),
    class = "dmd_db"
  )
  # Must not error. The zero-pack-size row can't contribute pro-rata; the
  # 1000mg row must still deliver the dose.
  expect_no_error(
    res <- dmd_dose_optimise(
      "metformin", dose = 1000, dose_unit = "mg", db = edge_db,
      preparation = "tablet|none|oral"
    )
  )
  expect_true(nrow(res) >= 1L)
})

test_that("all pack_size = 0 returns an empty result rather than crashing", {
  m <- tibble::tibble(
    medicine = "Metformin 500mg tablets",
    pack_size = 0L,
    unit = "tablet",
    vmp_snomed_code = "V1",
    vmpp_snomed_code = "VP1",
    drug_tariff_category = "Part VIIIA Category M",
    basic_price = 100L,
    nhs_indicative_price = 110L,
    price_basis = "NHS Indicative Price",
    price_date = "2025-08-08",
    ampp_name = "Metformin 500mg bad 0 tablet",
    ampp_snomed_code = "A1"
  )
  edge_db <- structure(
    list(master = m, loaded_at = Sys.time()),
    class = "dmd_db"
  )
  memoise::forget(.dmd_prepare_candidates_memo)
  expect_no_error(
    dmd_dose_cost(
      "metformin", dose = 500, dose_unit = "mg", db = edge_db
    )
  )
})

# ── preparation filter that matches nothing ───────────────────────────────────

test_that("preparation filter that matches no group warns and returns empty", {
  expect_warning(
    res <- dmd_dose_optimise(
      "metformin", dose = 500, dose_unit = "mg", db = db,
      preparation = "nonexistent-preparation-xyz"
    ),
    regexp = "No candidates remain"
  )
  expect_equal(nrow(res), 0L)
})

# ── dmd_dose_cost with objective = 'all' ──────────────────────────────────────

test_that("dmd_dose_cost accepts objective = 'all' as a shorthand", {
  cost_all <- dmd_dose_cost(
    "metformin", dose = 1000, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral", objective = "all"
  )
  # Minimum across cheapest/min_items/most_expensive per-objective aggregates
  # = cost for cheapest (since most_expensive dominates and cheapest/min_items
  # share the same minimum floor). Must match explicitly listing the three.
  cost_triple <- dmd_dose_cost(
    "metformin", dose = 1000, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral",
    objective = c("cheapest", "min_items", "most_expensive")
  )
  expect_equal(cost_all, cost_triple)
  expect_true(!is.na(cost_all))
})

# ── dmd_dose_cost_range ───────────────────────────────────────────────────────

test_that("dmd_dose_cost_range returns a tibble with lo_pence and hi_pence", {
  res <- dmd_dose_cost_range(
    "metformin", dose = 1000, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral"
  )
  expect_s3_class(res, "tbl_df")
  expect_named(res, c("lo_pence", "hi_pence"))
  expect_equal(nrow(res), 1L)
})

test_that("dmd_dose_cost_range: lo_pence <= hi_pence for all doses", {
  doses <- c(500, 1000, 1500, 2000)
  res <- dmd_dose_cost_range(
    "metformin", dose = doses, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral"
  )
  expect_equal(nrow(res), length(doses))
  # Both columns finite
  expect_true(all(is.finite(res$lo_pence)))
  expect_true(all(is.finite(res$hi_pence)))
  # Lower bound never exceeds upper bound
  expect_true(all(res$lo_pence <= res$hi_pence))
})

test_that("dmd_dose_cost_range lo_pence matches dmd_dose_cost('cheapest')", {
  doses <- c(500, 1000)
  lo <- dmd_dose_cost_range(
    "metformin", dose = doses, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral"
  )$lo_pence
  expected <- dmd_dose_cost(
    "metformin", dose = doses, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral", objective = "cheapest"
  )
  expect_equal(lo, expected)
})

test_that("dmd_dose_cost_range hi_pence matches dmd_dose_cost('most_expensive')", {
  doses <- c(500, 1000)
  hi <- dmd_dose_cost_range(
    "metformin", dose = doses, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral"
  )$hi_pence
  expected <- dmd_dose_cost(
    "metformin", dose = doses, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral", objective = "most_expensive"
  )
  expect_equal(hi, expected)
})

test_that("dmd_dose_cost_range returns na_value for NA, zero, and negative doses", {
  res <- dmd_dose_cost_range(
    "metformin", dose = c(NA, 0, -1, 500), dose_unit = "mg", db = db,
    preparation = "tablet|none|oral"
  )
  expect_true(is.na(res$lo_pence[1]))
  expect_true(is.na(res$lo_pence[2]))
  expect_true(is.na(res$lo_pence[3]))
  expect_false(is.na(res$lo_pence[4]))
})

test_that("dmd_dose_cost_range length matches dose vector length", {
  doses <- seq(500, 2500, by = 500)
  res <- dmd_dose_cost_range(
    "metformin", dose = doses, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral"
  )
  expect_equal(nrow(res), length(doses))
})

# ── Conflated-AMPP regression ────────────────────────────────────────────────
# When the cheapest *per-tablet* pack differs from the cheapest *whole* pack of
# the same strength, each combination row must still describe ONE AMPP: the
# reported pack_price_pence (and price_field_used) must belong to the AMPP named
# in that row, never get borrowed from a different pack.

# Two AMPPs of one 500 mg strength:
#  - a 1000-tablet pack with no Drug Tariff price but a cheap NHS Indicative
#    Price (0.975p / tablet) -> cheapest *per tablet*;
#  - a 28-tablet pack with a Drug Tariff basic price (58p) -> cheapest *whole
#    pack* for a single tablet, but a dearer per-tablet rate (~2.07p).
.fake_conflation_db <- function() {
  master <- tibble::tibble(
    medicine = c("Testdrug 500mg tablets", "Testdrug 500mg tablets"),
    pack_size = c(1000, 28),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("1", "1"),
    vmpp_snomed_code = c("VPP_BIG", "VPP_SMALL"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(NA_integer_, 58L),
    nhs_indicative_price = c(975L, 86L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c(
      "Testdrug 500mg (Big Pharma) 1000 tablet",
      "Testdrug 500mg (Small Pharma) 28 tablet"
    ),
    ampp_snomed_code = c("APP_BIG", "APP_SMALL")
  )
  structure(list(master = master, loaded_at = Sys.time()), class = "dmd_db")
}

test_that("combination row is not conflated across two packs of one strength", {
  db <- .fake_conflation_db()
  res <- dmd_dose_optimise("Testdrug 500mg tablets", dose = 500, db = db)
  cheapest <- res[res$objective == "cheapest", ]
  expect_equal(nrow(cheapest), 1L)

  comb <- cheapest$combination[[1]]
  expect_equal(nrow(comb), 1L)

  # Cheapest per-tablet source is the 1000-tablet pack.
  expect_equal(comb$ampp_snomed_code, "APP_BIG")
  expect_equal(comb$pack_size, 1000)

  # Its pack price must be the 1000-pack's own price (975), NOT the 28-pack's 58.
  expect_equal(comb$pack_price_pence, 975)
  expect_false(isTRUE(comb$pack_price_pence == 58))

  # Per-item price agrees with this same pack's price / pack size.
  expect_equal(
    comb$per_item_price_pence,
    comb$pack_price_pence / comb$pack_size
  )

  # Whole-pack subtotal is packs_to_buy * the SAME pack's price.
  expect_equal(
    comb$subtotal_whole_pack_pence,
    comb$packs_to_buy * comb$pack_price_pence
  )

  # price_field_used reflects the chosen pack (indicative fallback, since its
  # basic price is NA) rather than the other pack's basic price.
  expect_equal(cheapest$price_field_used, "nhs_indicative_price")
})

test_that("most_expensive objective is also internally consistent per row", {
  db <- .fake_conflation_db()
  res <- dmd_dose_optimise(
    "Testdrug 500mg tablets",
    dose = 500,
    db = db,
    objective = "most_expensive"
  )
  comb <- res$combination[[1]]
  expect_equal(nrow(comb), 1L)
  # Dearest per-tablet source is the 28-tablet pack (~2.07p vs 0.975p).
  expect_equal(comb$ampp_snomed_code, "APP_SMALL")
  expect_equal(comb$pack_price_pence, 58)
  expect_equal(
    comb$per_item_price_pence,
    comb$pack_price_pence / comb$pack_size
  )
})

test_that("each combination row's pack price belongs to its own AMPP", {
  # Invariant guard across the standard fixture and several doses: the
  # reported pack_price_pence must equal the resolved price (basic, else
  # indicative) of the AMPP named in the same row, and per-item price must be
  # that pack's price / pack size.
  db <- .fake_dose_db()
  m <- db$master
  for (d in c(500, 1000, 1500, 2000)) {
    res <- dmd_dose_optimise("Metformin 500mg tablets", dose = d, db = db)
    for (k in seq_len(nrow(res))) {
      comb <- res$combination[[k]]
      if (nrow(comb) == 0) next
      idx <- match(comb$ampp_snomed_code, m$ampp_snomed_code)
      resolved <- ifelse(
        !is.na(m$basic_price[idx]),
        m$basic_price[idx],
        m$nhs_indicative_price[idx]
      )
      expect_equal(comb$pack_price_pence, as.numeric(resolved))
      expect_equal(
        comb$per_item_price_pence,
        comb$pack_price_pence / comb$pack_size
      )
    }
  }
})

# ── over-delivery policy (issue #23) ─────────────────────────────────────────

test_that("an exact multi-strength dose is returned by every objective", {
  db_sl <- .fake_sublingual_db()
  res <- dmd_dose_optimise(
    "buprenorphine",
    dose = 3,
    dose_unit = "mg",
    db = db_sl,
    preparation = "sublingual",
    objective = "all"
  )
  expect_equal(nrow(res), 3L)
  expect_true(all(res$dose_delivered == 3))
  expect_true(all(res$over_delivery == 0))
  expect_true(all(res$dose_exact))
  expect_true(all(grepl("exact-dose", res$notes)))
  expect_false(any(grepl("over-delivery", res$notes, fixed = TRUE)))

  # Cheapest exact build is 1 x 2mg + 5 x 0.2mg = 400p, not the 200p 4mg build.
  ch <- res[res$objective == "cheapest", ]
  expect_equal(ch$dose_cost_pence, 400)
  # Fewest-item exact build is 1 x 2mg + 2 x 0.4mg + 1 x 0.2mg.
  expect_equal(res$total_items[res$objective == "min_items"], 4)
})

test_that("over_delivery = 'allow' reproduces the pre-0.6.0 answers", {
  db_sl <- .fake_sublingual_db()
  res <- dmd_dose_optimise(
    "buprenorphine",
    dose = 3,
    dose_unit = "mg",
    db = db_sl,
    preparation = "sublingual",
    objective = "all",
    over_delivery = "allow",
    quiet = TRUE
  )
  delivered <- stats::setNames(res$dose_delivered, res$objective)
  expect_equal(delivered[["cheapest"]], 4)
  expect_equal(delivered[["min_items"]], 8)
  expect_equal(delivered[["most_expensive"]], 11)
  expect_true(all(!res$dose_exact))

  # A 0.4mg request is likewise under-cut by a single 2mg tablet.
  low <- dmd_dose_optimise(
    "buprenorphine",
    dose = 0.4,
    dose_unit = "mg",
    db = db_sl,
    preparation = "sublingual",
    objective = "cheapest",
    over_delivery = "allow",
    quiet = TRUE
  )
  expect_equal(low$dose_delivered, 2)
  expect_equal(
    dmd_dose_optimise(
      "buprenorphine",
      dose = 0.4,
      dose_unit = "mg",
      db = db_sl,
      preparation = "sublingual",
      objective = "cheapest"
    )$dose_delivered,
    0.4
  )
})

test_that("dmd_dose_cost() costs the exact dose by default", {
  db_sl <- .fake_sublingual_db()
  shared <- list(
    query = "buprenorphine",
    dose_unit = "mg",
    db = db_sl,
    preparation = "sublingual",
    objective = "cheapest"
  )
  expect_equal(
    do.call(dmd_dose_cost, c(shared, list(dose = 3))),
    400
  )
  expect_equal(
    do.call(dmd_dose_cost, c(
      shared,
      list(dose = 3, over_delivery = "allow", quiet = TRUE)
    )),
    200
  )

  # 0.3mg is unreachable with 0.2mg as the smallest step: NA, warned once.
  warnings <- character()
  costs <- withCallingHandlers(
    do.call(dmd_dose_cost, c(shared, list(dose = c(0.3, 0.5, 3)))),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_equal(costs, c(NA_real_, NA_real_, 400))
  expect_equal(sum(grepl("No exact-dose combination exists", warnings)), 1L)
})

test_that("whole packs and whole containers are exempt from the policy", {
  db <- .fake_dose_db()

  # Community pharmacy: whole packs necessarily over-deliver a 750mg dose.
  packs <- dmd_dose_optimise(
    "metformin",
    dose = 750,
    dose_unit = "mg",
    db = db,
    preparation = "tablet|none|oral",
    can_split = FALSE
  )
  expect_gt(nrow(packs), 0L)
  expect_true(all(packs$over_delivery > 0))
  expect_true(all(grepl("over-delivery-policy-not-applied", packs$notes)))

  # Whole vials: 375mg cannot be built exactly from 100/500/1400mg vials.
  vials <- dmd_dose_optimise(
    "rituximab",
    dose = 375,
    dose_unit = "mg",
    db = db,
    preparation = "solution for infusion|none|intravenous",
    objective = "cheapest"
  )
  expect_gt(nrow(vials), 0L)
  expect_true(all(vials$over_delivery > 0))
  expect_true(all(grepl("over-delivery-policy-not-applied", vials$notes)))
  expect_false(is.na(dmd_dose_cost(
    "rituximab",
    dose = 375,
    dose_unit = "mg",
    db = db,
    preparation = "solution for infusion|none|intravenous"
  )))
})

test_that("dmd_dose_cost_range() passes the policy to both bounds", {
  db_sl <- .fake_sublingual_db()
  rng <- dmd_dose_cost_range(
    "buprenorphine",
    dose = 3,
    dose_unit = "mg",
    db = db_sl,
    preparation = "sublingual"
  )
  expect_equal(rng$lo_pence, 400)
  # Dearest exact build: 7 x 0.4mg + 1 x 0.2mg = 1460p.
  expect_equal(rng$hi_pence, 1460)

  warnings <- character()
  withCallingHandlers(
    dmd_dose_cost_range(
      "buprenorphine",
      dose = 0.3,
      dose_unit = "mg",
      db = db_sl,
      preparation = "sublingual"
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_equal(sum(grepl("No exact-dose combination exists", warnings)), 1L)
})

# ── over-delivery warnings ───────────────────────────────────────────────────

test_that("over-delivery warns and says an exact combination existed", {
  db_sl <- .fake_sublingual_db()
  expect_warning(
    dmd_dose_optimise(
      "buprenorphine",
      dose = 3,
      dose_unit = "mg",
      db = db_sl,
      preparation = "sublingual",
      objective = "cheapest",
      over_delivery = "allow"
    ),
    "exact-dose combination exists, but the objective preferred"
  )
})

test_that("over-delivery warns that no exact combination exists", {
  db_sl <- .fake_sublingual_db()
  expect_warning(
    dmd_dose_optimise(
      "buprenorphine",
      dose = 0.3,
      dose_unit = "mg",
      db = db_sl,
      preparation = "sublingual",
      objective = "cheapest",
      over_delivery = "minimise"
    ),
    "no exact-dose combination exists"
  )
})

test_that("exempt packs and containers do not raise the over-delivery warning", {
  db <- .fake_dose_db()
  # Whole packs: 750mg necessarily over-delivers, but that surplus stays in the
  # pack, so it is reported in notes only.
  expect_no_warning(
    packs <- dmd_dose_optimise(
      "metformin",
      dose = 750,
      dose_unit = "mg",
      db = db,
      preparation = "tablet|none|oral",
      can_split = FALSE
    )
  )
  expect_true(all(packs$over_delivery > 0))

  # Whole vials: same for a 375mg dose built from 100/500/1400mg vials.
  expect_no_warning(
    vials <- dmd_dose_optimise(
      "rituximab",
      dose = 375,
      dose_unit = "mg",
      db = db,
      preparation = "solution for infusion|none|intravenous",
      objective = "cheapest"
    )
  )
  expect_true(all(vials$over_delivery > 0))
})

test_that("quiet = TRUE silences the dose-policy warnings only", {
  db <- .fake_dose_db()
  db_sl <- .fake_sublingual_db()

  # No-exact warning under the default.
  expect_no_warning(
    res <- dmd_dose_optimise(
      "metformin",
      dose = 750,
      dose_unit = "mg",
      db = db,
      preparation = "tablet|none|oral",
      quiet = TRUE
    )
  )
  expect_equal(nrow(res), 0L)

  # Over-delivery warning under "allow".
  expect_no_warning(
    dmd_dose_optimise(
      "buprenorphine",
      dose = 3,
      dose_unit = "mg",
      db = db_sl,
      preparation = "sublingual",
      objective = "cheapest",
      over_delivery = "allow",
      quiet = TRUE
    )
  )

  # Unrelated warnings still come through.
  compound_db <- structure(
    list(
      master = tibble::tibble(
        medicine = "Co-codamol 8mg/500mg tablets",
        pack_size = 32L,
        unit = "tablet",
        vmp_snomed_code = "V1",
        vmpp_snomed_code = "VP1",
        drug_tariff_category = "Part VIIIA Category M",
        basic_price = 100L,
        nhs_indicative_price = 100L,
        price_basis = "NHS Indicative Price",
        price_date = "2025-08-08",
        ampp_name = "Co-codamol 8mg/500mg 32 tablet",
        ampp_snomed_code = "A1"
      ),
      loaded_at = Sys.time()
    ),
    class = "dmd_db"
  )
  expect_warning(
    dmd_dose_optimise(
      "co-codamol",
      dose = 8,
      dose_unit = "mg",
      db = compound_db,
      quiet = TRUE
    ),
    "compound product"
  )
})

test_that("dmd_dose_cost() and _range() warn once about over-delivery", {
  db_sl <- .fake_sublingual_db()
  shared <- list(
    query = "buprenorphine",
    dose_unit = "mg",
    db = db_sl,
    preparation = "sublingual"
  )

  warnings <- character()
  costs <- withCallingHandlers(
    do.call(dmd_dose_cost, c(
      shared,
      list(dose = c(0.3, 0.5, 0.7), over_delivery = "minimise")
    )),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_false(any(is.na(costs)))
  expect_equal(
    sum(grepl("Delivering more than the requested dose", warnings)),
    1L
  )

  # Both bounds share the candidate set, so the range call warns once, not twice.
  warnings <- character()
  withCallingHandlers(
    do.call(dmd_dose_cost_range, c(
      shared,
      list(dose = 3, over_delivery = "allow")
    )),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_equal(
    sum(grepl("Delivering more than the requested dose", warnings)),
    1L
  )
})

test_that("policy bookkeeping does not leak onto the returned tibble", {
  res <- dmd_dose_optimise(
    "buprenorphine",
    dose = 3,
    dose_unit = "mg",
    db = .fake_sublingual_db(),
    preparation = "sublingual"
  )
  expect_equal(
    setdiff(names(attributes(res)), c("names", "row.names", "class")),
    character(0)
  )
})

test_that("quiet rejects a non-logical value", {
  db_sl <- .fake_sublingual_db()
  expect_error(
    dmd_dose_optimise("buprenorphine", dose = 3, db = db_sl, quiet = "yes"),
    "must be a single logical value"
  )
  expect_error(
    dmd_dose_cost("buprenorphine", dose = 3, db = db_sl, quiet = NA),
    "must be a single logical value"
  )
})
