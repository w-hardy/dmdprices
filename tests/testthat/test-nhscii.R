test_that("same-year factor is 1", {
  out <- nhscii("2020/21", "2020/21")
  expect_equal(out, 1)
})

test_that("numeric years map to end-year financial years", {
  a <- nhscii(2020, 2024)
  b <- nhscii("2019/20", "2023/24")
  expect_equal(a, b)
})

test_that("adjacent year uses target-year rate", {
  # 2019/20 -> 2020/21 uses 2020/21 pay_and_prices = 2.49%
  out <- nhscii("2019/20", "2020/21", index = "pay_and_prices")
  expect_equal(out, 1.0249, tolerance = 1e-12)
})

test_that("reverse factor is reciprocal", {
  fwd <- nhscii("2019/20", "2022/23", index = "prices")
  rev <- nhscii("2022/23", "2019/20", index = "prices")
  expect_equal(fwd * rev, 1, tolerance = 1e-12)
})

test_that("percent output_type is derived from factor", {
  fac <- nhscii("2018/19", "2021/22", output_type = "factor")
  pct <- nhscii("2018/19", "2021/22", output_type = "percent")
  expect_equal(pct, (fac - 1) * 100, tolerance = 1e-12)
})

test_that("inflate_nhscii multiplies by nhscii factor", {
  cost <- c(100, 250)
  fac <- nhscii("2021/22", "2023/24", index = "pay")
  out <- inflate_nhscii(cost, "2021/22", "2023/24", index = "pay")
  expect_equal(out, cost * fac)
})

test_that("input validation fails gracefully", {
  expect_error(
    nhscii("2020-21", "2021/22"),
    "must be in 'YYYY/YY' format or a numeric end-year"
  )

  expect_error(
    nhscii("2010/11", "2021/22"),
    "from_year must be one of"
  )

  expect_error(
    nhscii("2020/21", "2021/22", index = "unknown"),
    "should be one of"
  )

  expect_error(
    inflate_nhscii(c(100, NA_real_), "2020/21", "2021/22"),
    "cost must be a numeric vector of finite values"
  )
})

test_that("all three indices are available", {
  expect_equal(nhscii("2020/21", "2021/22", index = "pay_and_prices"), 1.0258)
  expect_equal(nhscii("2020/21", "2021/22", index = "pay"), 1.0307)
  expect_equal(nhscii("2020/21", "2021/22", index = "prices"), 1.0172)
})
