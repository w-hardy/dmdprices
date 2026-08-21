# ── Memoized candidate preparation ──────────────────────────────────────────

# Convert a character vector of unit labels to canonical unit labels.
.canonicalise_unit_name <- function(unit) {
  vapply(
    unit,
    function(u) .canonicalise_unit(1, u)$unit,
    character(1)
  )
}

# Convert a value/unit pair to a canonical value.
.canonicalise_unit_value <- function(value, unit) {
  mapply(
    function(v, u) .canonicalise_unit(v, u)$value,
    value,
    unit,
    SIMPLIFY = TRUE,
    USE.NAMES = FALSE
  )
}

# Total dose represented by one discrete optimisation item. For liquids with a
# pack unit matching the denominator unit, use the pack quantity. For vials and
# other container-count packs, use the concentration denominator volume.
.per_item_dose <- function(enriched) {
  out <- enriched$strength_canonical
  is_concentration <- !is.na(enriched$denominator_unit)
  if (!any(is_concentration)) {
    return(out)
  }

  pack_unit_canon <- .canonicalise_unit_name(enriched$unit)
  den_unit_canon <- .canonicalise_unit_name(enriched$denominator_unit)
  den_value_canon <- .canonicalise_unit_value(
    enriched$denominator_value,
    enriched$denominator_unit
  )

  use_pack_quantity <- is_concentration &
    !is.na(pack_unit_canon) &
    !is.na(den_unit_canon) &
    pack_unit_canon == den_unit_canon

  multiplier <- den_value_canon
  multiplier[use_pack_quantity] <- enriched$pack_size[use_pack_quantity]

  out[is_concentration] <-
    enriched$strength_canonical[is_concentration] *
      multiplier[is_concentration]
  out
}

.strength_token_count <- function(name) {
  # .strength_num accepts comma thousands groups so a "1,000unit" token is
  # counted from its true start rather than from the digits after the comma.
  pattern <- paste0(
    "(?i)", .strength_num, "\\s*",
    "(?:micrograms?|mcg|mg|ng|nanograms?|g|units?|u)\\b"
  )
  matches <- gregexpr(pattern, name, perl = TRUE)
  vapply(
    matches,
    function(m) {
      if (length(m) == 1L && (is.na(m) || identical(m, -1L))) {
        0L
      } else {
        length(m)
      }
    },
    integer(1)
  )
}

.is_unsupported_compound <- function(enriched) {
  den_unit <- tolower(enriched$denominator_unit)
  num_unit_canon <- .canonicalise_unit_name(enriched$strength_unit)
  den_unit_canon <- .canonicalise_unit_name(den_unit)

  topical_mass_concentration <- enriched$form %in% c("cream", "ointment", "gel") &
    den_unit == "g"

  same_dose_unit_ratio <- !is.na(den_unit) &
    !is.na(num_unit_canon) &
    !is.na(den_unit_canon) &
    num_unit_canon == den_unit_canon &
    num_unit_canon %in% c("mg", "unit")

  multiple_strengths <- .strength_token_count(enriched$medicine) > 1L

  # The dm+d VPI-derived is_combination flag is authoritative where present
  # (bundled data and dmd_load() databases; the parser's name-based flag fills
  # in otherwise). A product dm+d records as a combination has no single
  # meaningful strength however its name reads — allergen mixes and factor
  # concentrates list one number for many ingredients — so it always requires
  # ingredient targeting, and it is not excused by the topical w/w exemption.
  # The name heuristic is kept as a union: multi-strength names like
  # "X 50mg tablets and X 100mg tablets" are ambiguous per-item even when
  # dm+d does not flag them as combinations.
  db_combination <- if ("is_combination" %in% names(enriched)) {
    enriched$is_combination %in% TRUE
  } else {
    FALSE
  }

  ((same_dose_unit_ratio | multiple_strengths) & !topical_mass_concentration) |
    db_combination
}

.drop_unsupported_compounds <- function(enriched) {
  if (!"unsupported_compound" %in% names(enriched)) {
    return(enriched)
  }

  n <- sum(enriched$unsupported_compound, na.rm = TRUE)
  if (n > 0L) {
    skipped <- unique(enriched$medicine[
      enriched$unsupported_compound %in% TRUE
    ])
    shown <- utils::head(skipped, 3L)
    more <- length(skipped) - length(shown)
    more_txt <- if (more > 0L) paste0(" and ", more, " more") else ""
    # The first line must keep its wording: dmd_dose_cost_range() and callers
    # de-duplicate this warning by matching "unsupported compound product".
    cli::cli_warn(c(
      "{n} unsupported compound product{?s} skipped during dose optimisation.",
      "x" = "E.g. {.val {shown}}{more_txt}.",
      "i" = 'Pass {.code ingredient = "<name>"} to dose one active ingredient of a combination product (e.g. the codeine in co-codamol).'
    ))
  }
  enriched[!enriched$unsupported_compound, , drop = FALSE]
}

# Performs all dose-independent work: price lookup, strength parsing,
# preparation classification, and price-field resolution. The result is
# memoized at session level so repeated calls for the same
# (query, db, method, max_dist, active_only, price) combination are free.
#
# Returns the enriched tibble ready for DP, or NULL if no candidates found.
.dmd_prepare_candidates <- function(
  query,
  db,
  method,
  max_dist,
  active_only,
  price
) {
  candidates <- dmd_price_lookup(
    query = query,
    db = db,
    method = method,
    max_dist = max_dist,
    active_only = active_only
  )
  if (nrow(candidates) == 0) {
    return(NULL)
  }

  parsed <- dmd_parse_strength(candidates$medicine)
  prep <- .classify_preparation(parsed$tail)

  # The database may already carry an authoritative `is_combination` flag
  # (derived from the dm+d VPI ingredient data). Prefer it over the parser's
  # name-based heuristic and avoid a duplicate-name clash in bind_cols().
  if ("is_combination" %in% names(candidates)) {
    parsed$is_combination <- NULL
  }

  enriched <- dplyr::bind_cols(candidates, parsed, prep)

  enriched$unsupported_compound <- .is_unsupported_compound(enriched)
  enriched$per_item_dose <- .per_item_dose(enriched)

  # Resolve price field with per-row fallback.
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

  is_concentration <- !is.na(enriched$denominator_unit)
  enriched$items_per_pack <- ifelse(is_concentration, 1, enriched$pack_size)

  # Pro-rata per-item price for solid forms. NA pack_size or non-positive
  # pack_size yields NA; NA pack_price propagates through division.
  safe_pack_size <- enriched$pack_size
  safe_pack_size[!is.na(safe_pack_size) & safe_pack_size <= 0] <- NA_real_
  enriched$per_item_price_pence <- ifelse(
    is_concentration,
    enriched$pack_price_pence,
    enriched$pack_price_pence / safe_pack_size
  )

  enriched
}

.validate_ingredient <- function(ingredient) {
  if (is.null(ingredient)) {
    return(invisible())
  }
  if (
    !is.character(ingredient) ||
      length(ingredient) != 1L ||
      is.na(ingredient) ||
      !nzchar(trimws(ingredient))
  ) {
    cli::cli_abort("{.arg ingredient} must be NULL or a single non-empty string.")
  }
  invisible()
}

# Resolve the per-ingredient strength table for a database: the loaded
# `$ingredients` for a <dmd_db>, otherwise the bundled `dmd_ingredients`.
.resolve_ingredients <- function(db) {
  if (inherits(db, "dmd_db")) {
    return(db$ingredients)
  }
  tryCatch(dmdprices::dmd_ingredients, error = function(...) NULL)
}

# Restrict candidates to products containing `ingredient` and dose against that
# ingredient's strength (rather than the parsed whole-product strength). This is
# what lets combination products (e.g. co-codamol) be optimised for a single
# active ingredient. Returns a zero-row frame (with a warning) when ingredient
# data is unavailable or nothing matches.
.apply_ingredient_targeting <- function(enriched, db, ingredient) {
  ing_tbl <- .resolve_ingredients(db)
  if (is.null(ing_tbl) || nrow(ing_tbl) == 0L) {
    cli::cli_warn(c(
      "No ingredient data available to target {.val {ingredient}}.",
      "i" = "Load a dm+d release that includes the VPI extract with {.fn dmd_load}, or rebuild the bundled data."
    ))
    return(enriched[0, , drop = FALSE])
  }

  # Match the ingredient name on a word boundary so that, e.g., "codeine" does
  # not also match "dihydrocodeine". \Q...\E quotes any regex metacharacters in
  # the user-supplied term.
  pattern <- paste0("\\b\\Q", ingredient, "\\E\\b")
  is_match <- grepl(
    pattern,
    ing_tbl$ingredient_name,
    ignore.case = TRUE,
    perl = TRUE
  )
  matches <- ing_tbl[is_match, , drop = FALSE]
  if (nrow(matches) == 0L) {
    cli::cli_warn("No ingredient matching {.val {ingredient}} found.")
    return(enriched[0, , drop = FALSE])
  }

  # The term may still resolve to more than one distinct ingredient (e.g. a
  # base substance and its salt). Surface that rather than silently choosing.
  distinct_names <- sort(unique(matches$ingredient_name))
  if (length(distinct_names) > 1L) {
    cli::cli_warn(c(
      "{.arg ingredient} {.val {ingredient}} matched {length(distinct_names)} distinct ingredients: {.val {distinct_names}}.",
      "i" = "All matches are used; supply a more specific name to narrow this."
    ))
  }

  # One strength per VMP (first match wins if a VMP lists it more than once).
  matches <- matches[!duplicated(matches$vmp_snomed_code), , drop = FALSE]

  idx <- match(enriched$vmp_snomed_code, matches$vmp_snomed_code)
  keep <- !is.na(idx)
  enriched <- enriched[keep, , drop = FALSE]
  idx <- idx[keep]
  if (nrow(enriched) == 0L) {
    return(enriched)
  }

  enriched$strength_value <- matches$strength_value[idx]
  enriched$strength_unit <- matches$strength_unit[idx]
  enriched$denominator_value <- matches$denominator_value[idx]
  enriched$denominator_unit <- matches$denominator_unit[idx]
  enriched$strength_canonical <- matches$strength_canonical[idx]
  enriched$strength_unit_canon <- matches$strength_unit_canon[idx]
  enriched$targeted_ingredient <- matches$ingredient_name[idx]

  # The named ingredient gives an unambiguous dose, so these rows are now
  # optimisable even when the product is a combination.
  enriched$unsupported_compound <- FALSE
  enriched$per_item_dose <- .per_item_dose(enriched)

  # Some ingredients are recorded in non-mass units (e.g. GBq, mmol, vaccine
  # units) that cannot be canonicalised to a mass dose. Those rows yield an NA
  # per-item dose and are dropped downstream; warn instead of failing silently.
  na_canon <- is.na(enriched$strength_canonical)
  if (any(na_canon)) {
    bad_units <- sort(unique(stats::na.omit(enriched$strength_unit[na_canon])))
    cli::cli_warn(c(
      "{sum(na_canon)} candidate{?s} for {.val {ingredient}} ha{?s/ve} a non-mass strength and cannot be dosed by mass; skipped.",
      "i" = "Strength unit{?s}: {.val {bad_units}}."
    ))
  }

  is_concentration <- !is.na(enriched$denominator_unit)
  enriched$items_per_pack <- ifelse(is_concentration, 1, enriched$pack_size)
  safe_pack_size <- enriched$pack_size
  safe_pack_size[!is.na(safe_pack_size) & safe_pack_size <= 0] <- NA_real_
  enriched$per_item_price_pence <- ifelse(
    is_concentration,
    enriched$pack_price_pence,
    enriched$pack_price_pence / safe_pack_size
  )

  enriched
}

# Session-level memo with a lightweight cache key. The bundled dmd_master is
# a ~118k-row tibble; memoise::memoise() would digest() the whole object on
# every call. Instead we key on scalars only:
#   - dmd_db objects: their loaded_at timestamp (set by dmd_load()).
#   - bundled dmd_master: its dmd_release_label attribute.
#   - any other tibble: rlang::hash() as a one-shot fallback (rare in practice).
# Cache is capped at 1 GB; entries are separated by a NUL byte to prevent
# collisions from adjacent argument concatenation.
.db_cache_key <- function(db) {
  if (inherits(db, "dmd_db")) {
    return(format(db$loaded_at, "%Y%m%dT%H%M%OS6"))
  }
  lbl <- attr(db, "dmd_release_label", exact = TRUE)
  if (!is.null(lbl)) lbl else rlang::hash(db)
}

.dmd_prepare_candidates_memo <- memoise::memoise(
  .dmd_prepare_candidates,
  hash = function(args) {
    rlang::hash(paste(
      args$query,
      .db_cache_key(args$db),
      args$method,
      args$max_dist,
      args$active_only,
      args$price,
      sep = "\x1f"
    ))
  },
  cache = cachem::cache_mem(max_size = 1024 * 1024^2)
)

#' Find dose combinations for a clinical dose
#'
#' Given a dose (e.g. 900 mg), searches the dm+d for products matching `query`
#' and returns the cheapest, most expensive, and/or fewest-item combination of
#' AMPPs that delivers that dose.
#'
#' Products are segregated into preparation groups automatically so that, e.g.,
#' immediate-release and modified-release tablets are optimised separately and
#' never mixed within a single combination. For each group, one row is returned
#' per requested objective.
#'
#' Combination (multi-ingredient) products are skipped with a warning rather
#' than optimised against an ambiguous dose. A product counts as a combination
#' when the dm+d `is_combination` flag says so (authoritative, covering e.g.
#' allergen mixes and factor concentrates whose names show a single number) or
#' when its name lists multiple active strengths. Supply `ingredient` to dose
#' such a product against one named active ingredient instead.
#'
#' @param query        Character string passed through to [dmd_price_lookup()].
#' @param dose         Numeric dose value (in `dose_unit`), **or** a
#'   self-contained dose string such as `"250 mg"`, `"250mg"`, or
#'   `"0.25 g"`. Comma thousands separators are accepted (`"100,000 units"`).
#'   When a string is supplied `dose_unit` may be omitted.
#' @param dose_unit    One of `"mg"`, `"microgram"` / `"mcg"`, `"g"`, `"ml"`,
#'   `"unit"`. Default `"mg"`. Ignored (with a warning) if `dose` is a
#'   string that already contains a unit.
#' @param db           A `<dmd_db>` object from [dmd_load()] or a tibble in the
#'   same shape as [dmd_master]. Default: bundled [dmd_master].
#' @param method,max_dist,active_only Passed through to [dmd_price_lookup()].
#' @param price        Which price column to use — `"basic_price"` (default) or
#'   `"nhs_indicative_price"`. Falls back to the other column when the chosen
#'   one is NA for an individual AMPP (a note is added).
#' @param objective    Character vector of one or more objectives: `"cheapest"`,
#'   `"min_items"`, `"most_expensive"`. Pass `"all"` as a shorthand for all
#'   three. Defaults to `c("cheapest", "min_items")`. Each objective produces
#'   one row per preparation group in the result.
#' @param preparation  Optional character — a case-insensitive plain substring
#'   matched against `preparation_group` or `preparation_label` before
#'   returning results. An exact key (e.g. `\"tablet|none|oral\"`) continues to
#'   work, but partial strings such as `\"infusion\"` or `\"oral\"` are also
#'   accepted and will match any group whose key or label contains that text.
#'   Pipe characters in preparation keys are treated literally, not as regex
#'   alternation.
#' @param ingredient  Optional character. Name of a single active ingredient to
#'   dose against (e.g. `"codeine"`). When supplied, candidates are restricted
#'   to products containing that ingredient and the dose is matched against the
#'   ingredient's own strength rather than the whole-product strength. This is
#'   what enables combination products such as co-codamol to be optimised for
#'   one ingredient. Matching is case-insensitive and **word-boundary** based,
#'   so `"codeine"` matches `"Codeine phosphate"` but not `"dihydrocodeine"`;
#'   ingredient names are matched as written in the dm+d (including salt forms).
#'   If the term still resolves to more than one distinct ingredient, all are
#'   used and a warning lists them. Ingredients recorded in non-mass units
#'   (e.g. radioactivity in GBq, electrolytes in mmol) cannot be converted to a
#'   mass dose; such candidates are skipped with a warning. Requires ingredient
#'   (VPI) data: a [dmd_load()] database that includes it, or a rebuilt bundled
#'   [dmd_ingredients]. With no ingredient data, returns no results and warns.
#' @param can_split    Logical. `TRUE` (default) assumes that individual items
#'   (tablets, capsules) can be taken from a part-pack, as is normal in
#'   hospital dispensing. `FALSE` requires whole packs to be dispensed, as
#'   is normal in community pharmacy. Concentration-based preparations
#'   (liquids, inhalers, vials) are treated as one container regardless of this
#'   setting unless `can_split_vials = TRUE`. When `can_split = FALSE`,
#'   reported costs are whole-pack costs rather than pro-rata costs, and a
#'   `"no-pack-splitting"` note is added.
#' @param can_split_vials Logical. If `TRUE`, concentration-based preparations
#'   (vials, ampoules) may be costed as a fraction of a container (vial
#'   sharing). Defaults to `FALSE`, which costs whole containers only.
#' @param over_delivery How much more than the requested dose a combination may
#'   deliver:
#'   \describe{
#'     \item{`"forbid"`}{(default) only combinations that deliver the dose
#'       exactly. A preparation group that cannot hit the dose exactly returns
#'       no row, and a warning names it.}
#'     \item{`"minimise"`}{the smallest achievable over-delivery, with the
#'       requested `objective` applied within it.}
#'     \item{`"allow"`}{the objective decides across every combination that
#'       delivers *at least* the dose; over-delivery is only a tie-break. This
#'       was the behaviour before version 0.6.0.}
#'   }
#'   The policy applies where one "item" is an individually administered dose —
#'   the splittable solid forms — because there over-delivery is extra drug
#'   given to the patient. Whole-pack dispensing (`can_split = FALSE`) and
#'   whole-container preparations (vials and ampoules with
#'   `can_split_vials = FALSE`) are **exempt**: their surplus is wastage in the
#'   pack or the vial, so the cheapest pack/container covering the dose remains
#'   the costing answer and an `"over-delivery-policy-not-applied"` note is
#'   added. Exact delivery from a container is available via
#'   `can_split_vials = TRUE`.
#' @param quiet Logical. `FALSE` (default) warns, once per call, when a
#'   preparation group cannot deliver the dose exactly (and is therefore dropped
#'   under `over_delivery = "forbid"`), and when a returned combination delivers
#'   more than the requested dose — saying whether an exact combination existed.
#'   `TRUE` silences both. Unrelated warnings (unsupported compounds, ingredient
#'   matching) are not affected.
#'
#' @return A [tibble][tibble::tibble] with one row per
#'   `(preparation_group, objective)` combination. See the package vignette for
#'   the column layout. `dose_exact` is `TRUE` when the combination delivers the
#'   requested dose exactly. The `combination` column is a list of tibbles — one
#'   row per AMPP picked, identifying the specific branded product(s) used.
#'   `dose_cost_pence` is the cost (in pence) of supplying the requested dose:
#'   pro-rata item cost when `can_split = TRUE` (hospital), or whole-pack cost
#'   when `can_split = FALSE` (community). In the `combination` tibble, `count`
#'   is the number of discrete dispensing units: individual tablets/capsules/
#'   containers when `can_split = TRUE`, whole packs when `can_split = FALSE`,
#'   or a fractional container when `can_split_vials = TRUE`.
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
#' # Equivalent: pass dose as a single string
#' dmd_dose_optimise("metformin", dose = "900 mg")
#' dmd_dose_optimise("metformin", dose = "0.9 g")   # same dose, different unit
#'
#' # Only modified-release tablets
#' dmd_dose_optimise(
#'   "metformin", dose = 1500, dose_unit = "mg",
#'   preparation = "tablet|modified-release|oral"
#' )
#'
#' # Community pharmacy — whole packs must be dispensed
#' dmd_dose_optimise("metformin", dose = "1500 mg", can_split = FALSE)
#'
#' # Allow over-delivery when no exact combination exists
#' dmd_dose_optimise("metformin", dose = "750 mg", over_delivery = "minimise")
#' }
dmd_dose_optimise <- function(
  query,
  dose,
  dose_unit = NULL,
  db = dmdprices::dmd_master,
  method = c("partial", "exact", "fuzzy"),
  max_dist = 3,
  price = c("basic_price", "nhs_indicative_price"),
  objective = c("cheapest", "min_items"),
  preparation = NULL,
  ingredient = NULL,
  active_only = TRUE,
  can_split = TRUE,
  can_split_vials = FALSE,
  over_delivery = c("forbid", "minimise", "allow"),
  quiet = FALSE
) {
  .validate_ingredient(ingredient)
  # ── Resolve dose / dose_unit ─────────────────────────────────────────────
  if (is.character(dose)) {
    if (length(dose) != 1L) {
      cli::cli_abort(
        "{.arg dose} must be a length-1 string or a single numeric value."
      )
    }
    parsed_dose <- .parse_dose_string(dose)
    if (
      !is.null(dose_unit) && !identical(tolower(dose_unit), parsed_dose$unit)
    ) {
      cli::cli_warn(
        paste0(
          "Parsed unit {.val {parsed_dose$unit}} from the {.arg dose} string ",
          "differs from supplied {.arg dose_unit} {.val {dose_unit}}; ",
          "using the value from {.arg dose}."
        )
      )
    }
    dose <- parsed_dose$value
    dose_unit <- parsed_dose$unit
  } else {
    if (is.null(dose_unit)) {
      dose_unit <- "mg"
    }
    # Normalise aliases so match.arg-style validation still works
    dose_unit <- tolower(dose_unit)
  }

  if (!is.numeric(dose) || length(dose) != 1L || is.na(dose) || dose <= 0) {
    cli::cli_abort("{.arg dose} must be a single positive numeric value.")
  }
  .validate_flag(can_split, "can_split")
  .validate_flag(can_split_vials, "can_split_vials")
  .validate_flag(quiet, "quiet")
  method <- match.arg(method)
  price <- match.arg(price)
  over_delivery <- match.arg(over_delivery)

  if (identical(objective, "all")) {
    objective <- c("cheapest", "min_items", "most_expensive")
  }
  if ("both" %in% objective) {
    lifecycle::deprecate_warn(
      when = "0.6.0",
      what = I('`objective = "both"`'),
      details = 'Use objective = c("cheapest", "min_items") or objective = "all" instead.'
    )
    objective <- unique(c(setdiff(objective, "both"), "cheapest", "min_items"))
  }
  if (length(objective) == 0L) {
    cli::cli_abort(
      '{.arg objective} must contain at least one of {.val cheapest}, {.val min_items}, {.val most_expensive} (or {.val all}).'
    )
  }
  objective <- match.arg(
    objective,
    c("cheapest", "min_items", "most_expensive"),
    several.ok = TRUE
  )

  # Canonicalise requested dose
  dose_canon <- .canonicalise_unit(dose, dose_unit)
  if (is.na(dose_canon$unit)) {
    cli::cli_abort("Unsupported {.arg dose_unit}: {.val {dose_unit}}.")
  }

  # Retrieve (and cache) all dose-independent candidate data.
  enriched <- .dmd_prepare_candidates_memo(
    query = query,
    db = db,
    method = method,
    max_dist = max_dist,
    active_only = active_only,
    price = price
  )
  if (is.null(enriched)) {
    return(.empty_dose_result())
  }
  if (!is.null(ingredient)) {
    enriched <- .apply_ingredient_targeting(enriched, db, ingredient)
  }
  enriched <- .drop_unsupported_compounds(enriched)
  if (nrow(enriched) == 0) {
    return(.empty_dose_result())
  }

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

  # Filter to requested preparation if supplied. Accepts either an exact key
  # (e.g. "solution for infusion|none|intravenous") or any case-insensitive
  # plain substring (e.g. "infusion") matched against preparation_group or
  # preparation_label. tolower() on both sides gives case-insensitivity while
  # fixed = TRUE ensures pipe characters in preparation keys are treated
  # literally, not as regex alternation.
  if (!is.null(preparation)) {
    enriched <- dplyr::filter(
      enriched,
      grepl(
        tolower(preparation),
        tolower(.data$preparation_group),
        fixed = TRUE
      ) |
        grepl(
          tolower(preparation),
          tolower(.data$preparation_label),
          fixed = TRUE
        )
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
  no_exact <- character()
  over_impossible <- character()
  over_available <- character()
  for (g in seq_len(nrow(groups))) {
    sub <- enriched[
      enriched$preparation_group == groups$preparation_group[g],
      ,
      drop = FALSE
    ]
    for (obj in objective) {
      row <- .optimise_group(
        group_df = sub,
        dose_canonical = dose_canon$value,
        dose_unit_canon = dose_canon$unit,
        objective = obj,
        medicine_root = medicine_root,
        preparation_group = groups$preparation_group[g],
        preparation_label = groups$preparation_label[g],
        can_split = can_split,
        can_split_vials = can_split_vials,
        over_delivery = over_delivery
      )
      if (.is_no_exact(row)) {
        no_exact <- c(no_exact, groups$preparation_label[g])
      } else if (!is.null(row)) {
        out[[length(out) + 1L]] <- row
        if (.policy_row(row) && !row$dose_exact) {
          if (.exact_feasible(row)) {
            over_available <- c(over_available, groups$preparation_label[g])
          } else {
            over_impossible <- c(over_impossible, groups$preparation_label[g])
          }
        }
      }
    }
  }

  # One warning per call, however many groups and objectives were dropped, so
  # that an impossible exact dose is never silently indistinguishable from a
  # query that matched nothing.
  .warn_no_exact(no_exact, quiet)
  .warn_over_delivery(over_impossible, over_available, quiet)

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
  result$dose_cost_pence <- if (can_split) {
    result$cost_prorata_pence
  } else {
    result$cost_whole_pack_pence
  }
  .drop_policy_info(result[, names(.empty_dose_result())])
}

# ── Vectorised cost lookup ────────────────────────────────────────────────────

#' Vectorised dose cost lookup
#'
#' A lightweight, vectorised alternative to [dmd_dose_optimise()] designed for
#' costing large tables. Accepts a numeric vector of doses and returns a numeric
#' vector of costs in pence of the same length.
#'
#' Unlike [dmd_dose_optimise()], this function:
#' \itemize{
#'   \item Calls the memoized candidate preparation step **once** regardless of
#'     how many doses are supplied.
#'   \item Applies unit-matching and `preparation` filters **once**.
#'   \item Runs only the DP optimisation per dose element, skipping the full
#'     result-assembly (combination tibble, notes, etc.).
#'   \item Returns a plain `numeric` vector — not a tibble — suitable for use
#'     directly inside [dplyr::mutate()].
#' }
#'
#' When multiple preparation groups match (e.g. no `preparation` filter is
#' supplied), the **minimum cost across all groups** is returned for each dose.
#'
#' @param query,dose_unit,db,method,max_dist,price,preparation,ingredient,active_only,can_split
#'   As in [dmd_dose_optimise()].
#' @param objective Character vector of one or more of `"cheapest"`,
#'   `"min_items"`, `"most_expensive"`, or `"all"`. The cost returned per dose
#'   element is aggregated across preparation groups using each objective's
#'   natural extremum (minimum for `"cheapest"` / `"min_items"`; maximum for
#'   `"most_expensive"`). When multiple objectives are supplied, the
#'   **minimum** of the per-objective aggregates is returned — i.e. the
#'   default `c("cheapest", "min_items")` returns the cheapest achievable cost,
#'   while `"most_expensive"` alone returns the worst-case cost across groups.
#' @param can_split_vials As in [dmd_dose_optimise()]. If `TRUE`, vials and
#'   ampoules are costed as a fraction of a container (vial sharing).
#' @param over_delivery As in [dmd_dose_optimise()]. Defaults to `"forbid"`, so
#'   doses that no combination delivers exactly return `na_value` (with one
#'   warning per call) rather than the cost of an over-delivered dose. Pass
#'   `"minimise"` or `"allow"` to cost over-delivering combinations.
#' @param quiet As in [dmd_dose_optimise()]. Because this function returns bare
#'   numbers, the warnings are the only signal that a cost is for an
#'   over-delivered dose; `TRUE` silences them for bulk costing runs.
#' @param dose A **numeric vector** of dose values in `dose_unit`. `NA`, zero,
#'   or negative elements are returned as `na_value` without error.
#' @param na_value Scalar returned for doses that are `NA`, non-positive, or for
#'   which no solution is found. Default `NA_real_`.
#'
#' @return A `numeric` vector of length `length(dose)` giving the dose cost in
#'   pence. Use `/ 100` for GBP. `NA` (or `na_value`) where no solution exists.
#'
#' @seealso [dmd_dose_optimise()] for the full result tibble with combination
#'   details.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Vectorised costing inside a mutate — no map_dbl needed
#' library(dplyr)
#' treatment_df |>
#'   mutate(
#'     ritux_gbp = dmd_dose_cost(
#'       query       = "rituximab",
#'       dose        = day1_ritux_mg,
#'       dose_unit   = "mg",
#'       objective   = "cheapest",
#'       preparation = "infusion"
#'     ) / 100
#'   )
#' }
dmd_dose_cost <- function(
  query,
  dose,
  dose_unit = NULL,
  db = dmdprices::dmd_master,
  method = c("partial", "exact", "fuzzy"),
  max_dist = 3,
  price = c("basic_price", "nhs_indicative_price"),
  objective = c("cheapest", "min_items"),
  preparation = NULL,
  ingredient = NULL,
  active_only = TRUE,
  can_split = TRUE,
  can_split_vials = FALSE,
  over_delivery = c("forbid", "minimise", "allow"),
  quiet = FALSE,
  na_value = NA_real_
) {
  .validate_ingredient(ingredient)
  .validate_flag(quiet, "quiet")
  method <- match.arg(method)
  price <- match.arg(price)
  over_delivery <- match.arg(over_delivery)

  if (identical(objective, "all")) {
    objective <- c("cheapest", "min_items", "most_expensive")
  }
  if ("both" %in% objective) {
    lifecycle::deprecate_warn(
      when = "0.6.0",
      what = I('`objective = "both"`'),
      details = 'Use objective = c("cheapest", "min_items") or objective = "all" instead.'
    )
    objective <- unique(c(setdiff(objective, "both"), "cheapest", "min_items"))
  }
  if (length(objective) == 0L) {
    cli::cli_abort(
      '{.arg objective} must contain at least one of {.val cheapest}, {.val min_items}, {.val most_expensive} (or {.val all}).'
    )
  }
  objective <- match.arg(
    objective,
    c("cheapest", "min_items", "most_expensive"),
    several.ok = TRUE
  )

  if (!is.numeric(dose)) {
    cli::cli_abort(c(
      "{.arg dose} must be a numeric vector.",
      "i" = paste0(
        "Unlike {.fn dmd_dose_optimise}, {.fn dmd_dose_cost} does not accept ",
        "a dose string. Supply a numeric vector, e.g. {.code dose = 900} ",
        "rather than {.code dose = \"900 mg\"}."
      )
    ))
  }
  if (is.null(dose_unit)) {
    dose_unit <- "mg"
  }
  dose_unit <- tolower(dose_unit)

  # ── Shared candidate preparation (memoized — runs once per argument set) ──
  enriched <- .dmd_prepare_candidates_memo(
    query = query,
    db = db,
    method = method,
    max_dist = max_dist,
    active_only = active_only,
    price = price
  )
  if (is.null(enriched)) {
    return(rep(na_value, length(dose)))
  }
  if (!is.null(ingredient)) {
    enriched <- .apply_ingredient_targeting(enriched, db, ingredient)
  }
  enriched <- .drop_unsupported_compounds(enriched)
  if (nrow(enriched) == 0) {
    return(rep(na_value, length(dose)))
  }

  # ── Static row filters applied once ───────────────────────────────────────
  dose_unit_info <- .canonicalise_unit(1, dose_unit)
  if (is.na(dose_unit_info$unit)) {
    cli::cli_abort("Unsupported {.arg dose_unit}: {.val {dose_unit}}.")
  }
  unit_canon <- dose_unit_info$unit

  keep <- !is.na(enriched$per_item_dose) & !is.na(enriched$strength_unit_canon)
  row_mass_unit <- ifelse(
    grepl("/", enriched$strength_unit_canon),
    sub("/.*", "", enriched$strength_unit_canon),
    enriched$strength_unit_canon
  )
  keep <- keep & (row_mass_unit == unit_canon)
  enriched <- enriched[keep, , drop = FALSE]

  if (!is.null(preparation)) {
    enriched <- enriched[
      grepl(
        tolower(preparation),
        tolower(enriched$preparation_group),
        fixed = TRUE
      ) |
        grepl(
          tolower(preparation),
          tolower(enriched$preparation_label),
          fixed = TRUE
        ),
      ,
      drop = FALSE
    ]
  }

  if (nrow(enriched) == 0) {
    return(rep(na_value, length(dose)))
  }

  medicine_root <- .medicine_root(enriched$drug_stem)
  groups <- unique(enriched[,
    c("preparation_group", "preparation_label"),
    drop = FALSE
  ])

  # ── Per-dose DP loop ───────────────────────────────────────────────────────
  # Aggregation semantics:
  #   - cheapest / min_items: minimum cost across preparation groups
  #   - most_expensive:       maximum cost across preparation groups
  #   - multiple objectives:  per-objective aggregate, then minimum across
  #                           objectives (backward-compatible for the default
  #                           c("cheapest", "min_items"), conservative when
  #                           "most_expensive" is mixed in)
  # Collected across every dose and group, then reported once after the loop —
  # a warning per dose element would be unusable on a costing table.
  no_exact <- character()
  over_impossible <- character()
  over_available <- character()

  costs <- vapply(
    dose,
    function(d) {
      if (is.na(d) || d <= 0) {
        return(na_value)
      }
      dose_canon <- .canonicalise_unit(d, dose_unit)

      per_obj_cost <- vapply(
        objective,
        function(obj) {
          is_max <- identical(obj, "most_expensive")
          best <- if (is_max) -Inf else Inf
          for (g in seq_len(nrow(groups))) {
            sub <- enriched[
              enriched$preparation_group == groups$preparation_group[g],
              ,
              drop = FALSE
            ]
            row <- .optimise_group(
              group_df = sub,
              dose_canonical = dose_canon$value,
              dose_unit_canon = dose_canon$unit,
              objective = obj,
              medicine_root = medicine_root,
              preparation_group = groups$preparation_group[g],
              preparation_label = groups$preparation_label[g],
              can_split = can_split,
              can_split_vials = can_split_vials,
              over_delivery = over_delivery
            )
            if (.is_no_exact(row)) {
              no_exact <<- c(no_exact, groups$preparation_label[g])
              next
            }
            if (is.null(row)) {
              next
            }
            cost <- if (can_split) {
              row$cost_prorata_pence
            } else {
              row$cost_whole_pack_pence
            }
            if (is.na(cost)) {
              next
            }
            # Recorded only once the cost is usable, so the warning describes
            # numbers the caller actually receives.
            if (.policy_row(row) && !row$dose_exact) {
              if (.exact_feasible(row)) {
                over_available <<- c(over_available, groups$preparation_label[g])
              } else {
                over_impossible <<- c(
                  over_impossible,
                  groups$preparation_label[g]
                )
              }
            }
            if (is_max) {
              if (cost > best) best <- cost
            } else {
              if (cost < best) best <- cost
            }
          }
          if (is.infinite(best)) NA_real_ else best
        },
        numeric(1L)
      )

      finite <- per_obj_cost[!is.na(per_obj_cost)]
      if (length(finite) == 0L) na_value else min(finite)
    },
    numeric(1L)
  )

  .warn_no_exact(no_exact, quiet)
  .warn_over_delivery(over_impossible, over_available, quiet)
  costs
}

# ── Cost range lookup ─────────────────────────────────────────────────────────

#' Vectorised dose cost range lookup
#'
#' Returns the **cheapest** and **most expensive** achievable cost for each
#' dose in a single call. A purpose-built alternative to calling
#' [dmd_dose_cost()] twice with different `objective` values, with clearer
#' naming for health-economics range analyses.
#'
#' The candidate preparation step is memoized, so even though this function
#' runs the DP twice internally (once per bound), the expensive price-lookup
#' and parsing work is only performed once per `(query, db, ...)` combination
#' within a session.
#'
#' @inheritParams dmd_dose_cost
#' @param dose A **numeric vector** of dose values in `dose_unit`. `NA`, zero,
#'   or negative elements yield `na_value` in both output columns.
#' @param na_value Scalar returned for doses that are `NA`, non-positive, or
#'   for which no solution is found. Default `NA_real_`.
#'
#' @return A [tibble][tibble::tibble] with `length(dose)` rows and two columns:
#'   \describe{
#'     \item{`lo_pence`}{Cheapest achievable dose cost in pence. Divide by 100
#'       for GBP.}
#'     \item{`hi_pence`}{Most expensive achievable dose cost in pence. Divide
#'       by 100 for GBP.}
#'   }
#'   Both columns are `na_value` when no solution is found.
#'
#' @seealso [dmd_dose_cost()] for a single-objective numeric vector,
#'   [dmd_dose_optimise()] for the full combination tibble with product detail.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Cost range for rituximab doses — divide by 100 for GBP
#' library(dplyr)
#' doses_mg <- c(375, 500, 700)
#' dmd_dose_cost_range(
#'   query       = "rituximab",
#'   dose        = doses_mg,
#'   dose_unit   = "mg",
#'   preparation = "infusion"
#' ) / 100
#'
#' # Use inside mutate() to add lo/hi cost columns to a treatment table
#' treatment_df |>
#'   dplyr::bind_cols(
#'     dmd_dose_cost_range("rituximab", dose = treatment_df$dose_mg) / 100
#'   )
#' }
dmd_dose_cost_range <- function(
  query,
  dose,
  dose_unit = NULL,
  db = dmdprices::dmd_master,
  method = c("partial", "exact", "fuzzy"),
  max_dist = 3,
  price = c("basic_price", "nhs_indicative_price"),
  preparation = NULL,
  ingredient = NULL,
  active_only = TRUE,
  can_split = TRUE,
  can_split_vials = FALSE,
  over_delivery = c("forbid", "minimise", "allow"),
  quiet = FALSE,
  na_value = NA_real_
) {
  .validate_ingredient(ingredient)
  .validate_flag(quiet, "quiet")
  over_delivery <- match.arg(over_delivery)
  shared <- list(
    query = query,
    dose = dose,
    dose_unit = dose_unit,
    db = db,
    method = method,
    max_dist = max_dist,
    price = price,
    preparation = preparation,
    ingredient = ingredient,
    active_only = active_only,
    can_split = can_split,
    can_split_vials = can_split_vials,
    over_delivery = over_delivery,
    quiet = quiet,
    na_value = na_value
  )
  # Both bounds run the same candidate set, so each of these warnings would
  # otherwise be raised twice for one user-visible call.
  seen <- character()
  once <- c(
    "unsupported compound product",
    "No exact-dose combination exists",
    "Delivering more than the requested dose"
  )
  call_cost <- function(obj) {
    withCallingHandlers(
      do.call(dmd_dose_cost, c(shared, list(objective = obj))),
      warning = function(w) {
        msg <- conditionMessage(w)
        hit <- once[vapply(once, grepl, logical(1), msg, fixed = TRUE)]
        if (length(hit) == 0L) {
          return()
        }
        if (hit[[1]] %in% seen) {
          invokeRestart("muffleWarning")
        }
        seen <<- c(seen, hit[[1]])
      }
    )
  }

  lo <- call_cost("cheapest")
  hi <- call_cost("most_expensive")
  tibble::tibble(lo_pence = lo, hi_pence = hi)
}

# Warn once about preparation groups that were dropped because no combination
# delivers the dose exactly under `over_delivery = "forbid"`. `labels` may
# contain repeats (one per objective and, in dmd_dose_cost(), per dose).
.warn_no_exact <- function(labels, quiet = FALSE) {
  labels <- unique(labels[!is.na(labels)])
  if (isTRUE(quiet) || length(labels) == 0L) {
    return(invisible())
  }
  cli::cli_warn(c(
    "No exact-dose combination exists for {length(labels)} preparation group{?s}: {.val {labels}}.",
    "i" = 'Pass {.code over_delivery = "minimise"} or {.code over_delivery = "allow"} to permit over-delivery.'
  ))
  invisible()
}

# Warn once about returned combinations that deliver more than the requested
# dose, so a caller reading only the numbers — `dmd_dose_cost()` has no notes
# column — still learns that the dose was not matched exactly. Only groups the
# over-delivery policy governs reach this; whole packs and whole containers
# report their surplus in `notes` alone. `impossible` names groups with no exact
# combination at all, `available` those where one existed but the objective
# preferred an over-delivering combination (reachable only under "allow").
.warn_over_delivery <- function(impossible, available, quiet = FALSE) {
  impossible <- unique(impossible[!is.na(impossible)])
  available <- unique(available[!is.na(available)])
  n <- length(impossible) + length(available)
  if (isTRUE(quiet) || n == 0L) {
    return(invisible())
  }
  msg <- "Delivering more than the requested dose for {n} preparation group{?s}."
  if (length(impossible) > 0L) {
    msg <- c(
      msg,
      "*" = "{.val {impossible}}: no exact-dose combination exists."
    )
  }
  if (length(available) > 0L) {
    msg <- c(
      msg,
      "*" = "{.val {available}}: an exact-dose combination exists, but the objective preferred an over-delivering one."
    )
  }
  cli::cli_warn(c(
    msg,
    "i" = 'Pass {.code over_delivery = "forbid"} to return only exact-dose combinations, or {.code quiet = TRUE} to silence this.'
  ))
  invisible()
}

# Shared validator for the package's single-logical arguments. Errors are
# attributed to the calling function, not this helper.
.validate_flag <- function(x, arg, call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be a single logical value (TRUE or FALSE).",
      call = call
    )
  }
  invisible()
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
    dose_exact = logical(),
    total_items = numeric(),
    cost_prorata_pence = numeric(),
    cost_whole_pack_pence = numeric(),
    dose_cost_pence = numeric(),
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
  # %g keeps integer counts compact while rendering fractional vial-sharing
  # counts (e.g. 0.5) without sprintf warnings.
  lines <- vapply(
    seq_len(nrow(x)),
    function(i) {
      sprintf("  %g \u00d7 %s", x$count[i], x$ampp_name[i])
    },
    character(1)
  )
  cat("<dmd_dose_combination>\n")
  cat(paste(lines, collapse = "\n"), "\n", sep = "")
  invisible(x)
}
