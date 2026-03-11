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
  app_dir <- system.file("shiny", "dmd_price_lookup", package = "dmdprices")
  if (app_dir == "") {
    stop(
      "Could not find the app directory. Try re-installing dmdprices.",
      call. = FALSE
    )
  }
  shiny::runApp(app_dir, display.mode = "normal")
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
  app_dir <- system.file("shiny", "inflate_nhscii", package = "dmdprices")
  if (app_dir == "") {
    stop(
      "Could not find the app directory. Try re-installing dmdprices.",
      call. = FALSE
    )
  }
  shiny::runApp(app_dir, display.mode = "normal")
}
