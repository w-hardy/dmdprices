# Canonical <dmd_db> $master columns, in order, each mapped to its typed NA fill
# value. `medicine` is required from the caller; the rest are filled if omitted.
.dmd_master_schema <- list(
  medicine = NA_character_,
  pack_size = NA_real_,
  unit = NA_character_,
  vmp_snomed_code = NA_character_,
  vmpp_snomed_code = NA_character_,
  drug_tariff_category = NA_character_,
  basic_price = NA_integer_,
  nhs_indicative_price = NA_integer_,
  price_basis = NA_character_,
  price_date = NA_character_,
  ampp_name = NA_character_,
  ampp_snomed_code = NA_character_
)

# Low-level <dmd_db> assembler: the single place that stamps the class. No
# validation or coercion — callers that already hold a canonical `master`
# (e.g. dmd_load()) use this directly; as_dmd_db() validates first.
#' @noRd
.new_dmd_db <- function(master, ingredients = NULL, loaded_at = Sys.time()) {
  structure(
    list(master = master, ingredients = ingredients, loaded_at = loaded_at),
    class = "dmd_db"
  )
}

#' Build a dm+d database from an in-memory table
#'
#' @description
#' Turn a data frame of medicine prices into a `<dmd_db>` object that the
#' `dmdprices` functions ([dmd_price_lookup()], [dmd_dose_optimise()],
#' [dmd_dose_cost()], [dmd_master_info()]) accept via their `db` argument.
#'
#' This is the supported entry point for **external** Drug-Tariff-shaped data
#' (for example the `drug_tariff_viii_a` table from the NICE `COSTmos` package).
#' Rename your columns to the `dmdprices` schema first — the same columns the
#' bundled [dmd_master] carries and that [dmd_load()] produces — then pass the
#' frame here. Missing optional columns are filled with `NA` and column types are
#' coerced; a message reports any resulting loss of functionality.
#'
#' @details
#' The required column is `medicine`, plus at least one price column
#' (`basic_price` or `nhs_indicative_price`, both in **pence**). All other
#' canonical columns — `pack_size`, `unit`, `vmp_snomed_code`,
#' `vmpp_snomed_code`, `drug_tariff_category`, `price_basis`, `price_date`,
#' `ampp_name`, `ampp_snomed_code` — are filled with `NA` when absent. See
#' [dmd_master] for the full column contract.
#'
#' Features degrade predictably when columns are missing: without `ampp_name`,
#' brand-name search is disabled ([dmd_price_lookup()] matches the generic name
#' only); without `ampp_snomed_code`, pack identifiers are `NA` and
#' [dmd_master_info()] reports 0 AMPPs; without `pack_size`/`unit`, dose
#' optimisation is unavailable or degraded.
#'
#' Unlike [dmd_load()], prices are trusted as given — a `0` price stays `0`
#' (it is not treated as missing). Leave `loaded_at` at its default: the dose
#' optimiser's session cache keys on it, so a fixed value shared across two
#' different tables could return a stale cached result.
#'
#' @param master A data frame with, at minimum, a `medicine` column and one of
#'   `basic_price` / `nhs_indicative_price` (in pence). Columns already matching
#'   the `dmdprices` schema are used as-is; missing canonical columns are filled.
#' @param ingredients Optional. `NULL` (default), or a data frame of
#'   per-ingredient strengths in the [dmd_ingredients] shape, enabling
#'   ingredient-targeted dose optimisation.
#' @param loaded_at A length-1 `POSIXct` timestamp recording when the data was
#'   assembled. Defaults to [Sys.time()].
#'
#' @return A `<dmd_db>` object: a list with `$master` (a [tibble][tibble::tibble]
#'   in the canonical schema), `$ingredients` (the supplied table or `NULL`), and
#'   `$loaded_at` (the timestamp).
#'
#' @seealso [dmd_load()] to read a full dm+d release from disk;
#'   [dmd_price_lookup()], [dmd_dose_optimise()].
#'
#' @export
#'
#' @examples
#' # A minimal Drug-Tariff-shaped table (prices in pence).
#' df <- data.frame(
#'   medicine = c("Metformin 500mg tablets", "Metformin 1000mg tablets"),
#'   pack_size = c(28, 28),
#'   unit = "tablet",
#'   basic_price = c(58L, 180L),
#'   nhs_indicative_price = c(63L, 190L)
#' )
#' # ampp_name / ampp_snomed_code are absent, so as_dmd_db() warns that
#' # brand search and pack identifiers are unavailable.
#' db <- as_dmd_db(df)
#' dmd_price_lookup("metformin", db = db)
#'
#' \dontrun{
#' # Interoperate with NICE COSTmos Drug Tariff Part VIIIA data.
#' # COSTmos is not on CRAN; install it separately.
#' library(dplyr)
#' db <- COSTmos::drug_tariff_viii_a |>
#'   rename(unit = unit_of_measure, basic_price = basic_price_in_p) |>
#'   as_dmd_db()
#' dmd_dose_optimise("metformin", dose = "1500 mg", db = db)
#' }
as_dmd_db <- function(master, ingredients = NULL, loaded_at = Sys.time()) {
  if (!is.data.frame(master)) {
    cli::cli_abort(c(
      "{.arg master} must be a data frame.",
      "i" = "Rename your columns to the {.pkg dmdprices} schema first; see {.fn as_dmd_db}."
    ))
  }
  if (!"medicine" %in% names(master)) {
    cli::cli_abort(c(
      "{.arg master} must have a {.field medicine} column.",
      "i" = "Every {.cls dmd_db} is searched by medicine name."
    ))
  }
  if (nrow(master) == 0L) {
    cli::cli_abort("{.arg master} has no rows.")
  }
  if (!inherits(loaded_at, "POSIXct") || length(loaded_at) != 1L) {
    cli::cli_abort("{.arg loaded_at} must be a single {.cls POSIXct} timestamp.")
  }
  if (!is.null(ingredients) && !is.data.frame(ingredients)) {
    cli::cli_abort("{.arg ingredients} must be {.code NULL} or a data frame.")
  }

  master <- tibble::as_tibble(master)

  # Fill missing canonical columns with typed NA.
  missing_cols <- setdiff(names(.dmd_master_schema), names(master))
  for (col in missing_cols) {
    master[[col]] <- .dmd_master_schema[[col]]
  }

  # Coerce types (present + filled). Count pack_size values lost to coercion.
  n_pack_before <- sum(!is.na(master$pack_size))
  master$pack_size <- suppressWarnings(as.numeric(master$pack_size))
  n_pack_lost <- n_pack_before - sum(!is.na(master$pack_size))

  master$basic_price <- suppressWarnings(as.integer(master$basic_price))
  master$nhs_indicative_price <-
    suppressWarnings(as.integer(master$nhs_indicative_price))
  chr_cols <- c(
    "medicine", "unit", "vmp_snomed_code", "vmpp_snomed_code",
    "drug_tariff_category", "price_basis", "price_date",
    "ampp_name", "ampp_snomed_code"
  )
  for (col in chr_cols) {
    master[[col]] <- as.character(master[[col]])
  }
  if ("is_combination" %in% names(master)) {
    master$is_combination <- as.logical(master$is_combination)
  }

  # With both prices entirely NA every row is dropped under active_only = TRUE,
  # so the object is silently useless — fail loudly instead.
  if (all(is.na(master$basic_price)) && all(is.na(master$nhs_indicative_price))) {
    cli::cli_abort(c(
      "{.arg master} has no usable prices.",
      "x" = "Both {.field basic_price} and {.field nhs_indicative_price} are entirely missing.",
      "i" = "Supply at least one price column, in {.strong pence}."
    ))
  }

  # Canonical columns first, then any extras (e.g. is_combination) preserved.
  canon <- names(.dmd_master_schema)
  master <- master[, c(canon, setdiff(names(master), canon)), drop = FALSE]

  # One consolidated warning about reduced functionality.
  notes <- character()
  if ("ampp_name" %in% missing_cols) {
    notes <- c(notes, "*" = "No {.field ampp_name}: brand-name search is disabled ({.fn dmd_price_lookup} matches the generic name only).")
  }
  if ("ampp_snomed_code" %in% missing_cols) {
    notes <- c(notes, "*" = "No {.field ampp_snomed_code}: pack identifiers are {.code NA} ({.fn dmd_master_info} reports 0 AMPPs).")
  }
  degraded_dose <- intersect(c("pack_size", "unit"), missing_cols)
  if (length(degraded_dose) > 0L) {
    notes <- c(notes, "*" = "Missing {.field {degraded_dose}} column{?s}: dose optimisation is unavailable or degraded.")
  }
  if (n_pack_lost > 0L) {
    notes <- c(notes, "*" = "{n_pack_lost} {.field pack_size} value{?s} could not be coerced to numeric and became {.code NA}.")
  }
  if (length(notes) > 0L) {
    cli::cli_warn(c(
      "Built a {.cls dmd_db} with reduced functionality:",
      notes
    ))
  }

  .new_dmd_db(master, ingredients = ingredients, loaded_at = loaded_at)
}
