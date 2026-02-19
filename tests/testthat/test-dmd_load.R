test_that("dmd_load() errors informatively on bad path", {
  expect_error(dmd_load("nonexistent/path"), class = "rlang_error")
})

test_that("dmd_load() errors when no path supplied and option unset", {
  withr::with_options(list(dmdprices.path = NULL), {
    expect_error(dmd_load(), class = "rlang_error")
  })
})
