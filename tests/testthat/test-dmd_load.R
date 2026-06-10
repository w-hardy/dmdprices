test_that("dmd_load() errors informatively on bad path", {
  expect_error(dmd_load("nonexistent/path"), class = "rlang_error")
})

test_that("dmd_load() errors when no path supplied and option unset", {
  withr::with_options(list(dmdprices.path = NULL), {
    expect_error(dmd_load(), class = "rlang_error")
  })
})

test_that(".build_master resolves pack units via the UoM lookup fallback", {
  raw <- list(
    vmp = tibble::tibble(
      VPID = c("V1", "V2"), NM = c("Syringe drug", "Liquid drug"),
      INVALID = NA_character_, UDFS = NA_character_,
      UNIT_DOSE_UOMCD = NA_character_
    ),
    vmpp = tibble::tibble(
      VPPID = c("P1", "P2"), NM = c("Syringe pack", "Liquid pack"),
      INVALID = NA_character_, VPID = c("V1", "V2"), QTYVAL = c("1", "100"),
      QTY_UOMCD = c("3318611000001103", "258773002")  # syringe code, then ml
    ),
    dt_info = tibble::tibble(
      VPPID = character(), PAY_CATCD = character(),
      PRICE = character(), DT = character(), PREVPRICE = character()
    ),
    ampp = tibble::tibble(
      APPID = c("A1", "A2"), NM = c("Syringe AMPP", "Liquid AMPP"),
      INVALID = NA_character_, VPPID = c("P1", "P2"), DISCCD = NA_character_
    ),
    price_info = tibble::tibble(
      APPID = c("A1", "A2"), PRICE = c("1000", "1000"),
      PRICEDT = c("2026-01-01", "2026-01-01"),
      PRICE_PREV = NA_character_, PRICE_BASISCD = c("B1", "B1")
    ),
    lkp_dt_cat = tibble::tibble(CD = character(), DESC = character()),
    lkp_pr_basis = tibble::tibble(CD = "B1", DESC = "NHS Indicative Price"),
    lkp_uom = tibble::tibble(
      CD = c("3318611000001103", "258773002"),
      CDDT = NA_character_, CDPREV = NA_character_,
      DESC = c("pre-filled syringe", "millilitre")
    )
  )
  m <- dmdprices:::.build_master(raw)
  # Unmapped syringe code resolves via the UoM lookup DESC.
  expect_equal(m$unit[m$vmp_snomed_code == "V1"], "pre-filled syringe")
  # A code curated in .uom_labels keeps its short canonical label ("ml"),
  # NOT the lookup's "millilitre" — preserving the dose-optimiser unit logic.
  expect_equal(m$unit[m$vmp_snomed_code == "V2"], "ml")
})

# ── dmd_master_info ───────────────────────────────────────────────────────────

test_that("dmd_master_info() returns a dmd_db_info list with expected names", {
  info <- dmd_master_info(.fake_dose_db())
  expect_s3_class(info, "dmd_db_info")
  expect_named(
    info,
    c("release_label", "loaded_at", "n_ampps", "n_vmpps", "n_vmps", "price_date_range")
  )
})

test_that("dmd_master_info() with dmd_db: loaded_at is POSIXct, release_label is NA", {
  db  <- .fake_dose_db()
  info <- dmd_master_info(db)
  expect_true(inherits(info$loaded_at, "POSIXct"))
  expect_true(is.na(info$release_label))
})

test_that("dmd_master_info() with dmd_db: counts match fake fixture", {
  db   <- .fake_dose_db()
  info <- dmd_master_info(db)
  # .fake_dose_db() has 12 distinct AMPPs and 12 distinct VMPPs / VMPs
  expect_equal(info$n_ampps, 12L)
  expect_equal(info$n_vmpps, 12L)
  expect_equal(info$n_vmps,  12L)
})

test_that("dmd_master_info() price_date_range is a length-2 character vector", {
  db   <- .fake_dose_db()
  info <- dmd_master_info(db)
  expect_type(info$price_date_range, "character")
  expect_length(info$price_date_range, 2L)
  # All price_dates in the fixture are "2025-08-08", so min == max
  expect_equal(info$price_date_range[[1]], info$price_date_range[[2]])
})

test_that("print.dmd_db_info() runs without error", {
  info <- dmd_master_info(.fake_dose_db())
  expect_no_error(print(info))
})
