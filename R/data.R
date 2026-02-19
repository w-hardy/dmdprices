#' NHS dm+d medicine pricing master table
#'
#' A joined pricing table built from the NHS Dictionary of Medicines and
#' Devices (dm+d), release **Week 34 2025 (14 August 2025)**. The table
#' combines Virtual Medicinal Products (VMPs), Virtual Medicinal Product Packs
#' (VMPPs), Actual Medicinal Product Packs (AMPPs), Drug Tariff reimbursement
#' prices, and NHS Indicative Prices into a single flat tibble.
#'
#' Column names and value formats are aligned with the **NHS Drug Tariff
#' Part VIIIA** CSV so that dm+d prices and Drug Tariff files can be used
#' together directly. Prices are in **pence**.
#'
#' Use [dmd_price_lookup()] to query this dataset by medicine name.
#'
#' Release metadata is stored as attributes and can be inspected with:
#'
#' ```r
#' attr(dmd_master, "dmd_release_label")
#' # [1] "Week 34 2025 (14 August 2025)"
#' ```
#'
#' @format A tibble with 118,196 rows and 12 columns. One row per AMPP
#'   (branded pack). A single generic VMP/VMPP appears on multiple rows when
#'   multiple manufacturers supply the same pack size.
#'
#' \describe{
#'   \item{Medicine}{`character`. Virtual Medicinal Product (VMP) name — the
#'     generic medicine name including strength and dose form,
#'     e.g. `"Metformin 500mg tablets"`.}
#'   \item{Pack size}{`numeric`. Numeric pack quantity.}
#'   \item{Unit}{`character`. Unit of measure for the pack quantity
#'     (e.g. `"tablet"`, `"ml"`, `"capsule"`, `"ampoule"`).}
#'   \item{VMP Snomed Code}{`character`. SNOMED CT identifier for the VMP.}
#'   \item{VMPP Snomed Code}{`character`. SNOMED CT identifier for the VMPP.}
#'   \item{Drug Tariff Category}{`character`. Drug Tariff reimbursement
#'     category, e.g. `"Part VIIIA Category M"`, `"Part VIIIA Category C"`.
#'     `NA` if the product is not reimbursed via the Drug Tariff.}
#'   \item{Basic Price}{`integer`. Drug Tariff basic price in **pence**.
#'     This is the reimbursement rate paid to pharmacies and is the same for
#'     all brands of the same VMPP. `NA` if not in the Drug Tariff.}
#'   \item{NHS Indicative Price}{`integer`. NHS Indicative Price in **pence**.
#'     This is the list price for the specific branded pack (AMPP) and may
#'     differ between manufacturers. `NA` where no indicative price is
#'     available.}
#'   \item{Price Basis}{`character`. Basis of the NHS Indicative Price,
#'     e.g. `"NHS Indicative Price"`. `NA` where not applicable.}
#'   \item{Price Date}{`character`. Date the NHS Indicative Price took effect
#'     (`"YYYY-MM-DD"`). `NA` where not applicable.}
#'   \item{AMPP Name}{`character`. Actual Medicinal Product Pack (AMPP) name —
#'     the full branded product name including manufacturer and pack
#'     description, e.g.
#'     `"Metformin 500mg tablets (A A H Pharmaceuticals Ltd) 28 tablet"`.}
#'   \item{AMPP Snomed Code}{`character`. SNOMED CT identifier for the AMPP.}
#' }
#'
#' @source
#' NHS Dictionary of Medicines and Devices (dm+d), Week 34 2025 release
#' (14 August 2025). Published by the NHS Business Services Authority (NHSBSA).
#'
#' © Crown copyright. Contains public sector information licensed under the
#' **Open Government Licence v3.0**.\cr
#' <https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/>
#'
#' dm+d is available from the NHSBSA TRUD service:\cr
#' <https://isd.digital.nhs.uk/trud/users/guest/filters/0/categories/6>
#'
#' @seealso [dmd_price_lookup()], [dmd_load()]
"dmd_master"
