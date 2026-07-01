#' Load a dm+d database from a dmdDataLoader output directory
#'
#' Reads the pipe-delimited CSV files produced by the NHSBSA dm+d extract tool
#' from the `csv/` subdirectory of `path` and builds a single joined pricing
#' table. The returned object can be passed directly to [dmd_price_lookup()].
#'
#' @param path Path to the `dmdDataLoader` folder (the parent of `csv/`).
#'   Defaults to `getOption("dmdprices.path")`, allowing you to set a
#'   project-wide default via `options(dmdprices.path = "~/dmdDataLoader")`.
#'
#' @return A `<dmd_db>` object: a list with the elements:
#'   * `$master`  — a [tibble][tibble::tibble] with one row per AMPP (branded
#'     pack), containing Drug Tariff and NHS Indicative Price columns that mirror
#'     the Drug Tariff Part VIIIA CSV format. When ingredient data is available
#'     it also carries an `is_combination` logical column.
#'   * `$ingredients` — a [tibble][tibble::tibble] of per-ingredient strengths
#'     (one row per VMP/ingredient) built from the dm+d Virtual Product
#'     Ingredient (VPI) extract, or `NULL` if that extract was not present.
#'     Columns: `vmp_snomed_code`, `ingredient_snomed_code`, `ingredient_name`,
#'     `strength_value`, `strength_unit`, `denominator_value`,
#'     `denominator_unit`, `strength_canonical`, `strength_unit_canon`.
#'   * `$loaded_at` — a `POSIXct` timestamp recording when the data was loaded.
#'
#' @seealso [as_dmd_db()] to build a `<dmd_db>` from an in-memory table (e.g.
#'   external Drug-Tariff data); [dmd_price_lookup()], [dmd_dose_optimise()].
#'
#' @export
#'
#' @examples
#' \dontrun{
#' db <- dmd_load("~/dmdDataLoader")
#' db
#' }
dmd_load <- function(path = getOption("dmdprices.path")) {
  if (is.null(path)) {
    cli::cli_abort(c(
      "No path supplied.",
      "i" = "Provide {.arg path} or set {.code options(dmdprices.path = \\\"...\\\")}"
    ))
  }

  path <- normalizePath(path, mustWork = FALSE)
  csv_dir <- file.path(path, "csv")

  if (!dir.exists(csv_dir)) {
    cli::cli_abort(c(
      "{.path {csv_dir}} does not exist.",
      "i" = "{.arg path} should be the {.code dmdDataLoader} folder that contains a {.code csv/} subdirectory."
    ))
  }

  cli::cli_progress_step("Reading dm+d CSV files from {.path {csv_dir}}")

  raw <- list(
    vmp = .read_dmd(csv_dir, "f_vmp_VmpType.csv", .col_names$vmp),
    vmpp = .read_dmd(csv_dir, "f_vmpp_VmppType.csv", .col_names$vmpp),
    dt_info = .read_dmd(csv_dir, "f_vmpp_DtInfoType.csv", .col_names$dt_info),
    ampp = .read_dmd(csv_dir, "f_ampp_AmppType.csv", .col_names$ampp),
    price_info = .read_dmd(
      csv_dir,
      "f_ampp_PriceInfoType.csv",
      .col_names$price_info
    ),
    lkp_dt_cat = .read_dmd(
      csv_dir,
      "f_lookup_DtPayCatInfoType.csv",
      .col_names$lkp_dt_cat
    ),
    lkp_pr_basis = .read_dmd(
      csv_dir,
      "f_lookup_PriceBasisInfoType.csv",
      .col_names$lkp_pr_basis
    ),
    # Optional ingredient (VPI) extract — present in full dm+d releases, absent
    # in some minimal exports. Enables combination-product handling.
    vpi = .read_dmd_optional(
      csv_dir,
      "f_vmp_VpiType.csv",
      .col_names$vpi
    ),
    ingredient = .read_dmd_optional(
      csv_dir,
      "f_ingredient.csv",
      .col_names$ingredient
    ),
    lkp_uom = .read_dmd_optional(
      csv_dir,
      "f_lookup_UoMHistoryInfoType.csv",
      .col_names$lkp_uom
    )
  )

  cli::cli_progress_step("Joining pricing hierarchy")

  master <- .build_master(raw)
  ingredients <- .build_ingredients(raw)

  if (!is.null(ingredients)) {
    flags <- .combination_flags(ingredients)
    master <- master |>
      dplyr::left_join(flags, by = dplyr::join_by("vmp_snomed_code")) |>
      dplyr::mutate(
        is_combination = !is.na(.data$is_combination) & .data$is_combination
      )
    n_comb <- dplyr::n_distinct(
      ingredients$vmp_snomed_code[
        ingredients$vmp_snomed_code %in%
          flags$vmp_snomed_code[flags$is_combination]
      ]
    )
    cli::cli_progress_step(
      "Loaded ingredient data ({n_comb} combination VMP{?s})"
    )
  }

  .new_dmd_db(master, ingredients = ingredients, loaded_at = Sys.time())
}

# ── S3 methods for dmd_db ─────────────────────────────────────────────────────

#' @export
print.dmd_db <- function(x, ...) {
  n_vmp <- dplyr::n_distinct(x$master$vmp_snomed_code, na.rm = TRUE)
  n_vmpp <- dplyr::n_distinct(x$master$vmpp_snomed_code, na.rm = TRUE)
  n_ampp <- dplyr::n_distinct(x$master$ampp_snomed_code, na.rm = TRUE)
  n_dt <- sum(!is.na(x$master$basic_price))
  n_ip <- sum(!is.na(x$master$nhs_indicative_price))

  msg <- c(
    "v" = "dm+d database loaded at {format(x$loaded_at, '%Y-%m-%d %H:%M')}",
    "*" = "{n_vmp} VMPs  |  {n_vmpp} VMPPs  |  {n_ampp} AMPPs",
    "*" = "{n_dt} Drug Tariff prices  |  {n_ip} NHS Indicative Prices"
  )

  if (!is.null(x$ingredients)) {
    n_ing <- dplyr::n_distinct(x$ingredients$ingredient_snomed_code, na.rm = TRUE)
    n_comb <- if ("is_combination" %in% names(x$master)) {
      dplyr::n_distinct(
        x$master$vmp_snomed_code[x$master$is_combination],
        na.rm = TRUE
      )
    } else {
      0L
    }
    msg <- c(
      msg,
      "*" = "{n_ing} ingredients  |  {n_comb} combination VMP{?s}"
    )
  }

  cli::cli_inform(msg)
  invisible(x)
}

#' @export
format.dmd_db <- function(x, ...) {
  paste0(
    "<dmd_db> [",
    nrow(x$master),
    " rows, loaded ",
    format(x$loaded_at, "%Y-%m-%d"),
    "]"
  )
}

# ── dmd_master_info ───────────────────────────────────────────────────────────

#' Report metadata about a dm+d dataset
#'
#' Returns a concise summary of key attributes for the bundled [dmd_master]
#' dataset or a user-loaded [dmd_load()] database. Useful for confirming data
#' freshness in analysis scripts and Shiny app footers.
#'
#' @param db A `<dmd_db>` object from [dmd_load()], or the bundled [dmd_master]
#'   tibble. Defaults to the bundled [dmd_master].
#'
#' @return A list of class `"dmd_db_info"` with the following elements:
#'   \describe{
#'     \item{`release_label`}{Character. dm+d release label
#'       (e.g. `"Week 15 2026 (06 April 2026)"`). `NA` for user-loaded
#'       databases (use `loaded_at` instead).}
#'     \item{`loaded_at`}{`POSIXct` timestamp recording when [dmd_load()] was
#'       called. `NA` for the bundled `dmd_master`.}
#'     \item{`n_ampps`}{Number of distinct AMPPs (branded packs).}
#'     \item{`n_vmpps`}{Number of distinct VMPPs.}
#'     \item{`n_vmps`}{Number of distinct VMPs (generic medicines).}
#'     \item{`price_date_range`}{Character vector `c(earliest, latest)` of
#'       `price_date` values present in the dataset. Both `NA` if the column
#'       is absent or entirely `NA`.}
#'   }
#'
#' @export
#'
#' @examples
#' dmd_master_info()
#'
#' \dontrun{
#' db <- dmd_load("~/dmdDataLoader")
#' dmd_master_info(db)
#' }
dmd_master_info <- function(db = dmdprices::dmd_master) {
  is_db <- inherits(db, "dmd_db")
  master <- if (is_db) db$master else db

  release_label <- if (is_db) {
    NA_character_
  } else {
    lbl <- attr(db, "dmd_release_label", exact = TRUE)
    if (!is.null(lbl)) as.character(lbl) else NA_character_
  }

  loaded_at <- if (is_db) {
    db$loaded_at
  } else {
    structure(NA_real_, class = c("POSIXct", "POSIXt"))
  }

  price_date_range <- if ("price_date" %in% names(master)) {
    pd <- master$price_date[!is.na(master$price_date)]
    if (length(pd) > 0L) {
      c(min(pd), max(pd))
    } else {
      c(NA_character_, NA_character_)
    }
  } else {
    c(NA_character_, NA_character_)
  }

  structure(
    list(
      release_label = release_label,
      loaded_at = loaded_at,
      n_ampps = dplyr::n_distinct(master$ampp_snomed_code, na.rm = TRUE),
      n_vmpps = dplyr::n_distinct(master$vmpp_snomed_code, na.rm = TRUE),
      n_vmps = dplyr::n_distinct(master$vmp_snomed_code, na.rm = TRUE),
      price_date_range = price_date_range
    ),
    class = "dmd_db_info"
  )
}

#' @export
print.dmd_db_info <- function(x, ...) {
  label <- if (!is.na(x$release_label)) {
    x$release_label
  } else if (!is.na(x$loaded_at[[1]])) {
    paste0("loaded at ", format(x$loaded_at, "%Y-%m-%d %H:%M"))
  } else {
    "unknown"
  }

  pd <- x$price_date_range
  pd_str <- if (!is.na(pd[[1]])) {
    if (identical(pd[[1]], pd[[2]])) {
      pd[[1]]
    } else {
      paste0(pd[[1]], " - ", pd[[2]])
    }
  } else {
    "unknown"
  }

  cli::cli_inform(c(
    "v" = "dm+d dataset: {label}",
    "*" = "{x$n_vmps} VMPs  |  {x$n_vmpps} VMPPs  |  {x$n_ampps} AMPPs",
    "*" = "Price date: {pd_str}"
  ))
  invisible(x)
}
