#' Look up medicine prices from a dm+d database
#'
#' Searches a dm+d pricing table for medicines whose names match `query`.
#' Returns a tibble in the same column format as the NHS Drug Tariff Part VIIIA
#' CSV, with Drug Tariff and NHS Indicative Price columns appended.
#'
#' By default, the bundled [dmd_master] dataset (Week 34 2025, 14 August 2025)
#' is used, so no setup is needed. Supply `db` to use a more recent release
#' loaded with [dmd_load()].
#'
#' @param query  A character string to search for in medicine names.
#' @param db     A `<dmd_db>` object from [dmd_load()], or a tibble with the
#'   same columns as [dmd_master]. Defaults to the bundled [dmd_master] dataset.
#' @param method One of:
#'   * `"partial"` *(default)* — case-insensitive substring match using a
#'     regular expression. Suitable for general searching, e.g. `"metformin"`.
#'   * `"exact"` — case-insensitive exact match against the full VMP name.
#'   * `"fuzzy"` — approximate string matching (optimal string alignment
#'     distance via [stringdist::stringdist()]). Tolerates typos. Tune
#'     sensitivity with `max_dist`.
#' @param max_dist Maximum edit distance for `method = "fuzzy"` (default `3`).
#'   Increase for looser matching; decrease for stricter matching.
#' @param active_only If `TRUE` (default), rows where both `Basic Price` and
#'   `NHS Indicative Price` are `NA` are dropped.
#'
#' @return A [tibble][tibble::tibble] with the following columns, in the same
#'   order and format as the NHS Drug Tariff Part VIIIA CSV:
#'
#'   | Column | Description |
#'   |---|---|
#'   | `Medicine` | VMP (generic) name |
#'   | `Pack size` | Pack quantity |
#'   | `Unit` | Unit of measure (tablet, ml, etc.) |
#'   | `VMP Snomed Code` | VMP SNOMED CT identifier |
#'   | `VMPP Snomed Code` | VMPP SNOMED CT identifier |
#'   | `Drug Tariff Category` | e.g. "Part VIIIA Category M" |
#'   | `Basic Price` | Drug Tariff basic price (pence) |
#'   | `NHS Indicative Price` | NHS Indicative Price (pence) |
#'   | `Price Basis` | Basis of NHS Indicative Price |
#'   | `Price Date` | Date of NHS Indicative Price |
#'   | `AMPP Name` | Branded pack name |
#'   | `AMPP Snomed Code` | AMPP SNOMED CT identifier |
#'
#' @export
#'
#' @examples
#' # Uses bundled data — no setup required
#' dmd_price_lookup("metformin")
#'
#' dmd_price_lookup("Metformin 500mg tablets", method = "exact")
#'
#' dmd_price_lookup("metfromin 500mg tablets", method = "fuzzy", max_dist = 4)
#'
#' # Include rows without any price
#' dmd_price_lookup("metformin", active_only = FALSE)
#'
#' \dontrun{
#' # Use a locally loaded, more recent release
#' db <- dmd_load("~/dmdDataLoader")
#' dmd_price_lookup("metformin", db = db)
#' }
dmd_price_lookup <- function(
  query,
  db = dmdprices::dmd_master,
  method = c("partial", "exact", "fuzzy"),
  max_dist = 3,
  active_only = TRUE
) {
  if (!rlang::is_string(query) || nchar(stringr::str_squish(query)) == 0) {
    cli::cli_abort("{.arg query} must be a non-empty character string.")
  }

  # Accept either a dmd_db object (from dmd_load()) or a plain tibble
  # (e.g. the bundled dmd_master)
  master <- if (inherits(db, "dmd_db")) db$master else db

  if (!is.data.frame(master) || !"Medicine" %in% names(master)) {
    cli::cli_abort(c(
      "{.arg db} must be a {.cls dmd_db} object or a tibble with a {.col Medicine} column.",
      "i" = "Use the bundled {.code dmd_master} dataset or create a {.cls dmd_db} with {.code dmd_load()}."
    ))
  }

  method <- match.arg(method)
  q <- stringr::str_squish(query)

  results <- switch(
    method,
    exact = dplyr::filter(
      master,
      stringr::str_to_upper(.data$Medicine) == stringr::str_to_upper(q)
    ),

    partial = dplyr::filter(
      master,
      stringr::str_detect(.data$Medicine, stringr::regex(q, ignore_case = TRUE))
    ),

    fuzzy = {
      dists <- stringdist::stringdist(
        stringr::str_to_lower(q),
        stringr::str_to_lower(master$Medicine),
        method = "osa"
      )
      master[dists <= max_dist, ]
    }
  )

  if (active_only) {
    results <- dplyr::filter(
      results,
      !is.na(.data$`Basic Price`) | !is.na(.data$`NHS Indicative Price`)
    )
  }

  if (nrow(results) == 0) {
    cli::cli_warn(
      "No medicines found matching {.val {q}} with method = {.val {method}}."
    )
  }

  dplyr::arrange(results, .data$Medicine, .data$`Pack size`)
}
