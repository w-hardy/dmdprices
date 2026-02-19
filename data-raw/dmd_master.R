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
# File naming convention: f_vmp2_3<DDMMYY>.xml → week 34, 14 August 2025
dmd_release_week <- "34"
dmd_release_year <- "2025"
dmd_release_date <- as.Date("2025-08-14")
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
  )
)

dmd_master <- .build_master(raw) |>
  # Attach release metadata as attributes (accessible via attr(dmd_master, ...))
  structure(
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
  " rows | release: ",
  dmd_release_label
)

# ── Save ──────────────────────────────────────────────────────────────────────

usethis::use_data(dmd_master, overwrite = TRUE, compress = "xz")
