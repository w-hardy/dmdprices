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
    "Dexamethasone 1.5mg/ml eye drops 0.3ml unit dose preservative free",
    "Glucotest 50mg/ml solution for infusion 500ml bags",
    "Morphine 10mg/1ml solution for injection ampoules",
    "Morphine 10mg/5ml oral solution",
    "Morphine 10mg/ml solution for injection ampoules",
    "Tirzepatide 12.5mg/0.6ml solution for injection 2.4ml pre-filled disposable devices"
  ))
  expect_equal(enriched$dose_basis, c(
    "container", "container", "container", "pack", "container", "container"
  ))
  expect_equal(enriched$per_item_dose, c(0.45, 25000, 10, 200, NA_real_, 50))
  expect_equal(enriched$items_per_pack, c(30, 10, 10, 1, 10, 4))
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
