test_that("dmd_load() errors informatively on bad path", {
  expect_snapshot(error = TRUE, dmd_load("nonexistent/path"))
})

test_that("dmd_load() errors when no path supplied and option unset", {
  withr::local_options(dmdprices.path = NULL)
  expect_snapshot(error = TRUE, dmd_load())
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
      QTY_UOMCD = c("9990001", "258773002")  # uncurated code, then ml (curated)
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
      CD = c("9990001", "258773002"),
      CDDT = NA_character_, CDPREV = NA_character_,
      DESC = c("widget container", "millilitre")
    )
  )
  m <- dmdprices:::.build_master(raw)
  # Code absent from .uom_labels resolves via the UoM lookup DESC.
  expect_equal(m$unit[m$vmp_snomed_code == "V1"], "widget container")
  # A code curated in .uom_labels keeps its short canonical label ("ml"),
  # NOT the lookup's "millilitre" — preserving the dose-optimiser unit logic.
  expect_equal(m$unit[m$vmp_snomed_code == "V2"], "ml")
})

# ── print / format methods for dmd_db ─────────────────────────────────────────

test_that("format.dmd_db is a one-line summary", {
  expect_equal(
    format(.fake_dose_db()),
    "<dmd_db> [12 rows, loaded 2025-08-08]"
  )
})

test_that("print.dmd_db summarises the pricing hierarchy", {
  expect_snapshot(print(.fake_dose_db()))
})

test_that("print.dmd_db reports ingredient/combination counts when present", {
  expect_snapshot(print(.fake_ingredient_db()))
})

# ── dmd_load() happy path (fake csv/ folder) ──────────────────────────────────

# Build a 1-row-per-value tibble with all `cols`, filling unnamed columns with
# "" (which dm+d uses for empty fields and readr reads back as NA).
.dmd_file <- function(cols, ...) {
  vals <- list(...)
  n <- max(lengths(vals))
  df <- as.data.frame(
    matrix("", nrow = n, ncol = length(cols)),
    stringsAsFactors = FALSE
  )
  names(df) <- cols
  for (nm in names(vals)) df[[nm]] <- vals[[nm]]
  tibble::as_tibble(df)
}

# Write a minimal but valid dmdDataLoader `csv/` folder to a temp dir. Two
# products: a single-ingredient paracetamol tablet and a two-ingredient
# co-codamol tablet (a combination). VPI/ingredient/UoM files are optional.
local_temp_dmd_dir <- function(with_vpi = TRUE, env = parent.frame()) {
  cn <- dmdprices:::.col_names
  dir <- withr::local_tempdir(.local_envir = env)
  csv <- file.path(dir, "csv")
  dir.create(csv)
  wr <- function(file, df) {
    readr::write_delim(
      df, file.path(csv, file),
      delim = "|", col_names = FALSE, na = ""
    )
  }

  wr("f_vmp_VmpType.csv", .dmd_file(
    cn$vmp,
    VPID = c("V1", "V2"),
    NM = c("Paracetamol 500mg tablets", "Co-codamol 8mg/500mg tablets"),
    UNIT_DOSE_UOMCD = c("428673006", "428673006")
  ))
  wr("f_vmpp_VmppType.csv", .dmd_file(
    cn$vmpp,
    VPPID = c("VP1", "VP2"),
    NM = c("Paracetamol 500mg 16 tablet", "Co-codamol 8mg/500mg 32 tablet"),
    VPID = c("V1", "V2"),
    QTYVAL = c("16", "32"),
    QTY_UOMCD = c("428673006", "428673006")
  ))
  wr("f_vmpp_DtInfoType.csv", .dmd_file(
    cn$dt_info,
    VPPID = c("VP1", "VP2"), PAY_CATCD = c("M", "M"),
    PRICE = c("58", "199"), DT = c("20250801", "20250801")
  ))
  wr("f_ampp_AmppType.csv", .dmd_file(
    cn$ampp,
    APPID = c("A1", "A2"),
    NM = c(
      "Paracetamol 500mg (Brand X) 16 tablet",
      "Co-codamol 8mg/500mg (Brand Y) 32 tablet"
    ),
    VPPID = c("VP1", "VP2")
  ))
  wr("f_ampp_PriceInfoType.csv", .dmd_file(
    cn$price_info,
    APPID = c("A1", "A2"), PRICE = c("63", "205"),
    PRICEDT = c("20250808", "20250808"), PRICE_BASISCD = c("1", "1")
  ))
  wr("f_lookup_DtPayCatInfoType.csv", .dmd_file(
    cn$lkp_dt_cat, CD = "M", DESC = "Part VIIIA Category M"
  ))
  wr("f_lookup_PriceBasisInfoType.csv", .dmd_file(
    cn$lkp_pr_basis, CD = "1", DESC = "NHS Indicative Price"
  ))

  if (with_vpi) {
    wr("f_vmp_VpiType.csv", .dmd_file(
      cn$vpi,
      VPID = c("V1", "V2", "V2"),
      ISID = c("I_para", "I_cod", "I_para"),
      STRNT_NMRTR_VAL = c("500", "8", "500"),
      STRNT_NMRTR_UOMCD = c("258684004", "258684004", "258684004")
    ))
    wr("f_ingredient.csv", .dmd_file(
      cn$ingredient,
      ISID = c("I_para", "I_cod"),
      NM = c("Paracetamol", "Codeine phosphate")
    ))
    wr("f_lookup_UoMHistoryInfoType.csv", .dmd_file(
      cn$lkp_uom, CD = "258684004", DESC = "milligram"
    ))
  }

  dir
}

test_that("dmd_load() builds a <dmd_db> from a csv/ folder without VPI data", {
  db <- suppressMessages(dmd_load(local_temp_dmd_dir(with_vpi = FALSE)))
  expect_s3_class(db, "dmd_db")
  expect_named(db, c("master", "ingredients", "loaded_at"))
  expect_null(db$ingredients)
  expect_s3_class(db$master, "tbl_df")
  expect_setequal(db$master$ampp_snomed_code, c("A1", "A2"))
  expect_setequal(db$master$unit, "tablet")
  expect_equal(
    db$master$basic_price[db$master$ampp_snomed_code == "A1"],
    58L
  )
  expect_false("is_combination" %in% names(db$master))
})

test_that("dmd_load() attaches ingredients and combination flags when VPI present", {
  db <- suppressMessages(dmd_load(local_temp_dmd_dir(with_vpi = TRUE)))
  expect_s3_class(db$ingredients, "tbl_df")
  expect_setequal(db$ingredients$vmp_snomed_code, c("V1", "V2"))
  # V2 (Co-codamol) has two ingredients -> combination; V1 (paracetamol) does not.
  expect_true("is_combination" %in% names(db$master))
  expect_true(db$master$is_combination[db$master$vmp_snomed_code == "V2"])
  expect_false(db$master$is_combination[db$master$vmp_snomed_code == "V1"])
})

test_that("dmd_load() errors when a required csv file is missing", {
  path <- local_temp_dmd_dir(with_vpi = FALSE)
  file.remove(file.path(path, "csv", "f_ampp_AmppType.csv"))
  expect_error(suppressMessages(dmd_load(path)), class = "rlang_error")
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
  expect_s3_class(info$loaded_at, "POSIXct")
  expect_equal(info$release_label, NA_character_)
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
