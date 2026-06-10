# Internal helpers for dmdprices
# Not exported.

# ── Column name specifications ────────────────────────────────────────────────

.col_names <- list(
  vmp = c(
    "VPID",
    "VPIDDT",
    "VPIDPREV",
    "VTMID",
    "INVALID",
    "NM",
    "ABBREVNM",
    "BASISCD",
    "NMDT",
    "NMPREV",
    "BASIS_PREVCD",
    "NMCHANGECD",
    "COMBPRODCD",
    "PRES_STATCD",
    "SUG_F",
    "GLU_F",
    "PRES_F",
    "CFC_F",
    "NON_AVAILCD",
    "NON_AVAILDT",
    "DF_INDCD",
    "UDFS",
    "UDFS_UOMCD",
    "UNIT_DOSE_UOMCD"
  ),
  vmpp = c(
    "VPPID",
    "INVALID",
    "NM",
    "ABBREVNM",
    "VPID",
    "QTYVAL",
    "QTY_UOMCD",
    "COMBPACKCD"
  ),
  dt_info = c("VPPID", "PAY_CATCD", "PRICE", "DT", "PREVPRICE"),
  ampp = c(
    "APPID",
    "INVALID",
    "NM",
    "ABBREVNM",
    "VPPID",
    "APID",
    "COMBPACKCD",
    "LEGAL_CATCD",
    "SUBP",
    "DISCCD",
    "DISCDT"
  ),
  price_info = c("APPID", "PRICE", "PRICEDT", "PRICE_PREV", "PRICE_BASISCD"),
  lkp_dt_cat = c("CD", "DESC"),
  lkp_pr_basis = c("CD", "DESC"),
  # Virtual Product Ingredient: one row per (VMP, ingredient) with strength.
  vpi = c(
    "VPID",
    "ISID",
    "BASIS_STRNTCD",
    "BS_SUBID",
    "STRNT_NMRTR_VAL",
    "STRNT_NMRTR_UOMCD",
    "STRNT_DNMTR_VAL",
    "STRNT_DNMTR_UOMCD"
  ),
  # Ingredient substance lookup (ISID → name).
  ingredient = c("ISID", "ISIDDT", "ISIDPREV", "INVALID", "NM"),
  # Unit-of-measure lookup (CD → DESC).
  lkp_uom = c("CD", "CDDT", "CDPREV", "DESC")
)

# ── Unit-of-measure lookup ────────────────────────────────────────────────────

#' @noRd
.uom_labels <- c(
  "258773002" = "ml",
  "258684004" = "mg",
  "258682000" = "g",
  "428641000" = "capsule",
  "428673006" = "tablet",
  "3318211000001100" = "unit",
  "3317411000001100" = "dose",
  "3318611000001103" = "pre-filled disposable injection",
  "413516001" = "ampoule",
  "415818006" = "vial",
  "733015007" = "ml"
)

# ── Low-level CSV reader ──────────────────────────────────────────────────────

#' Read a single pipe-delimited dm+d CSV.
#'
#' @param csv_dir Path to the `csv/` subdirectory inside `dmdDataLoader/`.
#' @param file    Filename (no path).
#' @param cols    Character vector of column names.
#' @noRd
.read_dmd <- function(csv_dir, file, cols) {
  path <- file.path(csv_dir, file)
  if (!file.exists(path)) {
    cli::cli_abort(
      "Expected file not found: {.path {path}}"
    )
  }
  readr::read_delim(
    path,
    delim = "|",
    col_names = cols,
    col_types = readr::cols(.default = readr::col_character()),
    trim_ws = TRUE,
    show_col_types = FALSE
  )
}

#' Read an optional dm+d CSV, returning NULL if it is absent.
#'
#' Used for files (e.g. the VPI ingredient extract) that may not be present in
#' every dmdDataLoader output, so loading degrades gracefully.
#' @noRd
.read_dmd_optional <- function(csv_dir, file, cols) {
  if (!file.exists(file.path(csv_dir, file))) {
    return(NULL)
  }
  .read_dmd(csv_dir, file, cols)
}

# ── Master table builder ──────────────────────────────────────────────────────

#' Build the joined master pricing table from raw dm+d tibbles.
#'
#' @param raw A named list as returned by `.load_raw()`.
#' @noRd
.build_master <- function(raw) {
  # Build a fallback unit-of-measure label map (CD -> DESC) from the lookup
  # extract, used for pack-unit codes that are not in the curated
  # `.uom_labels`. `.uom_labels` is preferred so canonicalisable short labels
  # (e.g. "ml", "tablet") are preserved for the dose-optimiser; the lookup only
  # fills in otherwise-unmapped codes such as the pre-filled-syringe unit.
  uom_desc <- if (is.null(raw$lkp_uom)) {
    character()
  } else {
    u <- raw$lkp_uom[!duplicated(raw$lkp_uom$CD), , drop = FALSE]
    stats::setNames(u$DESC, u$CD)
  }

  # Valid VMPs
  vmp_valid <- raw$vmp |>
    dplyr::filter(is.na(.data$INVALID) | .data$INVALID == "") |>
    dplyr::select("VPID", VMP_NM = "NM", "UDFS", "UNIT_DOSE_UOMCD")

  # Valid VMPPs
  vmpp_valid <- raw$vmpp |>
    dplyr::filter(is.na(.data$INVALID) | .data$INVALID == "") |>
    dplyr::select("VPPID", VMPP_NM = "NM", "VPID", "QTYVAL", "QTY_UOMCD")

  # Drug Tariff prices — most recent entry per VPPID
  dt_prices <- raw$dt_info |>
    dplyr::group_by(.data$VPPID) |>
    dplyr::slice_max(order_by = .data$DT, n = 1, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::left_join(
      raw$lkp_dt_cat,
      by = dplyr::join_by("PAY_CATCD" == "CD")
    ) |>
    dplyr::rename(DT_CAT = "DESC", DT_PRICE = "PRICE", DT_DATE = "DT")

  # Valid, non-discontinued AMPPs
  ampp_valid <- raw$ampp |>
    dplyr::filter(is.na(.data$INVALID) | .data$INVALID == "") |>
    dplyr::filter(is.na(.data$DISCCD) | .data$DISCCD == "") |>
    dplyr::select("APPID", AMPP_NM = "NM", "VPPID")

  # NHS Indicative Prices — most recent entry per APPID
  nhsip <- raw$price_info |>
    dplyr::group_by(.data$APPID) |>
    dplyr::slice_max(order_by = .data$PRICEDT, n = 1, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::left_join(
      raw$lkp_pr_basis,
      by = dplyr::join_by("PRICE_BASISCD" == "CD")
    ) |>
    dplyr::rename(
      NHSIP_PRICE = "PRICE",
      NHSIP_DATE = "PRICEDT",
      NHSIP_BASIS = "DESC"
    )

  # Full hierarchy join: VMP → VMPP → DT price → AMPP → NHSIP
  vmp_valid |>
    dplyr::inner_join(vmpp_valid, by = dplyr::join_by("VPID")) |>
    dplyr::left_join(dt_prices, by = dplyr::join_by("VPPID")) |>
    dplyr::left_join(ampp_valid, by = dplyr::join_by("VPPID")) |>
    dplyr::left_join(nhsip, by = dplyr::join_by("APPID")) |>
    dplyr::mutate(
      # unname() because named-vector lookups (.uom_labels / uom_desc) otherwise
      # leave SNOMED codes as names on the resulting `unit` column.
      Unit = unname(dplyr::coalesce(
        .uom_labels[.data$QTY_UOMCD],
        .uom_labels[.data$UNIT_DOSE_UOMCD],
        uom_desc[.data$QTY_UOMCD],
        uom_desc[.data$UNIT_DOSE_UOMCD],
        .data$QTY_UOMCD
      )),
      Pack_size = suppressWarnings(as.numeric(.data$QTYVAL)),
      "Basic Price" := dplyr::na_if(
        suppressWarnings(as.integer(.data$DT_PRICE)),
        0L
      ),
      "NHS Indicative Price" := dplyr::na_if(
        suppressWarnings(as.integer(.data$NHSIP_PRICE)),
        0L
      )
    ) |>
    dplyr::select(
      medicine = "VMP_NM",
      pack_size = "Pack_size",
      unit = "Unit",
      vmp_snomed_code = "VPID",
      vmpp_snomed_code = "VPPID",
      drug_tariff_category = "DT_CAT",
      basic_price = "Basic Price",
      nhs_indicative_price = "NHS Indicative Price",
      price_basis = "NHSIP_BASIS",
      price_date = "NHSIP_DATE",
      ampp_name = "AMPP_NM",
      ampp_snomed_code = "APPID"
    )
}

# ── Ingredient (VPI) table builder ────────────────────────────────────────────

# Map dm+d unit-of-measure DESC labels onto the tokens understood by
# .canonicalise_unit(). dm+d uses short forms ("mg", "ml") but spells out some
# units ("microgram", "gram", "litre"); normalise the long forms here. Unknown
# labels pass through unchanged and canonicalise to NA.
.normalise_uom_label <- function(x) {
  x <- tolower(trimws(x))
  dplyr::case_when(
    x %in% c("milligram", "milligrams") ~ "mg",
    x %in% c("gram", "grams", "gramme", "grammes") ~ "g",
    x %in% c("microgram", "micrograms") ~ "microgram",
    x %in% c("nanogram", "nanograms") ~ "nanogram",
    x %in% c("litre", "litres", "liter", "liters") ~ "litre",
    x %in% c("millilitre", "millilitres", "milliliter", "milliliters") ~ "ml",
    is.na(x) ~ NA_character_,
    TRUE ~ x
  )
}

# Build a tidy per-ingredient strength table from the raw VPI, ingredient, and
# unit-of-measure lookups. One row per (VMP, ingredient). Returns NULL when the
# VPI extract is not available (older loader outputs), so ingredient features
# degrade gracefully. Columns: vmp_snomed_code, ingredient_snomed_code,
# ingredient_name, strength_value, strength_unit, denominator_value,
# denominator_unit, strength_canonical, strength_unit_canon.
.build_ingredients <- function(raw) {
  if (is.null(raw$vpi) || nrow(raw$vpi) == 0L) {
    return(NULL)
  }

  uom <- if (is.null(raw$lkp_uom)) {
    tibble::tibble(CD = character(), uom_label = character())
  } else {
    dplyr::transmute(
      raw$lkp_uom,
      CD = .data$CD,
      uom_label = .normalise_uom_label(.data$DESC)
    )
  }

  ing <- if (is.null(raw$ingredient)) {
    tibble::tibble(ISID = character(), ingredient_name = character())
  } else {
    raw$ingredient |>
      dplyr::filter(is.na(.data$INVALID) | .data$INVALID == "") |>
      dplyr::select("ISID", ingredient_name = "NM")
  }

  out <- raw$vpi |>
    dplyr::left_join(ing, by = dplyr::join_by("ISID")) |>
    dplyr::left_join(
      uom,
      by = dplyr::join_by("STRNT_NMRTR_UOMCD" == "CD")
    ) |>
    dplyr::rename(strength_unit = "uom_label") |>
    dplyr::left_join(
      uom,
      by = dplyr::join_by("STRNT_DNMTR_UOMCD" == "CD")
    ) |>
    dplyr::rename(denominator_unit = "uom_label") |>
    dplyr::transmute(
      vmp_snomed_code = .data$VPID,
      ingredient_snomed_code = .data$ISID,
      ingredient_name = .data$ingredient_name,
      strength_value = suppressWarnings(as.numeric(.data$STRNT_NMRTR_VAL)),
      strength_unit = .data$strength_unit,
      denominator_value = suppressWarnings(as.numeric(.data$STRNT_DNMTR_VAL)),
      denominator_unit = .data$denominator_unit
    )

  can <- mapply(
    function(v, u) .canonicalise_unit(v, u),
    out$strength_value,
    out$strength_unit,
    SIMPLIFY = FALSE
  )
  out$strength_canonical <- vapply(can, function(z) z$value, numeric(1))
  out$strength_unit_canon <- vapply(can, function(z) z$unit, character(1))

  tibble::as_tibble(out)
}

# Logical per-VMP combination flag derived authoritatively from the ingredient
# table: a VMP with two or more distinct ingredients is a combination product.
# Returns a tibble (vmp_snomed_code, is_combination), or NULL when ingredient
# data is unavailable.
.combination_flags <- function(ingredients) {
  if (is.null(ingredients) || nrow(ingredients) == 0L) {
    return(NULL)
  }
  ingredients |>
    dplyr::group_by(.data$vmp_snomed_code) |>
    dplyr::summarise(
      is_combination = dplyr::n_distinct(.data$ingredient_snomed_code) >= 2L,
      .groups = "drop"
    )
}
