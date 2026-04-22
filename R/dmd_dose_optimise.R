#' Find the cheapest or minimum-item combination for a clinical dose
#'
#' Given a dose (e.g. 900 mg), searches the dm+d for products matching `query`
#' and returns the cheapest combination of AMPPs that delivers that dose,
#' and/or the combination using the fewest items (tablets, ampoules, etc.).
#'
#' Products are segregated into preparation groups automatically so that, e.g.,
#' immediate-release and modified-release tablets are optimised separately and
#' never mixed within a single combination. For each group, up to two rows are
#' returned — one per objective.
#'
#' @param query        Character string passed through to [dmd_price_lookup()].
#' @param dose         Numeric dose value (in `dose_unit`).
#' @param dose_unit    One of `"mg"`, `"microgram"` / `"mcg"`, `"g"`, `"ml"`,
#'   `"unit"`. Default `"mg"`.
#' @param db           A `<dmd_db>` object from [dmd_load()] or a tibble in the
#'   same shape as [dmd_master]. Default: bundled [dmd_master].
#' @param method,max_dist,active_only Passed through to [dmd_price_lookup()].
#' @param price        Which price column to use — `"basic_price"` (default) or
#'   `"nhs_indicative_price"`. Falls back to the other column when the chosen
#'   one is NA for an individual AMPP (a note is added).
#' @param objective    `"both"` (default), `"cheapest"`, or `"min_items"`.
#' @param preparation  Optional character — a preparation-group key (e.g.
#'   `"tablet|none|oral"`) or label to filter groups before returning.
#'
#' @return A [tibble][tibble::tibble] with one row per
#'   `(preparation_group, objective)` combination. See the package vignette for
#'   the column layout. The `combination` column is a list of tibbles — one
#'   row per AMPP picked, identifying the specific branded product(s) used.
#'
#' @seealso [dmd_price_lookup()], [dmd_parse_strength()]
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Cheapest and minimum-item combinations for a 900 mg dose of metformin
#' dmd_dose_optimise("metformin", dose = 900, dose_unit = "mg")
#'
#' # Only modified-release tablets
#' dmd_dose_optimise(
#'   "metformin", dose = 1500, dose_unit = "mg",
#'   preparation = "tablet|modified-release|oral"
#' )
#' }
dmd_dose_optimise <- function(
  query,
  dose,
  dose_unit = c("mg", "microgram", "mcg", "g", "ml", "unit"),
  db = dmdprices::dmd_master,
  method = c("partial", "exact", "fuzzy"),
  max_dist = 3,
  price = c("basic_price", "nhs_indicative_price"),
  objective = c("both", "cheapest", "min_items"),
  preparation = NULL,
  active_only = TRUE
) {
  if (!is.numeric(dose) || length(dose) != 1 || is.na(dose) || dose <= 0) {
    cli::cli_abort("{.arg dose} must be a single positive numeric value.")
  }
  dose_unit <- match.arg(dose_unit)
  method <- match.arg(method)
  price <- match.arg(price)
  objective <- match.arg(objective)

  objectives <- switch(
    objective,
    both = c("cheapest", "min_items"),
    cheapest = "cheapest",
    min_items = "min_items"
  )

  # Canonicalise requested dose
  dose_canon <- .canonicalise_unit(dose, dose_unit)
  if (is.na(dose_canon$unit)) {
    cli::cli_abort("Unsupported {.arg dose_unit}: {.val {dose_unit}}.")
  }

  # Step 1: candidate AMPPs
  candidates <- dmd_price_lookup(
    query = query,
    db = db,
    method = method,
    max_dist = max_dist,
    active_only = active_only
  )
  if (nrow(candidates) == 0) {
    return(.empty_dose_result())
  }

  # Step 2: parse strength + preparation
  parsed <- dmd_parse_strength(candidates$medicine)
  prep <- .classify_preparation(parsed$tail)

  enriched <- dplyr::bind_cols(candidates, parsed, prep)

  # Determine per-item canonical dose — for concentration entries, multiply by
  # denominator_value (the container volume, e.g. 11.7 ml) and pack_size to
  # recover total mg per item. Without denominator_value, strength_canonical
  # is a repeating decimal (e.g. 1400/11.7 = 119.658...) that inflates the
  # integer scale factor and causes integer overflow downstream.
  enriched$per_item_dose <- ifelse(
    !is.na(enriched$denominator_unit),
    enriched$strength_canonical *
      enriched$denominator_value *
      enriched$pack_size,
    enriched$strength_canonical
  )

  # Select the price field + fallback per-row.
  alt_col <- setdiff(c("basic_price", "nhs_indicative_price"), price)
  primary <- enriched[[price]]
  alt <- enriched[[alt_col]]
  price_used <- ifelse(!is.na(primary), primary, alt)
  price_field <- ifelse(
    !is.na(primary),
    price,
    ifelse(!is.na(alt), alt_col, NA_character_)
  )
  price_fallback <- is.na(primary) & !is.na(alt)

  enriched$pack_price_pence <- price_used
  enriched$price_field_used <- price_field
  enriched$price_fallback <- price_fallback
  # For tablets/capsules the "item" is one tablet, priced pro-rata, and one
  # pack contains `pack_size` items. For concentration-based preparations
  # (liquids, inhalers) the "item" is the whole container: its price is the
  # whole pack price and one pack contains 1 item.
  is_concentration <- !is.na(enriched$denominator_unit)
  enriched$items_per_pack <- ifelse(is_concentration, 1, enriched$pack_size)
  enriched$per_item_price_pence <- ifelse(
    is_concentration,
    enriched$pack_price_pence,
    mapply(.per_item_price, enriched$pack_price_pence, enriched$pack_size)
  )

  # Drop rows we cannot optimise (no strength, no preparation, or mismatched
  # canonical unit vs requested dose).
  keep <- !is.na(enriched$per_item_dose) &
    !is.na(enriched$strength_unit_canon)

  # Compare dose canonical unit to each row's unit. Concentrations
  # (mg/ml) yield a mass per-item, so treat those as the mass side of the unit.
  row_mass_unit <- ifelse(
    grepl("/", enriched$strength_unit_canon),
    sub("/.*", "", enriched$strength_unit_canon),
    enriched$strength_unit_canon
  )
  keep <- keep & (row_mass_unit == dose_canon$unit)

  skipped <- sum(!keep)
  enriched <- enriched[keep, , drop = FALSE]

  if (nrow(enriched) == 0) {
    if (skipped > 0) {
      cli::cli_warn(
        "No candidates matched the requested dose unit ({.val {dose_canon$unit}}) after parsing; returning empty result."
      )
    }
    return(.empty_dose_result())
  }

  # Filter to requested preparation if supplied.
  if (!is.null(preparation)) {
    enriched <- dplyr::filter(
      enriched,
      .data$preparation_group == preparation |
        .data$preparation_label == preparation
    )
    if (nrow(enriched) == 0) {
      cli::cli_warn(
        "No candidates remain after filtering to preparation {.val {preparation}}."
      )
      return(.empty_dose_result())
    }
  }

  # Derive medicine root: lowest-cardinality stem within the filtered set.
  medicine_root <- .medicine_root(enriched$drug_stem)

  # Group by preparation_group alone. The per-row mass-unit has already been
  # checked to match the requested dose unit, so concentration and mass rows
  # within the same preparation are directly comparable.
  groups <- unique(enriched[,
    c("preparation_group", "preparation_label"),
    drop = FALSE
  ])

  out <- list()
  for (g in seq_len(nrow(groups))) {
    sub <- enriched[
      enriched$preparation_group == groups$preparation_group[g],
      ,
      drop = FALSE
    ]
    for (obj in objectives) {
      row <- .optimise_group(
        group_df = sub,
        dose_canonical = dose_canon$value,
        dose_unit_canon = dose_canon$unit,
        objective = obj,
        medicine_root = medicine_root,
        preparation_group = groups$preparation_group[g],
        preparation_label = groups$preparation_label[g]
      )
      if (!is.null(row)) out[[length(out) + 1L]] <- row
    }
  }

  if (length(out) == 0) {
    return(.empty_dose_result())
  }

  # Present all dose columns in the user-supplied unit so `dose_requested`,
  # `dose_delivered`, and `over_delivery` are directly comparable.
  result <- dplyr::bind_rows(out)
  conv <- .canonicalise_unit(1, dose_unit)
  back_factor <- if (is.na(conv$value) || conv$value == 0) 1 else 1 / conv$value
  result$dose_requested <- dose
  result$dose_unit <- dose_unit
  result$dose_delivered <- result$dose_delivered * back_factor
  result$dose_delivered_unit <- dose_unit
  result$over_delivery <- result$over_delivery * back_factor
  result
}

# Empty result scaffold with the declared columns.
.empty_dose_result <- function() {
  tibble::tibble(
    medicine_root = character(),
    preparation_group = character(),
    preparation_label = character(),
    objective = character(),
    dose_requested = numeric(),
    dose_unit = character(),
    dose_delivered = numeric(),
    dose_delivered_unit = character(),
    over_delivery = numeric(),
    total_items = integer(),
    cost_prorata_pence = numeric(),
    cost_whole_pack_pence = numeric(),
    price_field_used = character(),
    combination = list(),
    notes = character()
  )
}

# Pick a shared prefix across drug_stem values, falling back to the modal value.
.medicine_root <- function(stems) {
  stems <- stems[!is.na(stems) & nzchar(stems)]
  if (length(stems) == 0) {
    return(NA_character_)
  }
  tab <- sort(table(stems), decreasing = TRUE)
  names(tab)[1]
}

#' @export
print.dmd_dose_combination <- function(x, ...) {
  if (nrow(x) == 0) {
    cat("<dmd_dose_combination: empty>\n")
    return(invisible(x))
  }
  lines <- vapply(
    seq_len(nrow(x)),
    function(i) {
      sprintf("  %d \u00d7 %s", x$count[i], x$ampp_name[i])
    },
    character(1)
  )
  cat("<dmd_dose_combination>\n")
  cat(paste(lines, collapse = "\n"), "\n", sep = "")
  invisible(x)
}
