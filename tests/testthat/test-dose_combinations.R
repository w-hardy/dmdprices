# The requested dose is authoritative. The solver works on the integer grid of
# the group's strengths, but that grid is only a search space: a dose off the
# grid is never rounded onto it. Under "forbid" such a dose has no exact
# combination (every combination of grid strengths is on the grid); under
# "minimise" and "allow" the smallest acceptable target is the first grid
# point at or above the dose. No route delivers less than the dose.
#
# The fixture is .fake_grid_db() (helper.R): 1 mg tablets in packs of 100
# (9p each) and 10 (10p each), 1 mg/1 ml vials in a pack of 10 (100p each)
# and a 5 mg/5 ml vial (450p); plus the sublingual and eptacog fixtures for
# exactly representable decimals and a real-name case. The tiny-dose inhaler
# case lives in test-container-packs.R.

db <- .fake_grid_db()

.tablets <- function(dose, ...) {
  dmd_dose_optimise(
    "testdrug",
    dose = dose,
    dose_unit = "mg",
    db = db,
    preparation = "tablet",
    objective = "cheapest",
    ...
  )
}

# ── Grid helpers ─────────────────────────────────────────────────────────────

test_that(".grid_target() places the dose on or above the strengths' grid", {
  off <- .grid_target(2.4, 1)
  expect_false(off$on_grid)
  expect_equal(off$t_exact, NA_real_)
  expect_equal(off$t_lo, 3)

  float <- .grid_target(0.3 / 0.1, 1)
  expect_true(float$on_grid)
  expect_equal(float$t_exact, 3)
  expect_equal(float$t_lo, 3)

  fine <- .grid_target(2.4, 5)
  expect_true(fine$on_grid)
  expect_equal(fine$t_exact, 12)

  expect_equal(.grid_target(2.6, 1)$t_lo, 3)
  expect_equal(.grid_target(10.4, 1)$t_lo, 11)
})

test_that("the dose tolerance is one part in a billion, never below a billionth of a unit", {
  expect_equal(.dose_tol(3), 3e-9)
  expect_equal(.dose_tol(0.5), 1e-9)
  expect_true(.grid_target(3 - 2e-9, 1)$on_grid)
  off <- .grid_target(3 - 4e-9, 1)
  expect_false(off$on_grid)
  expect_equal(off$t_lo, 3)
})

test_that(".strengths_on_grid() accepts only whole numbers of grid units", {
  expect_true(.strengths_on_grid(c(0.1, 0.2), 10))
  expect_false(.strengths_on_grid(c(0.125, 1), 833))
  expect_true(.strengths_on_grid(numeric(), 1))
})

test_that(".pick_scale_safe() takes the strengths' scale and never raises it for the dose", {
  expect_equal(.pick_scale_safe(c(12, 20, 40), 0.1), 1)
  expect_equal(.pick_scale_safe(c(12, 20, 40), 0.00025), 1)
  expect_equal(.pick_scale_safe(c(0.5, 5), 0.1), 10)
  expect_equal(.pick_scale_safe(c(500, 1000), 750), 1)
  expect_equal(.pick_scale_safe(c(0.01, 5000), 0.006), 100)
})

# ── A dose off the grid: 2.4 mg and 2.6 mg against 1 mg tablets ──────────────

test_that("forbid returns no exact combination for a dose off the strengths' grid", {
  .local_fresh_dose_cache()
  for (dose in c(2.4, 2.6)) {
    got <- .with_warnings(.tablets(dose))
    expect_equal(nrow(got$value), 0L)
    expect_length(grep("No exact-dose combination exists", got$warnings), 1L)
    expect_length(grep("rounded", got$warnings), 0L)
  }
})

test_that("minimise delivers the first grid point above the dose", {
  .local_fresh_dose_cache()
  for (dose in c(2.4, 2.6)) {
    got <- .with_warnings(.tablets(dose, over_delivery = "minimise"))
    expect_equal(got$value$dose_delivered, 3)
    expect_equal(got$value$over_delivery, 3 - dose)
    expect_false(got$value$dose_exact)
    expect_equal(got$value$total_items, 3)
    expect_equal(got$value$dose_cost_pence, 27)
    expect_match(got$value$notes, "over-delivery-minimised", fixed = TRUE)
    expect_length(grep("Delivering more than the requested dose", got$warnings), 1L)
    expect_match(got$warnings, "no exact-dose combination exists", all = FALSE)
    expect_length(grep("rounded", got$warnings), 0L)
  }
})

test_that("allow never delivers less than the dose, whatever the objective", {
  .local_fresh_dose_cache()
  res <- dmd_dose_optimise(
    "testdrug",
    dose = 2.4,
    dose_unit = "mg",
    db = db,
    preparation = "tablet",
    objective = "all",
    over_delivery = "allow",
    quiet = TRUE
  )
  expect_equal(nrow(res), 3L)
  expect_gte(min(res$dose_delivered), 2.4)
  expect_gte(min(res$over_delivery), 0)
  expect_false(any(res$dose_exact))
  expect_equal(res$dose_delivered[res$objective == "cheapest"], 3)
  expect_equal(res$dose_delivered[res$objective == "min_items"], 3)
})

test_that("vectorised costs refuse or over-deliver an off-grid dose, never under-deliver", {
  .local_fresh_dose_cache()
  shared <- list(query = "testdrug", dose_unit = "mg", db = db, preparation = "tablet")

  got <- .with_warnings(
    do.call(dmd_dose_cost, c(shared, list(dose = c(2.4, 2.6, 3))))
  )
  expect_equal(got$value, c(NA_real_, NA_real_, 27))
  expect_length(grep("No exact-dose combination exists", got$warnings), 1L)

  expect_equal(
    do.call(dmd_dose_cost, c(shared, list(dose = c(2.4, 2.6, 3), over_delivery = "minimise", quiet = TRUE))),
    c(27, 27, 27)
  )

  got <- .with_warnings(
    do.call(dmd_dose_cost_range, c(shared, list(dose = c(2.4, 2.6, 3))))
  )
  expect_equal(got$value$lo_pence, c(NA_real_, NA_real_, 27))
  expect_equal(got$value$hi_pence, c(NA_real_, NA_real_, 30))
  expect_length(grep("No exact-dose combination exists", got$warnings), 1L)
})

test_that("the dose unit does not change where the dose sits on the grid", {
  .local_fresh_dose_cache()
  whole <- .tablets(2400, over_delivery = "minimise", quiet = TRUE)
  expect_equal(whole$dose_delivered, 2400)
  expect_true(whole$dose_exact)

  micro <- dmd_dose_optimise(
    "testdrug",
    dose = 2400,
    dose_unit = "microgram",
    db = db,
    preparation = "tablet",
    objective = "cheapest",
    over_delivery = "minimise",
    quiet = TRUE
  )
  expect_equal(micro$dose_delivered, 3000)
  expect_equal(micro$dose_delivered_unit, "microgram")
  expect_equal(micro$over_delivery, 600)

  grams <- dmd_dose_optimise(
    "testdrug",
    dose = "0.0024 g",
    db = db,
    preparation = "tablet",
    objective = "cheapest",
    over_delivery = "minimise",
    quiet = TRUE
  )
  expect_equal(grams$dose_delivered, 0.003)
  expect_equal(grams$dose_delivered_unit, "g")

  expect_equal(
    dmd_dose_cost(
      "testdrug",
      dose = 2400,
      dose_unit = "microgram",
      db = db,
      preparation = "tablet",
      quiet = TRUE
    ),
    NA_real_
  )
})

# ── Exactly representable decimals stay exact ────────────────────────────────

test_that("a decimal dose the strengths can build exactly is exact under forbid", {
  .local_fresh_dose_cache()
  sl <- .fake_sublingual_db()
  cases <- list(
    list(2.4, "mg"),
    list(2400, "microgram"),
    list(0.1 + 0.1 + 0.2, "mg"),
    list(0.3 / 0.1, "mg")
  )
  for (dose in cases) {
    res <- dmd_dose_optimise(
      "buprenorphine",
      dose = dose[[1]],
      dose_unit = dose[[2]],
      db = sl,
      preparation = "sublingual",
      objective = "cheapest"
    )
    expect_equal(nrow(res), 1L)
    expect_true(res$dose_exact)
    expect_equal(res$over_delivery, 0)
    expect_match(res$notes, "exact-dose", fixed = TRUE)
    expect_false(grepl("over-delivery", res$notes, fixed = TRUE))
  }
})

test_that("floating-point noise in the dose does not create a false mismatch", {
  .local_fresh_dose_cache()
  res <- .tablets(0.3 / 0.1)
  expect_equal(nrow(res), 1L)
  expect_true(res$dose_exact)
  expect_equal(res$total_items, 3)
  expect_equal(res$notes, "cheapest-AMPP-per-strength; exact-dose")
})

# ── A real name: eptacog alfa 6.3 mg against 1 / 2 / 5 mg syringes ───────────

test_that("a weight-based eptacog dose is refused under forbid and covered under minimise", {
  .local_fresh_dose_cache()
  ept <- .fake_multi_strength_db()
  got <- .with_warnings(dmd_dose_optimise(
    "eptacog",
    dose = 6.3,
    dose_unit = "mg",
    db = ept,
    objective = "cheapest"
  ))
  expect_equal(nrow(got$value), 0L)
  expect_length(grep("No exact-dose combination exists", got$warnings), 1L)

  res <- dmd_dose_optimise(
    "eptacog",
    dose = 6.3,
    dose_unit = "mg",
    db = ept,
    objective = c("cheapest", "min_items"),
    over_delivery = "minimise",
    quiet = TRUE
  )
  expect_equal(res$dose_delivered, c(7, 7))
  expect_equal(res$dose_cost_pence, c(3500, 3500))
  expect_equal(res$total_items[res$objective == "min_items"], 2)
})

# ── Whole containers and whole packs cover the dose, never under-deliver ─────

test_that("whole containers cover an off-grid dose with the smallest surplus", {
  .local_fresh_dose_cache()
  res <- dmd_dose_optimise(
    "testdrug",
    dose = 2.4,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "cheapest"
  )
  expect_equal(res$dose_delivered, 3)
  expect_equal(res$over_delivery, 0.6)
  expect_false(res$dose_exact)
  expect_equal(res$dose_cost_pence, 300)
  expect_match(res$notes, "over-delivery-policy-not-applied", fixed = TRUE)

  # 10.4 mg: two 5 mg vials and one 1 mg vial (1000p) beat eleven 1 mg vials.
  expect_equal(
    dmd_dose_cost("testdrug", dose = c(2.4, 10.4), dose_unit = "mg", db = db, preparation = "injection"),
    c(300, 1000)
  )

  # Vial sharing draws the exact fraction (0.48 of a 5 mg vial at 450p), so
  # the grid plays no part on that route.
  shared <- dmd_dose_optimise(
    "testdrug",
    dose = 2.4,
    dose_unit = "mg",
    db = db,
    preparation = "injection",
    objective = "cheapest",
    can_split_vials = TRUE
  )
  expect_true(shared$dose_exact)
  expect_equal(shared$dose_cost_pence, 216)
})

test_that("whole packs cover an off-grid dose", {
  .local_fresh_dose_cache()
  res <- dmd_dose_optimise(
    "testdrug",
    dose = 10.4,
    dose_unit = "mg",
    db = db,
    preparation = "tablet",
    objective = "cheapest",
    can_split = FALSE
  )
  expect_equal(res$dose_delivered, 20)
  expect_equal(res$total_items, 2)
  expect_equal(res$dose_cost_pence, 200)
  expect_false(res$dose_exact)
  expect_match(res$notes, "over-delivery", fixed = TRUE)
})

# ── Solver failures stay distinguishable from "no exact combination" ─────────

test_that("strengths the dose table cannot represent are refused, not mis-costed", {
  # 0.125 mg and 1 mg tablets need a scale of 1000, but a 6000.125 mg dose
  # caps the scale at 833, where 0.125 mg is 104.125 units: no integer grid
  # represents the strengths, so the group is refused as a precision failure
  # rather than solved on a grid whose totals do not match the items.
  .local_fresh_dose_cache()
  got <- .with_warnings(dmd_dose_optimise(
    "finedrug",
    dose = 6000.125,
    dose_unit = "mg",
    db = .fake_unresolvable_db(),
    preparation = "tablet",
    objective = "cheapest",
    over_delivery = "minimise"
  ))
  expect_equal(nrow(got$value), 0L)
  expect_length(grep("could not be resolved", got$warnings), 1L)
  expect_match(got$warnings, "precision", all = FALSE)
  expect_length(grep("No exact-dose combination exists", got$warnings), 0L)
})

test_that("whole packs whose doses the capped table cannot represent are covered pack by pack", {
  # Pack doses of 3.5 mg and 28 mg need a scale of 10; a 1,600,000 mg dose
  # caps it at 3, where 3.5 mg is 10.5 units. Whole packs are policy-exempt,
  # so instead of a refusal the dose is covered by whole packs of the one
  # product that best meets the objective: 457,143 packs of 125 microgram
  # tablets (100p) beat 57,143 packs of 1 mg tablets (900p).
  .local_fresh_dose_cache()
  got <- .with_warnings(dmd_dose_optimise(
    "finedrug",
    dose = 1.6e6,
    dose_unit = "mg",
    db = .fake_unresolvable_db(),
    preparation = "tablet",
    objective = "cheapest",
    can_split = FALSE,
    over_delivery = "minimise"
  ))
  expect_length(got$warnings, 0L)
  expect_equal(nrow(got$value), 1L)
  expect_equal(got$value$total_items, 457143)
  expect_equal(got$value$dose_cost_pence, 45714300)
  expect_equal(got$value$dose_delivered, 457143 * 3.5)
  expect_match(got$value$notes, "over-delivery-policy-not-applied", fixed = TRUE)

  # The fewest packs is the 1 mg product, which is also the dearest cover
  # (57,143 x 900p; the 950p capsules are another preparation group).
  few <- dmd_dose_optimise(
    "finedrug",
    dose = 1.6e6,
    dose_unit = "mg",
    db = .fake_unresolvable_db(),
    preparation = "tablet",
    objective = c("min_items", "most_expensive"),
    can_split = FALSE,
    quiet = TRUE
  )
  expect_equal(few$total_items[few$objective == "min_items"], 57143)
  expect_equal(few$dose_cost_pence[few$objective == "most_expensive"], 57143 * 900)
})

test_that("a dose table past the cell cap is refused as such", {
  master <- tibble::tibble(
    medicine = c("Widedrug 1microgram tablets", "Widedrug 5g tablets"),
    pack_size = c(28, 28),
    unit = c("tablet", "tablet"),
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VPP1", "VPP2"),
    drug_tariff_category = rep("Part VIIIA Category M", 2),
    basic_price = c(100L, 900L),
    nhs_indicative_price = c(100L, 900L),
    price_basis = rep("NHS Indicative Price", 2),
    price_date = rep("2025-08-08", 2),
    ampp_name = c("Widedrug 1microgram 28 tablet", "Widedrug 5g 28 tablet"),
    ampp_snomed_code = c("APP1", "APP2")
  )
  wide <- structure(
    list(master = master, loaded_at = .fixed_loaded_at),
    class = "dmd_db"
  )
  .local_fresh_dose_cache()
  got <- .with_warnings(dmd_dose_cost(
    "widedrug",
    dose = 4000,
    dose_unit = "mg",
    db = wide
  ))
  expect_equal(got$value, NA_real_)
  expect_length(grep("5,000,000 cells", got$warnings), 1L)
  expect_length(grep("No exact-dose combination exists", got$warnings), 0L)
})

