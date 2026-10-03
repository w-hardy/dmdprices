# Bracketed restatements and multi-product packs in dose optimisation (#27).

# Enrich bare names the way .dmd_prepare_candidates() does before it flags
# unsupported compounds: parsed strength, preparation and the dm+d flag.
.enrich_names <- function(nm, is_combination = FALSE) {
  parsed <- dmd_parse_strength(nm)
  parsed$is_combination <- NULL
  dplyr::bind_cols(
    tibble::tibble(medicine = nm, is_combination = is_combination),
    parsed,
    dmdprices:::.classify_preparation(parsed$tail)
  )
}

# Capture every warning `expr` raises, muffled, as a character vector.
.collect_warnings <- function(expr) {
  warnings <- character()
  withCallingHandlers(
    expr,
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  warnings
}

# ── Which names count as compounds ───────────────────────────────────────────

test_that("a bracketed restatement in another unit dimension is not a compound", {
  enriched <- .enrich_names(c(
    "Eptacog beta (activated) 1mg (45,000unit) powder and solvent for solution for injection vials",
    "Iohexol 755mg/ml (Iodine 350mg/ml) solution for injection 700ml plastic bottles",
    "Mexiletine hydrochloride 200mg (Mexiletine 167mg) capsules",
    "Factor VIII Inhibitor Bypassing Fraction human 25units/ml (500unit) powder and 20ml solvent for solution for infusion vials",
    "Testosterone 20mg/g transdermal gel (23mg per actuation) refill",
    "Danicopan 50mg tablets and Danicopan 100mg tablets"
  ))
  expect_equal(
    unname(dmdprices:::.is_unsupported_compound(enriched)),
    c(FALSE, TRUE, TRUE, TRUE, FALSE, TRUE)
  )
})

test_that("the dm+d combination flag still wins over a restatement", {
  enriched <- .enrich_names(
    "Eptacog beta (activated) 1mg (45,000unit) powder and solvent for solution for injection vials",
    is_combination = TRUE
  )
  expect_identical(unname(dmdprices:::.is_unsupported_compound(enriched)), TRUE)
})

test_that("a name-flagged combination gel is flagged, never NA", {
  # No denominator: the topical w/w exemption must be FALSE, not NA, or the row
  # is dropped without the skip warning.
  enriched <- .enrich_names(
    "Doxycycline 36.4mg/260mg periodontal gel cartridge"
  )
  expect_identical(unname(dmdprices:::.is_unsupported_compound(enriched)), TRUE)
})

# ── Restated products are dosed ──────────────────────────────────────────────

test_that("eptacog with a bracketed activity restatement is dosed by mass", {
  db <- .fake_multi_strength_db()
  res <- expect_no_warning(dmd_dose_optimise(
    "eptacog",
    dose = 7,
    dose_unit = "mg",
    db = db,
    objective = "min_items"
  ))
  expect_equal(nrow(res), 1L)
  expect_equal(res$dose_delivered, 7)
  expect_true(res$dose_exact)
  expect_equal(res$total_items, 2)
  expect_equal(res$dose_cost_pence, 3500)
})

test_that("a dose in the restated unit is not read as the mass strength", {
  db <- .fake_multi_strength_db()
  # 350,000 units never matches a mass row: it warns and returns nothing rather
  # than misreading the units as mg.
  expect_warning(
    res <- dmd_dose_optimise(
      "eptacog",
      dose = "350,000 units",
      db = db,
      objective = "min_items"
    ),
    "requested dose unit"
  )
  expect_equal(nrow(res), 0L)
})

test_that("dmd_dose_cost() costs restated products for each dose", {
  db <- .fake_multi_strength_db()
  cost <- expect_no_warning(
    dmd_dose_cost("eptacog", dose = c(7, 3), dose_unit = "mg", db = db)
  )
  expect_equal(cost, c(3500, 1500))
})

# ── Products that stay skipped ───────────────────────────────────────────────

test_that("a same-dimension bracketed strength keeps a product skipped", {
  db <- .fake_multi_strength_db()
  expect_warning(
    res <- dmd_dose_optimise(
      "iohexol",
      dose = 755,
      dose_unit = "mg",
      db = db,
      objective = "cheapest"
    ),
    "unsupported compound product"
  )
  expect_equal(nrow(res), 0L)
})

test_that("packs are skipped with a multi-product pack warning", {
  db <- .fake_multi_strength_db()
  # "s and " matches only the two packs ("...tablets and ...", "...vials
  # and ..."), not eptacog's "powder and solvent".
  expect_snapshot(
    res <- dmd_dose_optimise(
      "s and ",
      dose = 50,
      dose_unit = "mg",
      db = db,
      objective = "cheapest"
    )
  )
  expect_equal(nrow(res), 0L)
})

test_that("dmd_dose_cost_range() shows each skip warning once", {
  db <- .fake_multi_strength_db()
  # "solution" matches eptacog (dosable), iohexol (a compound) and the
  # tixagevimab co-pack. Both bounds see the same skipped rows.
  warnings <- .collect_warnings(
    range <- dmd_dose_cost_range(
      "solution",
      dose = 50,
      dose_unit = "mg",
      db = db
    )
  )
  expect_equal(sum(grepl("unsupported compound product", warnings)), 1L)
  expect_equal(sum(grepl("multi-product pack", warnings)), 1L)
  expect_length(warnings, 2L)
  # The compound warning names the compound, not the pack.
  compound <- warnings[grepl("unsupported compound product", warnings)]
  expect_match(compound, "Iohexol", fixed = TRUE)
  expect_no_match(compound, "Tixagevimab", fixed = TRUE)
  # 50 mg of eptacog at a flat 500p per mg, whichever syringes are used.
  expect_equal(range$lo_pence, 25000)
  expect_equal(range$hi_pence, 25000)
})
