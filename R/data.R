#' NHS dm+d medicine pricing master table
#'
#' A joined pricing table built from the NHS Dictionary of Medicines and
#' Devices (dm+d), release **Week 15 2026 (06 April 2026)**. The table
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
#' # [1] "Week 15 2026 (06 April 2026)"
#' ```
#'
#' @format A tibble with 118,196 rows and 13 columns. One row per AMPP
#'   (branded pack). A single generic VMP/VMPP appears on multiple rows when
#'   multiple manufacturers supply the same pack size.
#'
#' \describe{
#'   \item{medicine}{`character`. Virtual Medicinal Product (VMP) name — the
#'     generic medicine name including strength and dose form,
#'     e.g. `"Metformin 500mg tablets"`.}
#'   \item{pack_size}{`numeric`. Numeric pack quantity.}
#'   \item{unit}{`character`. Unit of measure for the pack quantity
#'     (e.g. `"tablet"`, `"ml"`, `"capsule"`, `"ampoule"`).}
#'   \item{vmp_snomed_code}{`character`. SNOMED CT identifier for the VMP.}
#'   \item{vmpp_snomed_code}{`character`. SNOMED CT identifier for the VMPP.}
#'   \item{drug_tariff_category}{`character`. Drug Tariff reimbursement
#'     category, e.g. `"Part VIIIA Category M"`, `"Part VIIIA Category C"`.
#'     `NA` if the product is not reimbursed via the Drug Tariff.}
#'   \item{basic_price}{`integer`. Drug Tariff basic price in **pence**.
#'     This is the reimbursement rate paid to pharmacies and is the same for
#'     all brands of the same VMPP. `NA` if not in the Drug Tariff.}
#'   \item{nhs_indicative_price}{`integer`. NHS Indicative Price in **pence**.
#'     This is the list price for the specific branded pack (AMPP) and may
#'     differ between manufacturers. `NA` where no indicative price is
#'     available.}
#'   \item{price_basis}{`character`. Basis of the NHS Indicative Price,
#'     e.g. `"NHS Indicative Price"`. `NA` where not applicable.}
#'   \item{price_date}{`character`. Date the NHS Indicative Price took effect
#'     (`"YYYY-MM-DD"`). `NA` where not applicable.}
#'   \item{ampp_name}{`character`. Actual Medicinal Product Pack (AMPP) name —
#'     the full branded product name including manufacturer and pack
#'     description, e.g.
#'     `"Metformin 500mg tablets (A A H Pharmaceuticals Ltd) 28 tablet"`.}
#'   \item{ampp_snomed_code}{`character`. SNOMED CT identifier for the AMPP.}
#'   \item{is_combination}{`logical`. `TRUE` when the VMP has two or more
#'     distinct active ingredients (derived from the dm+d Virtual Product
#'     Ingredient data); see [dmd_ingredients].}
#' }
#'
#' @source
#' NHS Dictionary of Medicines and Devices (dm+d), Week 15 2026 release
#' (06 April 2026). Published by the NHS Business Services Authority (NHSBSA).
#'
#' Prices are **derived from dm+d**; the column layout mirrors the NHS Drug
#' Tariff Part VIIIA CSV for interoperability, but that published CSV is not the
#' source of these values.
#'
#' © Crown copyright. Contains public sector information licensed under the
#' **Open Government Licence v3.0**.\cr
#' <https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/>
#'
#' dm+d is available from the NHSBSA TRUD service:\cr
#' <https://isd.digital.nhs.uk/trud/users/guest/filters/0/categories/6>
#'
#' @seealso [dmd_price_lookup()], [dmd_load()], [dmd_ingredients]
"dmd_master"

#' NHS dm+d per-ingredient strengths
#'
#' A tidy table of ingredient strengths built from the dm+d Virtual Product
#' Ingredient (VPI) extract, with one row per (VMP, ingredient). It identifies
#' the individual active ingredients — and their strengths — of every VMP,
#' including combination products such as co-codamol, enabling
#' ingredient-specific dose optimisation via [dmd_dose_optimise()].
#'
#' A VMP with two or more distinct ingredients is a combination product; this is
#' also surfaced as the `is_combination` column on a [dmd_load()] database's
#' `$master` table.
#'
#' @details
#' The bundled table is built from the same Week 15 2026 release as
#' [dmd_master] and has 26,667 rows (`nrow(dmd_ingredients)`).
#' `data-raw/dmd_master.R` rebuilds both datasets.
#'
#' A database loaded with [dmd_load()] carries its own `$ingredients` table,
#' which is used in place of this one. That table depends on optional files of
#' the `dmdDataLoader` export. Without `f_vmp_VpiType.csv` it is `NULL`, and
#' the `ingredient` argument of [dmd_dose_optimise()] returns no results, with
#' a warning. Without `f_ingredient.csv` it is built but `ingredient_name` is
#' `NA`, so `ingredient` matches nothing. Without
#' `f_lookup_UoMHistoryInfoType.csv` its strength units are `NA`, so
#' `ingredient` skips every candidate as having a non-mass strength.
#'
#' @format A tibble with one row per VMP/ingredient and 9 columns:
#' \describe{
#'   \item{vmp_snomed_code}{`character`. SNOMED CT identifier for the VMP.}
#'   \item{ingredient_snomed_code}{`character`. SNOMED CT identifier for the
#'     ingredient substance (ISID).}
#'   \item{ingredient_name}{`character`. Ingredient substance name,
#'     e.g. `"Codeine phosphate"`.}
#'   \item{strength_value}{`numeric`. Strength numerator value.}
#'   \item{strength_unit}{`character`. Strength numerator unit (e.g. `"mg"`).}
#'   \item{denominator_value}{`numeric`. Strength denominator value for
#'     concentrations, else `NA`.}
#'   \item{denominator_unit}{`character`. Strength denominator unit
#'     (e.g. `"ml"`), else `NA`.}
#'   \item{strength_canonical}{`numeric`. Strength in canonical units: the
#'     canonical numerator (mass in mg, volume in ml, or biological activity
#'     as `"unit"`) per **one canonical denominator unit** for a
#'     concentration, or the canonical numerator alone otherwise. This is the
#'     same convention as [dmd_parse_strength()] applies to product names, so
#'     "20 mg per 1 g" is `0.02` (mg per mg) and "500 mg per 50 ml" is `10`
#'     (mg per ml). `NA` for strengths recorded in units that have no mass
#'     equivalent (e.g. radioactivity in GBq/MBq, amount of substance in mmol,
#'     vaccine antigen units, or volumes such as microlitre) or whose
#'     denominator has no canonical unit (e.g. per hour for a patch). Such
#'     ingredients cannot be dose-optimised by mass via [dmd_dose_optimise()].}
#'   \item{strength_unit_canon}{`character`. Canonical strength unit in slash
#'     form for a concentration (`"mg/mg"`, `"mg/ml"`, `"unit/ml"`), or the
#'     canonical numerator unit alone (`"mg"`); `NA` when the strength has no
#'     mass/volume/activity equivalent.}
#' }
#'
#' @source
#' NHS Dictionary of Medicines and Devices (dm+d). Published by the NHS Business
#' Services Authority (NHSBSA).
#'
#' © Crown copyright. Contains public sector information licensed under the
#' **Open Government Licence v3.0**.\cr
#' <https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/>
#'
#' @seealso [dmd_master], [dmd_dose_optimise()], [dmd_load()]
"dmd_ingredients"
