test_that("dmd_parse_strength parses common tablet strengths", {
  res <- dmd_parse_strength(c(
    "Metformin 500mg tablets",
    "Metformin 1000mg tablets",
    "Atenolol 100mg tablets"
  ))
  expect_equal(res$strength_value, c(500, 1000, 100))
  expect_equal(res$strength_unit, c("mg", "mg", "mg"))
  expect_equal(res$strength_canonical, c(500, 1000, 100))
  expect_equal(res$strength_unit_canon, c("mg", "mg", "mg"))
  expect_equal(res$drug_stem, c("Metformin", "Metformin", "Atenolol"))
  expect_equal(res$tail, c("tablets", "tablets", "tablets"))
})

test_that("microgram/mcg convert to mg canonical", {
  res <- dmd_parse_strength(c(
    "Levothyroxine 25microgram tablets",
    "Levothyroxine 125 micrograms tablets",
    "Digoxin 62.5mcg tablets"
  ))
  expect_equal(res$strength_canonical, c(0.025, 0.125, 0.0625))
  expect_equal(res$strength_unit_canon, rep("mg", 3))
})

test_that("g converts to mg canonical", {
  res <- dmd_parse_strength("Paracetamol 1g tablets")
  expect_equal(res$strength_canonical, 1000)
  expect_equal(res$strength_unit_canon, "mg")
})

test_that("concentration (mg/ml) parses as mass-per-volume", {
  res <- dmd_parse_strength(c(
    "Morphine 10mg/5ml oral solution",
    "Morphine 2.5mg/5ml oral solution"
  ))
  expect_equal(res$strength_value, c(10, 2.5))
  expect_equal(res$denominator_value, c(5, 5))
  expect_equal(res$denominator_unit, c("ml", "ml"))
  expect_equal(res$strength_canonical, c(2, 0.5))
  expect_equal(res$strength_unit_canon, c("mg/ml", "mg/ml"))
})

test_that("units/ml and implicit denominator parse", {
  res <- dmd_parse_strength("Heparin 100units/ml solution for injection ampoules")
  expect_equal(res$strength_value, 100)
  expect_equal(res$denominator_value, 1)
  expect_equal(res$denominator_unit, "ml")
  expect_equal(res$strength_unit_canon, "unit/ml")
})

test_that("per-dose concentration parses (inhaler)", {
  res <- dmd_parse_strength("Salbutamol 100micrograms/dose inhaler CFC free")
  expect_equal(res$strength_value, 100)
  expect_equal(res$denominator_unit, "dose")
  expect_equal(res$strength_unit_canon, "mg/dose")
})

test_that("unparseable names return NAs", {
  res <- dmd_parse_strength("Gauze dressing sterile")
  expect_true(is.na(res$strength_value))
  expect_true(is.na(res$strength_canonical))
  expect_false(res$is_combination)
  expect_equal(res$n_components, 0L)
})

test_that("single-strength products expose one ingredient component", {
  res <- dmd_parse_strength("Metformin 500mg tablets")
  expect_false(res$is_combination)
  expect_equal(res$n_components, 1L)
  comp <- res$components[[1]]
  expect_equal(comp$value, 500)
  expect_equal(comp$canonical_value, 500)
  expect_equal(comp$canonical_unit, "mg")
})

test_that("two-ingredient combinations parse into components, not a ratio", {
  res <- dmd_parse_strength(c(
    "Co-codamol 8mg/500mg tablets",
    "Co-amilofruse 5mg/40mg tablets"
  ))
  expect_true(all(res$is_combination))
  expect_equal(res$n_components, c(2L, 2L))
  # The mass/mass ratio must NOT be treated as a concentration
  expect_true(all(is.na(res$strength_canonical)))
  expect_true(all(is.na(res$denominator_unit)))
  expect_equal(res$drug_stem, c("Co-codamol", "Co-amilofruse"))

  cocodamol <- res$components[[1]]
  expect_equal(cocodamol$value, c(8, 500))
  expect_equal(cocodamol$canonical_value, c(8, 500))
  expect_equal(cocodamol$canonical_unit, c("mg", "mg"))
  expect_equal(res$tail[[1]], "tablets")
})

test_that("three-ingredient combinations parse all components", {
  res <- dmd_parse_strength("Generic Alyftrek 50mg/20mg/4mg tablets")
  expect_true(res$is_combination)
  expect_equal(res$n_components, 3L)
  expect_equal(res$components[[1]]$value, c(50, 20, 4))
})

test_that("combination liquids capture the shared volume denominator", {
  res <- dmd_parse_strength("Co-trimoxazole 80mg/400mg/5ml oral suspension")
  expect_true(res$is_combination)
  expect_equal(res$n_components, 2L)
  expect_equal(res$denominator_value, 5)
  expect_equal(res$denominator_unit, "ml")
  expect_equal(res$components[[1]]$value, c(80, 400))
  expect_equal(res$tail, "oral suspension")
})

test_that("mass-per-volume concentrations are not treated as combinations", {
  res <- dmd_parse_strength(c(
    "Morphine 10mg/5ml oral solution",
    "Heparin 100units/ml solution for injection ampoules"
  ))
  expect_false(any(res$is_combination))
  expect_equal(res$strength_canonical, c(2, 100))
  expect_equal(res$strength_unit_canon, c("mg/ml", "unit/ml"))
})

test_that(".classify_preparation distinguishes IR vs MR tablets", {
  res <- dmdprices:::.classify_preparation(c(
    "tablets",
    "modified-release tablets",
    "oral solution",
    "solution for injection ampoules"
  ))
  expect_equal(res$form, c("tablet", "modified-release tablet",
                           "oral solution", "solution for injection"))
  expect_equal(res$modifier, c("none", "modified-release", "none", "none"))
  expect_equal(res$route, c("oral", "oral", "oral", "injection"))
})
