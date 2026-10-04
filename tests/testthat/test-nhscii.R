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
  expect_snapshot(error = TRUE, nhscii("2020-21", "2021/22"))
  expect_snapshot(error = TRUE, nhscii("2010/11", "2021/22"))
  expect_snapshot(error = TRUE, nhscii("2020/21", "2021/22", index = "unknown"))
  expect_snapshot(
    error = TRUE,
    inflate_nhscii(c(100, NA_real_), "2020/21", "2021/22")
  )
})

test_that("all three indices are available", {
  expect_equal(nhscii("2020/21", "2021/22", index = "pay_and_prices"), 1.0258)
  expect_equal(nhscii("2020/21", "2021/22", index = "pay"), 1.0307)
  expect_equal(nhscii("2020/21", "2021/22", index = "prices"), 1.0172)
})

test_that("2014/15 is a valid from_year", {
  # Same-year returns 1
  expect_equal(nhscii("2014/15", "2014/15"), 1)

  # One-step from 2014/15 to 2015/16 uses the 2015/16 rate
  expect_equal(
    nhscii("2014/15", "2015/16", index = "pay_and_prices"),
    1.0040,
    tolerance = 1e-12
  )
  expect_equal(
    nhscii("2014/15", "2015/16", index = "prices"),
    1.0056,
    tolerance = 1e-12
  )
  expect_equal(
    nhscii("2014/15", "2015/16", index = "pay"),
    1.0030,
    tolerance = 1e-12
  )

  # Multi-year from 2014/15 is consistent with chained calculation
  fwd_15_23 <- nhscii("2015/16", "2023/24", index = "pay_and_prices")
  fwd_14_15 <- nhscii("2014/15", "2015/16", index = "pay_and_prices")
  fwd_14_23 <- nhscii("2014/15", "2023/24", index = "pay_and_prices")
  expect_equal(fwd_14_23, fwd_14_15 * fwd_15_23, tolerance = 1e-12)
})

test_that("2024/25 is available and uses the 2025-manual rates", {
  # Latest-year one-step factors (2025 PSSRU manual, Table 12.1.1)
  expect_equal(
    nhscii("2023/24", "2024/25", index = "pay_and_prices"),
    1.0402,
    tolerance = 1e-12
  )
  expect_equal(
    nhscii("2023/24", "2024/25", index = "prices"),
    1.0204,
    tolerance = 1e-12
  )
  expect_equal(
    nhscii("2023/24", "2024/25", index = "pay"),
    1.0511,
    tolerance = 1e-12
  )

  # Numeric end-year maps to 2024/25
  expect_equal(nhscii(2024, 2025), nhscii("2023/24", "2024/25"))
})

test_that("2023/24 figures were revised by the 2025 manual", {
  # 2022/23 -> 2023/24 now uses the revised overall rate of 2.47%
  expect_equal(
    nhscii("2022/23", "2023/24", index = "pay_and_prices"),
    1.0247,
    tolerance = 1e-12
  )
  expect_equal(
    nhscii("2022/23", "2023/24", index = "prices"),
    1.0298,
    tolerance = 1e-12
  )
  expect_equal(
    nhscii("2022/23", "2023/24", index = "pay"),
    1.0218,
    tolerance = 1e-12
  )
})
