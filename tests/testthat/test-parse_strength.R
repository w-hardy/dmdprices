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
  expect_equal(res$strength_value, NA_real_)
  expect_equal(res$strength_canonical, NA_real_)
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
  expect_equal(res$is_combination, c(TRUE, TRUE))
  expect_equal(res$n_components, c(2L, 2L))
  # The mass/mass ratio must NOT be treated as a concentration
  expect_equal(res$strength_canonical, c(NA_real_, NA_real_))
  expect_equal(res$denominator_unit, c(NA_character_, NA_character_))
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

test_that("combination inhalers ('.../dose / Name .../dose') parse all ingredients", {
  res <- dmd_parse_strength(
    "Fluticasone propionate 100micrograms/dose / Salmeterol 12.75micrograms/dose dry powder inhaler"
  )
  expect_true(res$is_combination)
  expect_equal(res$n_components, 2L)
  expect_equal(res$denominator_unit, "dose")
  expect_equal(res$drug_stem, "Fluticasone propionate")
  expect_equal(res$tail, "dry powder inhaler")
  comp <- res$components[[1]]
  expect_equal(comp$value, c(100, 12.75))
  expect_equal(comp$canonical_value, c(0.1, 0.01275))
})

test_that("three-way combination inhalers parse all ingredients", {
  res <- dmd_parse_strength(
    "Generic Trimbow 172micrograms/dose / 5micrograms/dose / 9micrograms/dose pressurised inhalation"
  )
  expect_true(res$is_combination)
  expect_equal(res$n_components, 3L)
  expect_equal(res$components[[1]]$value, c(172, 5, 9))
})

test_that("single-ingredient inhalers stay concentrations, not combinations", {
  res <- dmd_parse_strength("Salbutamol 100micrograms/dose inhaler CFC free")
  expect_false(res$is_combination)
  expect_equal(res$denominator_unit, "dose")
  expect_equal(res$strength_unit_canon, "mg/dose")
})

test_that("mass-per-volume concentrations are not treated as combinations", {
  res <- dmd_parse_strength(c(
    "Morphine 10mg/5ml oral solution",
    "Heparin 100units/ml solution for injection ampoules"
  ))
  expect_equal(res$is_combination, c(FALSE, FALSE))
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

# ── Comma thousands separators (issue #22) ───────────────────────────────────

test_that("comma-formatted strengths parse identically to plain forms", {
  res <- dmd_parse_strength(c(
    "Nystatin 100,000units/ml oral suspension",
    "Nystatin 100000units/ml oral suspension"
  ))
  expect_equal(res$strength_value, c(100000, 100000))
  expect_equal(res$strength_unit, c("units", "units"))
  expect_equal(res$denominator_value, c(1, 1))
  expect_equal(res$denominator_unit, c("ml", "ml"))
  expect_equal(res$strength_canonical, c(100000, 100000))
  expect_equal(res$strength_unit_canon, c("unit/ml", "unit/ml"))
  expect_equal(res$drug_stem, c("Nystatin", "Nystatin"))
})

test_that("multi-group and decimal comma strengths parse", {
  res <- dmd_parse_strength(c(
    "Testdrug 1,234,567units powder for solution vials",
    "Testdrug 1,234.5mg tablets"
  ))
  expect_equal(res$strength_value, c(1234567, 1234.5))
  expect_equal(res$strength_unit, c("units", "mg"))
})

test_that("malformed comma groups do not parse as strengths", {
  # A comma group must be exactly three digits; "1,00" is not a strength and
  # must not be misread as 1 or 100.
  res <- dmd_parse_strength("Testdrug 1,00mg tablets")
  expect_true(is.na(res$strength_value))
  expect_true(is.na(res$strength_unit))
})

test_that("comma numbers without a unit stay unparsed", {
  # Real bundled name: the number is a product name token, not a strength.
  res <- dmd_parse_strength("Generic Pangrol 10,000 capsules")
  expect_true(is.na(res$strength_value))
  expect_true(is.na(res$denominator_unit))
})

test_that("spaced-slash combinations with comma strengths parse all components", {
  # Regression: "1,000unit" previously matched from "000unit", producing a
  # zero-strength component and drug_stem "Colecalciferol 1,".
  res <- dmd_parse_strength(
    "Colecalciferol 1,000unit / Menaquinone-7 45microgram capsules"
  )
  expect_true(res$is_combination)
  expect_equal(res$drug_stem, "Colecalciferol")
  comps <- res$components[[1]]
  expect_equal(comps$value, c(1000, 45))
  expect_equal(comps$unit, c("unit", "microgram"))
  expect_false(any(comps$value == 0))
})

test_that("bare-slash combinations with comma strengths parse all components", {
  res <- dmd_parse_strength("Testdrug 1,000mg/500mg tablets")
  expect_true(res$is_combination)
  comps <- res$components[[1]]
  expect_equal(comps$value, c(1000, 500))
  expect_equal(comps$unit, c("mg", "mg"))
})

# ── Bracketed restatements and multi-product packs (#27) ─────────────────────

test_that(".strength_token_count returns 0 for names without a strength", {
  expect_equal(
    dmdprices:::.strength_token_count(c(
      "Gauze dressing sterile",
      "Metformin 500mg tablets",
      "Co-codamol 8mg/500mg tablets",
      NA
    )),
    c(0L, 1L, 2L, 0L)
  )
  expect_identical(dmdprices:::.strength_token_count(character()), integer())
})

test_that("bracketed text after the strength stays in the tail", {
  res <- dmd_parse_strength(c(
    "Eptacog beta (activated) 1mg (45,000unit) powder and solvent for solution for injection vials",
    "Iohexol 755mg/ml (Iodine 350mg/ml) solution for injection 700ml plastic bottles"
  ))
  expect_equal(res$drug_stem, c("Eptacog beta (activated)", "Iohexol"))
  expect_equal(res$strength_value, c(1, 755))
  expect_equal(res$strength_unit_canon, c("mg", "mg/ml"))
  expect_equal(
    res$tail,
    c(
      "(45,000unit) powder and solvent for solution for injection vials",
      "(Iodine 350mg/ml) solution for injection 700ml plastic bottles"
    )
  )
})

test_that(".dose_strength_count ignores restatements in another unit dimension", {
  nm <- c(
    # mass restated as activity: one dose basis
    "Eptacog beta (activated) 1mg (45,000unit) powder and solvent for solution for injection vials",
    # same-dimension bracketed strengths: competing bases, still counted
    "Iohexol 755mg/ml (Iodine 350mg/ml) solution for injection 700ml plastic bottles",
    "Mexiletine hydrochloride 200mg (Mexiletine 167mg) capsules",
    "Factor VIII Inhibitor Bypassing Fraction human 25units/ml (500unit) powder and 20ml solvent for solution for infusion vials",
    "Testosterone 20mg/g transdermal gel (23mg per actuation) refill",
    # nested brackets; the parsed strength is itself inside a bracket
    "Magnesium glycerophosphate (magnesium 97.2mg (4mmol)) tablets",
    # no parsed strength, so nothing is a restatement
    "Ferric maltol (iron 30mg) capsules",
    # an unbalanced bracket is not a bare bracketed strength
    "Testdrug 10mg (Otherdrug 5mg tablets",
    # a different-dimension strength that names another substance is not a
    # bare restatement, so it still counts
    "Testdrug 10mg (Otherdrug 1,000unit) tablets",
    # a bare different-dimension restatement with a denominator
    "Testdrug 1,000units/ml (10mg/ml) solution for injection 5ml ampoules",
    "Gauze dressing sterile",
    NA
  )
  unit <- dmd_parse_strength(ifelse(is.na(nm), "", nm))$strength_unit
  expect_equal(
    dmdprices:::.dose_strength_count(nm, unit),
    c(1L, 2L, 2L, 2L, 2L, 1L, 1L, 2L, 2L, 1L, 0L, 0L)
  )
  expect_identical(
    dmdprices:::.dose_strength_count(character(), character()),
    integer()
  )
})

test_that(".pack_kind labels multi-strength packs and co-packs", {
  nm <- c(
    "Danicopan 50mg tablets and Danicopan 100mg tablets",
    "Mitapivat 20mg tablets and Mitapivat 5mg tablets",
    "Mirikizumab 100mg/1ml solution for injection pre-filled disposable devices and Mirikizumab 200mg/2ml solution for injection pre-filled disposable devices",
    "Memantine 5mg/10mg/15mg/20mg tablets treatment initiation pack",
    "Tixagevimab 150mg/1.5ml solution for injection vials and Cilgavimab 150mg/1.5ml solution for injection vials",
    "Generic Actonel Combi 35mg tablets and 1000mg/880unit effervescent granules sachets",
    # one chewable tablet holding two ingredients: a combination, not a pack
    "Generic LipoSil Liposomal Iron 15mg and Active folate 173.88microgram chewable tablets",
    # dm+d's "powder and solvent" idiom is not a second product
    "Eptacog beta (activated) 1mg (45,000unit) powder and solvent for solution for injection vials",
    "Factor VIII Inhibitor Bypassing Fraction human 25units/ml (500unit) powder and 20ml solvent for solution for infusion vials",
    "Galactose 2.49g / Palmitic acid 2.5mg powder and solvent for suspension for injection 2.5g vials",
    "Co-codamol 8mg/500mg tablets",
    NA
  )
  expect_equal(
    dmdprices:::.pack_kind(nm),
    c(
      rep("multi_strength_pack", 4),
      rep("co_pack", 2),
      rep(NA_character_, 6)
    )
  )
  expect_identical(dmdprices:::.pack_kind(character()), character())
})
