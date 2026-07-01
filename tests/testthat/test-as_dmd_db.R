# Canonical <dmd_db> $master column order.
.canon_cols <- c(
  "medicine", "pack_size", "unit", "vmp_snomed_code", "vmpp_snomed_code",
  "drug_tariff_category", "basic_price", "nhs_indicative_price",
  "price_basis", "price_date", "ampp_name", "ampp_snomed_code"
)

# A fully-populated canonical frame (no missing columns -> no warning).
.canonical_frame <- function() {
  data.frame(
    medicine = c("Metformin 500mg tablets", "Metformin 1000mg tablets"),
    pack_size = c(28, 28),
    unit = "tablet",
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VP1", "VP2"),
    drug_tariff_category = "Part VIIIA Category M",
    basic_price = c(58L, 180L),
    nhs_indicative_price = c(63L, 190L),
    price_basis = "NHS Indicative Price",
    price_date = "2025-08-08",
    ampp_name = c("Metformin 500mg 28 tab", "Metformin 1000mg 28 tab"),
    ampp_snomed_code = c("A1", "A2"),
    stringsAsFactors = FALSE
  )
}

# A COSTmos Part VIIIA-shaped frame *after* renaming to the dmdprices schema:
# pack_size is character, and ampp_*/nhs_indicative_price/price_* are absent.
.viiia_frame <- function() {
  data.frame(
    drug_tariff_category = "Part VIIIA Category M",
    medicine = c("Metformin 500mg tablets", "Metformin 1000mg tablets"),
    pack_size = c("28", "28"),
    unit = c("tablet", "tablet"),
    basic_price = c(58L, 180L),
    vmp_snomed_code = c("V1", "V2"),
    vmpp_snomed_code = c("VP1", "VP2"),
    stringsAsFactors = FALSE
  )
}

test_that("as_dmd_db() builds a valid <dmd_db> from a canonical frame", {
  db <- expect_no_warning(as_dmd_db(.canonical_frame()))
  expect_s3_class(db, "dmd_db")
  expect_named(db, c("master", "ingredients", "loaded_at"))
  expect_s3_class(db$master, "tbl_df")
  expect_null(db$ingredients)
  expect_s3_class(db$loaded_at, "POSIXct")
  expect_named(db$master, .canon_cols)
})

test_that("as_dmd_db() errors without a medicine column", {
  df <- .canonical_frame()
  df$medicine <- NULL
  expect_snapshot(error = TRUE, as_dmd_db(df))
})

test_that("as_dmd_db() errors when no usable price is present", {
  # Both price columns absent entirely.
  no_price <- .canonical_frame()
  no_price$basic_price <- NULL
  no_price$nhs_indicative_price <- NULL
  expect_snapshot(error = TRUE, as_dmd_db(no_price))

  # basic_price present but all-NA, no indicative -> same failure.
  all_na <- .canonical_frame()
  all_na$basic_price <- NA_integer_
  all_na$nhs_indicative_price <- NULL
  expect_snapshot(error = TRUE, as_dmd_db(all_na))
})

test_that("as_dmd_db() fills missing optional columns with typed NA", {
  df <- data.frame(
    medicine = "Metformin 500mg tablets",
    pack_size = 28,
    unit = "tablet",
    basic_price = 58L,
    stringsAsFactors = FALSE
  )
  db <- suppressWarnings(as_dmd_db(df))
  expect_named(db$master, .canon_cols)
  expect_type(db$master$nhs_indicative_price, "integer")
  expect_type(db$master$ampp_name, "character")
  expect_true(all(is.na(db$master$nhs_indicative_price)))
  expect_true(all(is.na(db$master$ampp_name)))
  expect_true(all(is.na(db$master$ampp_snomed_code)))
})

test_that("as_dmd_db() warns once about degraded functionality", {
  df <- data.frame(
    medicine = "Metformin 500mg tablets",
    basic_price = 58L,
    stringsAsFactors = FALSE
  )
  expect_snapshot(db <- as_dmd_db(df))
})

test_that("as_dmd_db() coerces character pack_size and flags unparseable values", {
  df <- .canonical_frame()
  df$pack_size <- c("28", "not-a-number")
  expect_snapshot(db <- as_dmd_db(df))
  expect_equal(db$master$pack_size, c(28, NA_real_))
})

test_that("as_dmd_db() preserves a zero price (no na_if(0))", {
  df <- .canonical_frame()
  df$basic_price <- c(0L, 58L)
  db <- expect_no_warning(as_dmd_db(df))
  expect_equal(db$master$basic_price, c(0L, 58L))
})

test_that("as_dmd_db() output round-trips through dmd_price_lookup()", {
  db <- suppressWarnings(as_dmd_db(.viiia_frame()))
  res <- dmd_price_lookup("metformin", db = db)
  expect_gte(nrow(res), 1L)
  expect_match(res$medicine, "Metformin", all = TRUE)
})

test_that("as_dmd_db() output round-trips through dmd_dose_optimise()", {
  withr::defer(memoise::forget(.dmd_prepare_candidates_memo))
  db <- suppressWarnings(as_dmd_db(.viiia_frame()))
  res <- dmd_dose_optimise(
    "metformin",
    dose = "1500 mg",
    db = db,
    preparation = "tablet|none|oral"
  )
  expect_s3_class(res, "tbl_df")
  expect_gte(nrow(res), 1L)
  expect_gte(min(res$dose_delivered), 1500)
})

test_that(".new_dmd_db() assembles without validation or coercion", {
  ts <- as.POSIXct("2025-08-08 09:00:00", tz = "UTC")
  db <- dmdprices:::.new_dmd_db(tibble::tibble(medicine = "x"), NULL, ts)
  expect_s3_class(db, "dmd_db")
  expect_named(db, c("master", "ingredients", "loaded_at"))
  expect_identical(db$loaded_at, ts)
})
