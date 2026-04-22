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
