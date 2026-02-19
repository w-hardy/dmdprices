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
  lkp_pr_basis = c("CD", "DESC")
)

# ── Unit-of-measure lookup ────────────────────────────────────────────────────

#' @noRd
.uom_labels <- c(
  "258773002" = "ml",
  "258684004" = "mg",
  "428641000" = "capsule",
  "428673006" = "tablet",
  "3318211000001100" = "unit",
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

# ── Master table builder ──────────────────────────────────────────────────────

#' Build the joined master pricing table from raw dm+d tibbles.
#'
#' @param raw A named list as returned by `.load_raw()`.
#' @noRd
.build_master <- function(raw) {
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
      Unit = dplyr::coalesce(
        .uom_labels[.data$QTY_UOMCD],
        .uom_labels[.data$UNIT_DOSE_UOMCD],
        .data$QTY_UOMCD
      ),
      Pack_size = suppressWarnings(as.numeric(.data$QTYVAL)),
      "Basic Price" := suppressWarnings(as.integer(.data$DT_PRICE)),
      "NHS Indicative Price" := suppressWarnings(as.integer(.data$NHSIP_PRICE))
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
