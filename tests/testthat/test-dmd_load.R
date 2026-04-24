test_that("dmd_load() errors informatively on bad path", {
  expect_error(dmd_load("nonexistent/path"), class = "rlang_error")
})

test_that("dmd_load() errors when no path supplied and option unset", {
  withr::with_options(list(dmdprices.path = NULL), {
    expect_error(dmd_load(), class = "rlang_error")
  })
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
