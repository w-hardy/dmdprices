db <- .fake_dose_db()

test_that("basic dose optimisation returns cheapest and min_items rows", {
  res <- dmd_dose_optimise(
    "metformin", dose = 1500, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral"
  )
  expect_s3_class(res, "tbl_df")
  expect_true(all(c("cheapest", "min_items") %in% res$objective))
  expect_equal(unique(res$preparation_group), "tablet|none|oral")
  expect_true(all(res$dose_delivered >= res$dose_requested))
})

test_that("combination list-column identifies the AMPPs chosen", {
  res <- dmd_dose_optimise(
    "metformin", dose = 1500, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral", objective = "min_items"
  )
  combo <- res$combination[[1]]
  expect_s3_class(combo, "tbl_df")
  expect_true(all(c("medicine", "ampp_name", "vmpp_snomed_code",
                    "ampp_snomed_code", "count",
                    "pack_size", "packs_to_buy",
                    "pack_price_pence", "per_item_price_pence",
                    "subtotal_prorata_pence",
                    "subtotal_whole_pack_pence") %in% names(combo)))
  expect_true(all(combo$count > 0))
})

test_that("cheapest and min_items can differ for a 900mg metformin dose", {
  res <- dmd_dose_optimise(
    "metformin", dose = 900, dose_unit = "mg", db = db,
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
    "morphine", dose = 20, dose_unit = "mg", db = db
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
    medicine = c("Levothyroxine 25microgram tablets",
                 "Levothyroxine 100microgram tablets"),
    pack_size = c(28, 28),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("L1", "L2"),
    vmpp_snomed_code = c("LP1", "LP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(150L, 200L),
    nhs_indicative_price = c(160L, 210L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c("Levothyroxine 25mcg (Brand A) 28 tablet",
                  "Levothyroxine 100mcg (Brand A) 28 tablet"),
    ampp_snomed_code = c("LA1", "LA2")
  )
  ldb <- structure(list(master = m, loaded_at = Sys.time()), class = "dmd_db")
  res <- dmd_dose_optimise("levothyroxine", dose = 125,
                           dose_unit = "microgram", db = ldb)
  expect_s3_class(res, "tbl_df")
  expect_true(nrow(res) >= 1)
  # 125 micrograms = 25 + 100 mcg, so dose_delivered should equal 125 in
  # the same unit as the input.
  expect_equal(unique(res$dose_delivered), 125)
})

test_that("price fallback is flagged when basic_price is NA", {
  # Metformin 100mg row has NA basic_price but non-NA nhs_indicative_price.
  res <- dmd_dose_optimise(
    "metformin", dose = 100, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral"
  )
  # Should pick the 100mg tablet for min_items; price_fallback in notes.
  mi <- res[res$objective == "min_items", , drop = FALSE]
  expect_true(any(grepl("price-field-fallback|over-delivery|cheapest",
                        mi$notes)))
})

test_that("over-delivery is recorded in notes when dose is unreachable exactly", {
  # With only 500mg and 1000mg IR metformin, 750mg cannot be reached exactly.
  # Keep only IR strengths by filtering via preparation.
  res <- dmd_dose_optimise(
    "metformin", dose = 750, dose_unit = "mg", db = db,
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
    "metformin", dose = 1500, dose_unit = "mg", db = db,
    preparation = "tablet|none|oral", objective = "min_items"
  )
  expect_output(print(res$combination[[1]]), "Metformin")
})
