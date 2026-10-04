test_that("run_dmd_price_lookup() launches the bundled price-lookup app", {
  local_mocked_bindings(runApp = function(appDir, ...) appDir, .package = "shiny")
  expect_match(run_dmd_price_lookup(), "shiny/dmd_price_lookup$")
})

test_that("run_dmd_dose_optimise() launches the bundled dose-optimiser app", {
  local_mocked_bindings(runApp = function(appDir, ...) appDir, .package = "shiny")
  expect_match(run_dmd_dose_optimise(), "shiny/dmd_dose_optimise$")
})

test_that("run_inflate_nhscii() launches the bundled NHS CII app", {
  local_mocked_bindings(runApp = function(appDir, ...) appDir, .package = "shiny")
  expect_match(run_inflate_nhscii(), "shiny/inflate_nhscii$")
})

test_that(".app_dir() errors when the bundled app is missing", {
  local_mocked_bindings(.app_path = function(name) "")
  expect_snapshot(error = TRUE, .app_dir("dmd_price_lookup"))
})
