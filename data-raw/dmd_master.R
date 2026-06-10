## data-raw/dmd_master.R
##
## Builds and saves the bundled `dmd_master` dataset.
##
## Run this script whenever a new dm+d release is available:
##
##   source("data-raw/dmd_master.R")
##
## Requirements:
##   - The dmdDataLoader CSV output must be available at `dmd_loader_path`.
##   - Run from the package root directory.
##
## Attribution:
##   The underlying data is sourced from the NHS Dictionary of Medicines and
##   Devices (dm+d), published by the NHS Business Services Authority (NHSBSA).
##   © Crown copyright. Licensed under the Open Government Licence v3.0.
##   https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/

library(dplyr)
library(readr)
library(stringr)
library(stringdist)
library(here)
library(usethis)

# ── Configuration ─────────────────────────────────────────────────────────────

# Path to the dmdDataLoader folder (parent of csv/).
# here::here() resolves relative to the package root (where the .Rproj file
# lives), so this script can be run from any working directory.
#
# Edit the path below to point to your dmdDataLoader folder. Using here() keeps
# paths relative and removes the need for any hardcoded personal or
# machine-specific paths.
dmd_loader_path <- here::here("..", "dmdDataLoader")

# dm+d release metadata (update with each new release)
# File naming convention: f_vmp2_3<DDMMYY>.xml → week 15, 06 April 2026
dmd_release_week <- "15"
dmd_release_year <- "2026"
dmd_release_date <- as.Date("2026-04-06")
dmd_release_label <- paste0(
  "Week ",
  dmd_release_week,
  " ",
  dmd_release_year,
  " (",
  format(dmd_release_date, "%d %B %Y"),
  ")"
)

# ── Source internal helpers from the package ──────────────────────────────────

# Load the package internals without installing
pkgload::load_all(".", quiet = TRUE)

# ── Build master table ────────────────────────────────────────────────────────

csv_dir <- file.path(dmd_loader_path, "csv")

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
  # Ingredient (VPI) extract for combination-product handling. Optional: a
  # release without these files simply yields no ingredient data.
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

# ── Ingredient table + combination flag ───────────────────────────────────────

# Per-ingredient strengths (one row per VMP/ingredient). Fall back to a typed
# zero-row tibble when no VPI extract is present, so the bundled symbol always
# exists with a stable schema.
dmd_ingredients <- .build_ingredients(raw)
if (is.null(dmd_ingredients)) {
  message("No VPI extract found — bundling an empty dmd_ingredients table.")
  dmd_ingredients <- tibble::tibble(
    vmp_snomed_code = character(),
    ingredient_snomed_code = character(),
    ingredient_name = character(),
    strength_value = numeric(),
    strength_unit = character(),
    denominator_value = numeric(),
    denominator_unit = character(),
    strength_canonical = numeric(),
    strength_unit_canon = character()
  )
}

combination_flags <- .combination_flags(dmd_ingredients)

master <- .build_master(raw)
if (!is.null(combination_flags)) {
  master <- master |>
    dplyr::left_join(
      combination_flags,
      by = dplyr::join_by("vmp_snomed_code")
    ) |>
    dplyr::mutate(
      is_combination = !is.na(.data$is_combination) & .data$is_combination
    )
}

# Attach release metadata as attributes (accessible via attr(dmd_master, ...))
dmd_master <- structure(
  master,
  dmd_release_week = dmd_release_week,
  dmd_release_year = dmd_release_year,
  dmd_release_date = dmd_release_date,
  dmd_release_label = dmd_release_label,
  dmd_source = "NHS Dictionary of Medicines and Devices (dm+d)",
  dmd_publisher = "NHS Business Services Authority (NHSBSA)",
  dmd_licence = "Open Government Licence v3.0",
  dmd_licence_url = "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/"
)

message(
  "Built dmd_master: ",
  nrow(dmd_master),
  " rows | ",
  nrow(dmd_ingredients),
  " ingredient rows | release: ",
  dmd_release_label
)

# ── Save ──────────────────────────────────────────────────────────────────────

usethis::use_data(dmd_master, overwrite = TRUE, compress = "xz")
usethis::use_data(dmd_ingredients, overwrite = TRUE, compress = "xz")
