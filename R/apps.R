#' Launch the dm+d price lookup Shiny app
#'
#' Opens an interactive browser-based interface for querying medicine prices
#' from the bundled `dmd_master` dataset using [dmd_price_lookup()].
#'
#' @return Starts the Shiny app (does not return a value).
#'
#' @examples
#' if (interactive()) {
#'   run_dmd_price_lookup()
#' }
#'
#' @export
run_dmd_price_lookup <- function() {
  shiny::runApp(.app_dir("dmd_price_lookup"), display.mode = "normal")
}

#' Launch the dm+d dose optimiser Shiny app
#'
#' Opens an interactive browser-based interface for finding the cheapest or
#' minimum-item pack combination that delivers a specified dose, using
#' [dmd_dose_optimise()].
#'
#' @return Starts the Shiny app (does not return a value).
#'
#' @examples
#' if (interactive()) {
#'   run_dmd_dose_optimise()
#' }
#'
#' @export
run_dmd_dose_optimise <- function() {
  shiny::runApp(.app_dir("dmd_dose_optimise"), display.mode = "normal")
}

#' Launch the NHS CII cost adjuster Shiny app
#'
#' Opens an interactive browser-based interface for inflating or deflating
#' costs between financial years using [inflate_nhscii()] and [nhscii()].
#'
#' @return Starts the Shiny app (does not return a value).
#'
#' @examples
#' if (interactive()) {
#'   run_inflate_nhscii()
#' }
#'
#' @export
run_inflate_nhscii <- function() {
  shiny::runApp(.app_dir("inflate_nhscii"), display.mode = "normal")
}

# Locate a bundled Shiny app directory. Thin wrapper over system.file() so the
# missing-app branch of .app_dir() can be exercised in tests via
# local_mocked_bindings() (base functions like system.file() cannot be mocked).
.app_path <- function(name) {
  system.file("shiny", name, package = "dmdprices")
}

# Resolve a bundled Shiny app directory, erroring clearly if it is missing
# (e.g. a broken install).
.app_dir <- function(name) {
  dir <- .app_path(name)
  if (dir == "") {
    cli::cli_abort(
      "Could not find the {.val {name}} app directory. Try re-installing {.pkg dmdprices}."
    )
  }
  dir
}
