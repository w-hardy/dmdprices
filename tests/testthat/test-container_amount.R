# The amount of drug in one container of a concentration (a vial, bag, bottle
# or unit dose) comes from the name: a bare container size in the strength's
# denominator dimension, else an explicit numeric strength denominator. When
# neither is stated the amount is unknown and the product is skipped with a
# classed warning, never dosed as one denominator unit.

db <- .fake_container_amount_db()

.unknown_amount_warnings <- function(conditions) {
  Filter(
    function(w) inherits(w, "dmdprices_warning_unknown_container_amount"),
    conditions
  )
}

.amount_candidates <- function(query) {
  .dmd_prepare_candidates(
    query = query,
    db = db,
    method = "partial",
    max_dist = 3,
    active_only = TRUE,
    price = "basic_price"
  )
}

test_that("a container's dose comes from the size its name states", {
  .local_fresh_dose_cache()
  enriched <- .amount_candidates("e")
  enriched <- enriched[order(enriched$medicine, method = "radix"), , drop = FALSE]
  expect_equal(enriched$medicine, c(
    "Aflitest 4mg/100microlitres solution for injection vials",
    "Dexamethasone 1.5mg/ml eye drops 0.3ml unit dose preservative free",
    "Glucotest 50mg/ml solution for infusion 500ml bags",
    "Heparitest 5,000units/1litre infusion bags",
    "Immunotest 2.5g/25ml solution for infusion vials and Hyalutest solution for infusion 1.25ml vials",
    "Lidotest 10mg/ml solution for injection ampoules 1/2 strength",
    "Mixtest 0.25mg/0.37ml solution for injection 1.5ml vials",
    "Mixtest 1mg/1ml solution for injection vials",
    "Mixtest 2mg/2ml solution for injection vials",
    "Morphine 10mg/1ml solution for injection ampoules",
    "Morphine 10mg/5ml oral solution",
    "Morphine 10mg/ml solution for injection ampoules",
    "Semaglutest 0.25mg/0.37ml solution for injection 1.5ml pre-filled disposable devices",
    "Tirzepatide 12.5mg/0.6ml solution for injection 2.4ml pre-filled disposable devices"
  ))
  expect_equal(enriched$dose_basis, c(
    "container", "container", "container", "container", "container",
    "container", "container", "container", "container", "container", "pack",
    "container", "container", "container"
  ))
  expect_equal(
    enriched$per_item_dose,
    c(
      4, 0.45, 25000, 5000, 2500, NA_real_, 0.25 * 1.5 / 0.37, 1, 2, 10, 200,
      NA_real_, 0.25 * 1.5 / 0.37, 50
    )
  )
  expect_equal(
    enriched$items_per_pack,
    c(1, 30, 10, 10, 1, 10, 1, 1, 1, 10, 1, 10, 4, 4)
  )
})

test_that("one off-grid container does not cost its group its exact combinations", {
  .local_fresh_dose_cache()
  # 1 mg and 2 mg vials (1,000p and 1,500p) beside a 1.0135 mg vial (2,000p):
  # 3 mg is still 1 mg + 2 mg exactly, 1 mg one vial, and 1.01 mg the 2 mg
  # vial (1,500p over-delivering) rather than the dearer off-grid one.
  three <- dmd_dose_optimise("Mixtest", dose = 3, dose_unit = "mg", db = db, objective = "cheapest")
  expect_true(three$dose_exact)
  expect_equal(three$dose_cost_pence, 2500)
  expect_equal(three$total_items, 2)
  expect_equal(
    dmd_dose_cost("Mixtest", dose = c(3, 1, 1.01), dose_unit = "mg", db = db),
    c(2500, 1000, 1500)
  )
  # Under min_items 1.01 mg is one vial either way, and the grid solver's own
  # tie rule (the least surplus, then cost) picks the 1.0135 mg vial (2,000p).
  expect_equal(
    dmd_dose_cost("Mixtest", dose = c(3, 1, 1.01), dose_unit = "mg", db = db, objective = "min_items"),
    c(2500, 1000, 2000)
  )
  # Only the off-grid vial reaches 1.02 mg in one container at the lowest
  # cost per item? No: the 2 mg vial (1,500p) still wins; 2.03 mg needs two
  # off-grid vials (4,000p) or 1 mg + 2 mg (2,500p).
  expect_equal(
    dmd_dose_cost("Mixtest", dose = c(1.02, 2.03), dose_unit = "mg", db = db),
    c(1500, 2500)
  )
  expect_equal(
    dmd_dose_cost("Mixtest", dose = 3, dose_unit = "mg", db = db, can_split = FALSE),
    2500
  )
})

test_that("a cost tie between the grid and a whole off-grid container goes to the least surplus", {
  .local_fresh_dose_cache()
  # With the 1.0135 mg vial priced like the 2 mg vial (1,500p), 1.01 mg costs
  # 1,500p in one vial either way: the 1.0135 mg vial wastes less, so it wins.
  tied <- db
  off <- tied$master$medicine == "Mixtest 0.25mg/0.37ml solution for injection 1.5ml vials"
  tied$master$basic_price[off] <- 1500L
  tied$master$nhs_indicative_price[off] <- 1500L
  for (objective in c("cheapest", "min_items")) {
    res <- dmd_dose_optimise("Mixtest", dose = 1.01, dose_unit = "mg", db = tied, objective = objective)
    expect_equal(res$dose_cost_pence, 1500, info = objective)
    expect_equal(res$total_items, 1, info = objective)
    expect_equal(res$dose_delivered, 0.25 * 1.5 / 0.37, info = objective)
  }
  packs <- dmd_dose_optimise(
    "Mixtest",
    dose = 1.01,
    dose_unit = "mg",
    db = tied,
    objective = "cheapest",
    can_split = FALSE
  )
  expect_equal(packs$dose_delivered, 0.25 * 1.5 / 0.37)
})

test_that("a whole container whose dose is off the solver's grid still covers the dose", {
  .local_fresh_dose_cache()
  # 0.25 mg per 0.37 ml in 1.5 ml devices: 1.0135... mg per device, which no
  # integer grid represents. Whole devices are policy-exempt, so one device
  # covers 0.25 mg, two cover 1.5 mg, one pack of four covers either, and vial
  # sharing draws the exact fraction.
  one <- dmd_dose_optimise("Semaglutest", dose = 0.25, dose_unit = "mg", db = db, objective = "cheapest")
  expect_equal(one$total_items, 1)
  expect_equal(one$dose_cost_pence, 7325)
  expect_equal(one$dose_delivered, 0.25 * 1.5 / 0.37)
  expect_match(one$notes, "over-delivery-policy-not-applied", fixed = TRUE)
  expect_equal(
    dmd_dose_cost("Semaglutest", dose = c(0.25, 1.5), dose_unit = "mg", db = db),
    c(7325, 14650)
  )
  expect_equal(
    dmd_dose_cost("Semaglutest", dose = c(0.25, 1.5), dose_unit = "mg", db = db, can_split = FALSE),
    c(29300, 29300)
  )
  expect_equal(
    dmd_dose_cost("Semaglutest", dose = 0.25, dose_unit = "mg", db = db, can_split_vials = TRUE),
    0.25 / (0.25 * 1.5 / 0.37) * 7325
  )
  expect_equal(
    dmd_dose_cost_range("Semaglutest", dose = 0.25, dose_unit = "mg", db = db)$hi_pence,
    7325
  )
})

test_that("a co-pack's second product does not size the first, and litre and microlitre denominators do", {
  .local_fresh_dose_cache()
  expect_equal(
    dmd_dose_cost("Immunotest", dose = 2.5, dose_unit = "g", db = db),
    17250
  )
  expect_equal(
    dmd_dose_cost("Aflitest", dose = 4, dose_unit = "mg", db = db),
    81600
  )
  expect_equal(
    dmd_dose_cost("Heparitest", dose = 5000, dose_unit = "unit", db = db),
    100
  )
  got <- .with_warnings(dmd_dose_cost("Lidotest", dose = 10, dose_unit = "mg", db = db))
  expect_equal(got$value, NA_real_)
  expect_length(.unknown_amount_warnings(got$conditions), 1L)
})

test_that("a container of unknown size returns no row and a classed warning", {
  .local_fresh_dose_cache()
  got <- .with_warnings(dmd_dose_optimise(
    "Morphine 10mg/ml",
    dose = 10,
    dose_unit = "mg",
    db = db,
    objective = "cheapest"
  ))
  expect_equal(nrow(got$value), 0L)
  unknown <- .unknown_amount_warnings(got$conditions)
  expect_length(unknown, 1L)
  expect_equal(
    unknown[[1]]$medicines,
    "Morphine 10mg/ml solution for injection ampoules"
  )
  expect_snapshot(
    res <- dmd_dose_optimise(
      "Morphine",
      dose = 10,
      dose_unit = "mg",
      db = db,
      preparation = "injection",
      objective = "cheapest"
    )
  )
  # The ampoule whose name states 1 ml is costed.
  expect_equal(res$combination[[1]]$medicine, "Morphine 10mg/1ml solution for injection ampoules")
  expect_equal(res$dose_cost_pence, 45)
})

test_that("every route refuses a container of unknown size", {
  .local_fresh_dose_cache()
  for (extra in list(
    list(),
    list(can_split = FALSE),
    list(can_split_vials = TRUE),
    list(over_delivery = "allow")
  )) {
    got <- .with_warnings(do.call(
      dmd_dose_cost,
      c(list("Morphine 10mg/ml", dose = c(10, 20), dose_unit = "mg", db = db), extra)
    ))
    expect_equal(got$value, c(NA_real_, NA_real_))
    expect_length(.unknown_amount_warnings(got$conditions), 1L)
  }
  got <- .with_warnings(dmd_dose_cost_range(
    "Morphine 10mg/ml",
    dose = c(10, 20),
    dose_unit = "mg",
    db = db
  ))
  expect_equal(got$value$lo_pence, c(NA_real_, NA_real_))
  expect_length(.unknown_amount_warnings(got$conditions), 1L)
})

test_that("the warning names only products the call would otherwise have costed, and quiet keeps it", {
  .local_fresh_dose_cache()
  got <- .with_warnings(dmd_dose_cost(
    "Morphine",
    dose = 200,
    dose_unit = "mg",
    db = db,
    preparation = "oral solution",
    over_delivery = "minimise"
  ))
  expect_equal(got$value, 300)
  expect_length(.unknown_amount_warnings(got$conditions), 0L)

  got <- .with_warnings(dmd_dose_cost(
    "Morphine 10mg/ml",
    dose = 10,
    dose_unit = "mg",
    db = db,
    quiet = TRUE
  ))
  expect_equal(got$value, NA_real_)
  expect_length(.unknown_amount_warnings(got$conditions), 1L)
})

test_that("a pre-filled device holds its whole stated volume", {
  .local_fresh_dose_cache()
  # 12.5 mg per 0.6 ml, in 2.4 ml devices: one device holds 50 mg and covers a
  # 12.5 mg dose as a whole container; vial sharing draws a quarter of it.
  res <- dmd_dose_optimise(
    "Tirzepatide",
    dose = 12.5,
    dose_unit = "mg",
    db = db,
    objective = "cheapest"
  )
  expect_equal(res$dose_delivered, 50)
  expect_equal(res$dose_cost_pence, 10000)
  shared <- dmd_dose_optimise(
    "Tirzepatide",
    dose = 12.5,
    dose_unit = "mg",
    db = db,
    objective = "cheapest",
    can_split_vials = TRUE
  )
  expect_equal(shared$dose_cost_pence, 2500)
  expect_true(shared$dose_exact)
})
