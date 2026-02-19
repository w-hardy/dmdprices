# Minimal fake dmd_db for testing dmd_price_lookup() without real CSVs

.fake_db <- function() {
  master <- tibble::tibble(
    medicine = c(
      "Metformin 500mg tablets",
      "Metformin 500mg tablets",
      "Atenolol 100mg tablets"
    ),
    pack_size = c(28, 28, 28),
    unit = c("tablet", "tablet", "tablet"),
    vmp_snomed_code = c("A", "A", "B"),
    vmpp_snomed_code = c("AA", "AA", "BB"),
    drug_tariff_category = c(
      "Part VIIIA Category M",
      "Part VIIIA Category M",
      "Part VIIIA Category C"
    ),
    basic_price = c(58L, 58L, 90L),
    nhs_indicative_price = c(63L, 70L, NA_integer_),
    price_basis = c("NHS Indicative Price", "NHS Indicative Price", NA),
    price_date = c("2025-08-08", "2025-08-08", NA),
    ampp_name = c(
      "Metformin 500mg (Brand A) 28 tablet",
      "Metformin 500mg (Brand B) 28 tablet",
      "Atenolol 100mg (Brand A) 28 tablet"
    ),
    ampp_snomed_code = c("AAA", "AAB", "BBA")
  )
  structure(list(master = master, loaded_at = Sys.time()), class = "dmd_db")
}

db <- .fake_db()

test_that("partial match returns correct rows", {
  res <- dmd_price_lookup("metformin", db = db)
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 2)
  expect_true(all(grepl("metformin", res$medicine, ignore.case = TRUE)))
})

test_that("exact match is case-insensitive", {
  res <- dmd_price_lookup("metformin 500mg tablets", db = db, method = "exact")
  expect_equal(nrow(res), 2)
})

test_that("exact match returns nothing for non-matching query", {
  expect_warning(
    res <- dmd_price_lookup("aspirin 75mg tablets", db = db, method = "exact"),
    regexp = "No medicines found"
  )
  expect_equal(nrow(res), 0)
})

test_that("fuzzy match tolerates a single typo", {
  res <- suppressWarnings(
    dmd_price_lookup(
      "Metformin 500mg tabltes",
      db = db,
      method = "fuzzy",
      max_dist = 2
    )
  )
  expect_true(nrow(res) >= 1)
})

test_that("active_only = FALSE keeps NA-price rows", {
  res_active <- dmd_price_lookup("atenolol", db = db)
  res_all <- dmd_price_lookup("atenolol", db = db, active_only = FALSE)
  # Atenolol row has Basic Price, so active_only shouldn't drop it here
  expect_equal(nrow(res_active), nrow(res_all))
})

test_that("output has correct snake_case column names", {
  res <- dmd_price_lookup("metformin", db = db)
  expected_cols <- c(
    "medicine",
    "pack_size",
    "unit",
    "vmp_snomed_code",
    "vmpp_snomed_code",
    "drug_tariff_category",
    "basic_price",
    "nhs_indicative_price",
    "price_basis",
    "price_date",
    "ampp_name",
    "ampp_snomed_code"
  )
  expect_named(res, expected_cols)
})

test_that("dmd_price_lookup() errors on non-dmd_db / non-tibble input", {
  expect_error(dmd_price_lookup("metformin", db = "bad"), class = "rlang_error")
})

test_that("dmd_price_lookup() errors on empty query", {
  expect_error(dmd_price_lookup("  ", db = db), class = "rlang_error")
})
