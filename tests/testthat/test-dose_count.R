# Products whose strength is per dose or actuation but whose pack is measured
# in ml or g (nicotine mouth sprays, lidocaine sprays, ispaghula granules), or
# whose pack and strength are in different physical units (a shampoo stated
# per g and sold in ml), give no reliable number of doses per pack: the dm+d
# records none. Such rows are excluded from dose optimisation with a warning
# instead of being costed as if each ml or g were one dose.
#
# The fixture is .fake_dose_count_db() (helper.R): those products beside the
# packs that must keep working (a 200-dose inhaler, a dose-measured nasal
# spray, a mg/ml bottle, a mg/g tube, a pack of ampoules, a multidose vaccine
# vial counted in doses, inhalation capsules), with VPI rows for nicotine,
# lidocaine and the inhaler.

db <- .fake_dose_count_db()

# The enriched candidate table for one or more literal queries, without the
# session memo.
.count_candidates <- function(queries, db = .fake_dose_count_db()) {
  rows <- lapply(queries, function(query) {
    .dmd_prepare_candidates(
      query = query,
      db = db,
      method = "partial",
      max_dist = 3,
      active_only = TRUE,
      price = "basic_price"
    )
  })
  out <- dplyr::bind_rows(rows)
  out[!duplicated(out$ampp_snomed_code), , drop = FALSE]
}

.unknown_count_warnings <- function(warnings) {
  Filter(function(w) inherits(w, "dmdprices_warning_unknown_dose_count"), warnings)
}

# ── Classification at enrichment ─────────────────────────────────────────────

test_that(".pack_dose_basis() tells reconciled packs from unknown dose counts", {
  cases <- tibble::tribble(
    ~denominator_unit, ~unit,       ~basis,
    NA,                "tablet",    "item",
    "ml",              "ml",        "pack",
    "ml",              "litre",     "pack",
    "g",               "g",         "pack",
    "g",               "mg",        "pack",
    "dose",            "dose",      "pack",
    "actuation",       "actuation", "pack",
    "ml",              "vial",      "container",
    "mg",              NA,          "container",
    "ml",              "dose",      "container",
    "dose",            "capsule",   "container",
    "actuation",       "dose",      "container",
    "hour",            "ml",        "container",
    "dose",            "ml",        "unknown",
    "dose",            "g",         "unknown",
    "dose",            "litre",     "unknown",
    "actuation",       "ml",        "unknown",
    "g",               "ml",        "unknown",
    "ml",              "g",         "unknown"
  )
  cases$pack_size <- 1
  expect_equal(.pack_dose_basis(cases), cases$basis)
})

test_that("a per-dose strength in an ml or g pack has no per-item dose", {
  enriched <- .count_candidates(c("spray", "granules", "shampoo"))
  enriched <- enriched[order(enriched$medicine, method = "radix"), , drop = FALSE]
  unknown <- enriched$dose_basis == "unknown"
  expect_equal(
    enriched$medicine[unknown],
    c(
      "Clobetasol 500micrograms/g shampoo",
      "Flurbiprofen 2.92mg/actuation oromucosal spray sugar free",
      "Ispaghula husk 3.5g/dose effervescent granules gluten free sugar free",
      "Lidocaine 10mg/dose spray sugar free",
      "Nicotine 1mg/dose oromucosal spray sugar free",
      "Nicotine 1mg/dose oromucosal spray sugar free"
    )
  )
  expect_equal(enriched$per_item_dose[unknown], rep(NA_real_, 6))
  expect_equal(enriched$items_per_pack[unknown], rep(NA_real_, 6))
  expect_equal(enriched$per_item_price_pence[unknown], rep(NA_real_, 6))
})

test_that("the warning lists three products and counts the rest", {
  enriched <- .count_candidates(c("spray", "granules", "shampoo"))
  expect_snapshot(kept <- .drop_unknown_dose_counts(enriched))
  expect_false(any(kept$dose_basis == "unknown"))
})

test_that("packs whose dose count is known keep their per-item dose", {
  enriched <- .count_candidates(c(
    "inhaler", "nasal spray", "oral solution", "cream", "ampoules",
    "Covivax", "capsules", "Benzydamine"
  ))
  enriched <- enriched[order(enriched$medicine, method = "radix"), , drop = FALSE]
  expect_equal(enriched$dose_basis, c(
    "pack", # Benzydamine 150micrograms/dose oromucosal spray, 30 dose
    "container", # Covivax 30micrograms/0.3ml dose ... vials, 10 dose
    "pack", # Delgocitinib 20mg/g cream, 60 g
    "pack", # Fluticasone 50micrograms/dose nasal spray, 150 dose
    "pack", # Morphine 10mg/5ml oral solution, 100 ml
    "pack", # Salbutamol 100micrograms/dose inhaler, 200 dose
    "container", # Salbutamol 500micrograms/1ml ampoules, 5 ampoule
    "container" # Tiotropium 18micrograms/dose inhalation powder capsules, 30 capsule
  ))
  expect_equal(
    enriched$per_item_dose,
    c(4.5, 0.03, 1200, 7.5, 200, 20, 0.5, 0.018)
  )
  expect_equal(enriched$items_per_pack, c(1, 10, 1, 1, 1, 1, 5, 30))
})

# ── Exclusion with one warning per call ──────────────────────────────────────

test_that("a product with an unknown dose count returns no row and a classed warning", {
  .local_fresh_dose_cache()
  got <- .with_warnings(dmd_dose_optimise(
    "Nicotine",
    dose = 1,
    dose_unit = "mg",
    db = db,
    objective = "cheapest"
  ))
  expect_equal(nrow(got$value), 0L)
  unknown <- .unknown_count_warnings(got$conditions)
  expect_length(unknown, 1L)
  expect_match(
    conditionMessage(unknown[[1]]),
    "number of doses per pack is unknown",
    fixed = TRUE
  )
  expect_match(
    conditionMessage(unknown[[1]]),
    "Nicotine 1mg/dose oromucosal spray sugar free",
    fixed = TRUE
  )
  expect_equal(
    unknown[[1]]$medicines,
    "Nicotine 1mg/dose oromucosal spray sugar free"
  )
})

test_that("the warning text names the products and the reason", {
  .local_fresh_dose_cache()
  # Of the six spray products, the three sold in ml are skipped; the two
  # dose-measured ones (benzydamine 4.5 mg exactly, fluticasone as a whole
  # 7.5 mg container) are costed.
  expect_snapshot(
    res <- dmd_dose_optimise(
      "spray",
      dose = 4.5,
      dose_unit = "mg",
      db = db,
      objective = "cheapest",
      over_delivery = "minimise"
    )
  )
  expect_equal(nrow(res), 2L)
})

test_that("ingredient targeting classifies the dose count from the VPI denominator", {
  .local_fresh_dose_cache()
  # Nicospray's name gives no strength; only its VPI row (1 mg per 1 dose)
  # reveals that its 13.2 ml bottle holds an unknown number of doses.
  got <- .with_warnings(dmd_dose_cost(
    "Nicospray",
    dose = 1,
    dose_unit = "mg",
    db = db,
    ingredient = "Nicotine"
  ))
  expect_equal(got$value, NA_real_)
  expect_length(.unknown_count_warnings(got$conditions), 1L)
  expect_equal(
    .unknown_count_warnings(got$conditions)[[1]]$medicines,
    "Nicospray oromucosal spray"
  )

  # Oilatine is one 250 ml bottle of 5 mg/ml by its name (1250 mg), but its
  # VPI strength is per gram, which an ml pack cannot count.
  expect_equal(
    dmd_dose_cost(
      "Oilatine",
      dose = 5,
      dose_unit = "mg",
      db = db,
      over_delivery = "minimise",
      quiet = TRUE
    ),
    700
  )
  got <- .with_warnings(dmd_dose_cost(
    "Oilatine",
    dose = 5,
    dose_unit = "mg",
    db = db,
    over_delivery = "minimise",
    ingredient = "Oilatine"
  ))
  expect_equal(got$value, NA_real_)
  expect_length(.unknown_count_warnings(got$conditions), 1L)
})

test_that("every route refuses to cost an unknown dose count", {
  .local_fresh_dose_cache()
  shared <- list(query = "Nicotine", dose_unit = "mg", db = db)
  for (extra in list(
    list(),
    list(can_split = FALSE),
    list(can_split_vials = TRUE),
    list(over_delivery = "allow"),
    list(ingredient = "Nicotine")
  )) {
    got <- .with_warnings(
      do.call(dmd_dose_cost, c(shared, list(dose = c(1, 150)), extra))
    )
    expect_equal(got$value, c(NA_real_, NA_real_))
    expect_length(.unknown_count_warnings(got$conditions), 1L)
  }

  got <- .with_warnings(
    dmd_dose_cost("Lidocaine", dose = 10, dose_unit = "mg", db = db, ingredient = "Lidocaine")
  )
  expect_equal(got$value, NA_real_)
  expect_length(.unknown_count_warnings(got$conditions), 1L)
})

test_that("the cost range warns once for both bounds", {
  .local_fresh_dose_cache()
  got <- .with_warnings(dmd_dose_cost_range(
    "Nicotine",
    dose = c(1, 150),
    dose_unit = "mg",
    db = db
  ))
  expect_equal(got$value$lo_pence, c(NA_real_, NA_real_))
  expect_equal(got$value$hi_pence, c(NA_real_, NA_real_))
  expect_length(.unknown_count_warnings(got$conditions), 1L)
})

test_that("a group keeps its reconciled rows when others have unknown dose counts", {
  .local_fresh_dose_cache()
  got <- .with_warnings(dmd_dose_optimise(
    "oromucosal spray",
    dose = 4.5,
    dose_unit = "mg",
    db = db,
    objective = "cheapest"
  ))
  expect_equal(nrow(got$value), 1L)
  combo <- got$value$combination[[1]]
  expect_equal(combo$medicine, "Benzydamine 150micrograms/dose oromucosal spray sugar free")
  expect_equal(got$value$dose_cost_pence, 400)
  unknown <- .unknown_count_warnings(got$conditions)
  expect_length(unknown, 1L)
  expect_setequal(unknown[[1]]$medicines, c(
    "Nicotine 1mg/dose oromucosal spray sugar free",
    "Flurbiprofen 2.92mg/actuation oromucosal spray sugar free"
  ))
})

test_that("quiet = TRUE does not silence the unknown-dose-count warning", {
  .local_fresh_dose_cache()
  got <- .with_warnings(dmd_dose_cost(
    "Nicotine",
    dose = 1,
    dose_unit = "mg",
    db = db,
    quiet = TRUE
  ))
  expect_equal(got$value, NA_real_)
  expect_length(.unknown_count_warnings(got$conditions), 1L)
})

# ── Valid per-dose packs are untouched ───────────────────────────────────────

test_that("dose-measured packs and container counts still cost as before", {
  .local_fresh_dose_cache()
  expect_no_warning(
    inhaler <- dmd_dose_cost(
      "Salbutamol",
      dose = 20,
      dose_unit = "mg",
      db = db,
      preparation = "inhaler"
    )
  )
  expect_equal(inhaler, 150)
  expect_equal(
    dmd_dose_cost(
      "Salbutamol",
      dose = 20,
      dose_unit = "mg",
      db = db,
      preparation = "inhaler",
      ingredient = "Salbutamol"
    ),
    150
  )
  expect_equal(
    dmd_dose_cost("Fluticasone", dose = 7.5, dose_unit = "mg", db = db),
    300
  )
  expect_equal(
    dmd_dose_cost("Covivax", dose = 0.03, dose_unit = "mg", db = db),
    50
  )
  expect_equal(
    dmd_dose_cost("Tiotropium", dose = 0.018, dose_unit = "mg", db = db),
    2000 / 30
  )
})
