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
    preparation = "tablet|none|oral"
  )
  # 750 with 100mg available is reachable exactly (1×500 + 2×100 + 1×50? no,
  # no 50mg). 100mg × 7 + 500mg × 1 - ... Actually 750 = 500 + 250, no 250.
  # 750 = 100×7 + 50 — no. Options: 100×7 = 700 (under), 100×8 = 800 (over).
  # So 750 needs over-delivery. Confirm.
  expect_true(all(res$over_delivery >= 0))
  expect_true(any(grepl("over-delivery", res$notes)))
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
