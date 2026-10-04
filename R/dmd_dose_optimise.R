# ── Memoized candidate preparation ──────────────────────────────────────────

# Convert a character vector of unit labels to canonical unit labels.
.canonicalise_unit_name <- function(unit) {
  vapply(
    unit,
    function(u) .canonicalise_unit(1, u)$unit,
    character(1)
  )
}

# How a row's pack quantity relates to its strength, which decides what one
# optimisation item is:
#   "item"      no denominator: a tablet or capsule, the strength is per item;
#   "pack"      one container: the pack quantity is in the strength's own
#               denominator unit (a 100 ml bottle of a mg/ml liquid, a 60 g
#               tube of a mg/g cream, a 200-dose inhaler of a microgram/dose
#               aerosol), so the item is the whole pack;
#   "container" container count: the pack counts containers (10 pre-filled
#               syringes, 5 ampoules, 30 inhalation capsules, the 10 doses of a
#               multidose vaccine vial), so the item is one denominator
#               quantity;
#   "unknown"   the pack quantity and the strength denominator cannot be
#               reconciled into a number of items: a strength per dose or
#               actuation sold in a pack measured in ml or g (a 13.2 ml
#               nicotine 1mg/dose mouth spray, a 300 g tub of 3.5g/dose
#               granules), whose dose count the dm+d does not record, or a
#               physical denominator with a different physical pack unit (a
#               shampoo stated per g and sold in ml). Such a row gets no
#               per-item dose and is skipped with a warning
#               (.drop_unknown_dose_counts()) rather than costed as if each
#               ml or g were one dose.
.pack_dose_basis <- function(enriched) {
  den <- unname(.canonicalise_unit_name(enriched$denominator_unit))
  pack <- unname(.canonicalise_unit_name(enriched$unit))
  physical <- c("mg", "ml")
  count_like <- c("dose", "actuation")

  is_concentration <- !is.na(enriched$denominator_unit)
  one_container <- is_concentration & !is.na(den) & !is.na(pack) & den == pack
  unknown <- is_concentration &
    !one_container &
    ((den %in% count_like & pack %in% physical) |
      (den %in% physical & pack %in% physical))

  basis <- rep("container", length(is_concentration))
  basis[!is_concentration] <- "item"
  basis[one_container] <- "pack"
  basis[unknown] <- "unknown"
  basis
}

# Total dose represented by one discrete optimisation item: the strength times
# the item quantity, both in canonical units. `strength_canonical` is the
# canonical numerator per one canonical denominator unit whatever its source
# (.canonical_strength()), so the item quantity must be canonical too. For a
# one-container pack ("pack" basis) the item is the whole pack, "60 g" ->
# 60000 mg; for a container-count pack ("container") it is one denominator
# quantity, "500mg/50ml" -> 50 ml; a pack with an "unknown" basis has no
# per-item dose.
.per_item_dose <- function(enriched) {
  out <- enriched$strength_canonical
  is_concentration <- !is.na(enriched$denominator_unit)
  if (!any(is_concentration)) {
    return(out)
  }

  basis <- .pack_dose_basis(enriched)
  multiplier <- .canonicalise_units(
    enriched$denominator_value,
    enriched$denominator_unit
  )$value
  whole_pack <- basis == "pack"
  multiplier[whole_pack] <- .canonicalise_units(
    enriched$pack_size[whole_pack],
    enriched$unit[whole_pack]
  )$value
  multiplier[basis == "unknown"] <- NA_real_

  out[is_concentration] <-
    enriched$strength_canonical[is_concentration] *
      multiplier[is_concentration]
  out
}

# Items per pack and the price of one item, matching .per_item_dose(): a
# solid-form item is one tablet or capsule (pack_size per pack); a
# concentration item is one container — the whole pack when the pack quantity
# is in the strength's denominator unit, otherwise one of the pack_size
# containers the pack holds, so a 10-syringe pack prices each syringe at a
# tenth of the pack. A pack whose container count is unknown (NA pack_size)
# is treated as one container; a pack whose dose count is unknown ("unknown"
# basis) has no items. NA or non-positive counts give an NA price, and an NA
# pack price propagates through the division.
.container_pricing <- function(enriched) {
  basis <- .pack_dose_basis(enriched)
  one_container <- basis == "pack" |
    (basis == "container" & is.na(enriched$pack_size))
  items_per_pack <- ifelse(one_container, 1, enriched$pack_size)
  items_per_pack[basis == "unknown"] <- NA_real_
  safe_items <- items_per_pack
  safe_items[!is.na(safe_items) & safe_items <= 0] <- NA_real_
  enriched$items_per_pack <- items_per_pack
  enriched$per_item_price_pence <- enriched$pack_price_pence / safe_items
  enriched
}

.is_unsupported_compound <- function(enriched) {
  den_unit <- tolower(enriched$denominator_unit)
  num_unit_canon <- .canonicalise_unit_name(enriched$strength_unit)
  den_unit_canon <- .canonicalise_unit_name(den_unit)

  # %in% keeps the exemption FALSE, not NA, for a row with no denominator, so
  # a name-flagged combination gel is skipped with a warning rather than
  # dropped silently through an NA flag.
  topical_mass_concentration <- enriched$form %in% c("cream", "ointment", "gel") &
    den_unit %in% "g"

  same_dose_unit_ratio <- !is.na(den_unit) &
    !is.na(num_unit_canon) &
    !is.na(den_unit_canon) &
    num_unit_canon == den_unit_canon &
    num_unit_canon %in% c("mg", "unit")

  # A bare bracketed strength restating the product's own strength in another
  # unit dimension (eptacog alfa "1mg (50,000unit)") is not a second strength.
  multiple_strengths <- .dose_strength_count(
    enriched$medicine,
    enriched$strength_unit
  ) > 1L

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

# The distinct names in `medicine`: how many (`n`), up to three to show in a
# warning (`shown`), and " and <k> more" text for the rest (`more`, "" when all
# are shown).
.skipped_examples <- function(medicine) {
  medicine <- unique(medicine)
  shown <- utils::head(medicine, 3L)
  more <- length(medicine) - length(shown)
  list(
    n = length(medicine),
    shown = shown,
    more = if (more > 0L) paste0(" and ", more, " more") else ""
  )
}

.drop_unsupported_compounds <- function(enriched) {
  if (!"unsupported_compound" %in% names(enriched)) {
    return(enriched)
  }

  skip <- enriched$unsupported_compound %in% TRUE
  skipped <- enriched$medicine[skip]
  kind <- .pack_kind(skipped)

  n <- sum(is.na(kind))
  if (n > 0L) {
    ex <- .skipped_examples(skipped[is.na(kind)])
    # The first line must keep its wording: dmd_dose_cost_range() and callers
    # de-duplicate this warning by matching "unsupported compound product".
    cli::cli_warn(c(
      "{n} unsupported compound product{?s} skipped during dose optimisation.",
      "x" = "E.g. {.val {ex$shown}}{ex$more}.",
      "i" = 'Pass {.code ingredient = "<name>"} to dose one active ingredient of a combination product (e.g. the codeine in co-codamol).'
    ))
  }

  # A pack of several products (a titration pack, a co-pack) has no single
  # per-item strength, so it gets its own warning without the ingredient
  # advice. dmd_dose_cost_range() de-duplicates it by matching
  # "multi-product pack".
  n_pack <- sum(!is.na(kind))
  if (n_pack > 0L) {
    msg <- "{n_pack} multi-product pack{?s} skipped during dose optimisation."
    multi <- skipped[kind %in% "multi_strength_pack"]
    if (length(multi) > 0L) {
      ex_multi <- .skipped_examples(multi)
      msg <- c(
        msg,
        "x" = "Multi-strength {cli::qty(ex_multi$n)}pack{?s}: {.val {ex_multi$shown}}{ex_multi$more}."
      )
    }
    co <- skipped[kind %in% "co_pack"]
    if (length(co) > 0L) {
      ex_co <- .skipped_examples(co)
      msg <- c(
        msg,
        "x" = "{cli::qty(ex_co$n)}Co-pack{?s} of different products: {.val {ex_co$shown}}{ex_co$more}."
      )
    }
    msg <- c(
      msg,
      "i" = "A pack holding several products has no single per-item strength; cost its products individually."
    )
    cli::cli_warn(msg)
  }

  enriched[!skip, , drop = FALSE]
}

# Drop the rows whose number of doses per pack is unknown (.pack_dose_basis()
# "unknown") with one warning per call that names them, so they are never
# costed as if each ml or g were one dose and a caller reading bare numbers
# can tell the resulting NA from "no product matched". Runs after ingredient
# targeting, which recomputes the basis from the VPI denominator. Not governed
# by `quiet`, like the other data-exclusion warnings; silence it by its class.
# `candidate` marks the rows the call would otherwise have costed: a product
# the preparation filter or the dose unit excludes anyway is dropped silently.
.drop_unknown_dose_counts <- function(enriched, candidate = NULL) {
  if (!"dose_basis" %in% names(enriched)) {
    return(enriched)
  }

  skip <- enriched$dose_basis %in% "unknown"
  named <- if (is.null(candidate)) skip else skip & candidate
  if (any(named)) {
    skipped <- unique(enriched$medicine[named])
    ex <- .skipped_examples(skipped)
    # The first line must keep its wording: dmd_dose_cost_range() de-duplicates
    # this warning by matching "doses per pack is unknown".
    cli::cli_warn(
      c(
        "{ex$n} product{?s} skipped during dose optimisation: the number of doses per pack is unknown.",
        "x" = "E.g. {.val {ex$shown}}{ex$more}.",
        "i" = "The strength is per dose or actuation but the pack is measured in ml or g, or the pack and the strength are in different units, and the dm+d records no dose count for such packs. Cost them as whole packs with {.fn dmd_price_lookup}."
      ),
      class = "dmdprices_warning_unknown_dose_count",
      medicines = skipped
    )
  }

  enriched[!skip, , drop = FALSE]
}

# Rows whose preparation group or label contains `preparation`, matched
# case-insensitively and literally (so a key such as
# "solution for infusion|none|intravenous" is not read as regex alternation);
# every row when no preparation is requested.
.preparation_matches <- function(enriched, preparation) {
  if (is.null(preparation)) {
    return(rep(TRUE, nrow(enriched)))
  }
  needle <- tolower(preparation)
  grepl(needle, tolower(enriched$preparation_group), fixed = TRUE) |
    grepl(needle, tolower(enriched$preparation_label), fixed = TRUE)
}

# Rows whose strength is in the requested dose's canonical unit. A
# concentration ("mg/ml") delivers its numerator, so that is the unit compared.
.dose_unit_matches <- function(enriched, unit_canon) {
  row_mass_unit <- ifelse(
    grepl("/", enriched$strength_unit_canon),
    sub("/.*", "", enriched$strength_unit_canon),
    enriched$strength_unit_canon
  )
  !is.na(row_mass_unit) & row_mass_unit == unit_canon
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
  enriched$dose_basis <- .pack_dose_basis(enriched)
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

  .container_pricing(enriched)
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

# The raw dm+d VPI strength fields that ingredient targeting reads. A table's
# canonical columns are never read, so a table built to any convention targets
# alike, but these fields must be present.
.ingredient_strength_cols <- c(
  "strength_value",
  "strength_unit",
  "denominator_value",
  "denominator_unit"
)

.check_ingredient_columns <- function(
  ingredients,
  arg = "ingredients",
  call = rlang::caller_env()
) {
  fields <- .ingredient_strength_cols
  required <- c("vmp_snomed_code", "ingredient_name", fields)
  missing <- setdiff(required, names(ingredients))
  if (length(missing) > 0L) {
    cli::cli_abort(
      c(
        "{.arg {arg}} lacks the {cli::qty(length(missing))}column{?s} {.val {missing}}.",
        "i" = "Ingredient targeting reads the raw dm+d VPI strength fields {.val {fields}}, as in {.code dmd_ingredients} and the {.code $ingredients} of a {.fn dmd_load} database; the canonical columns are not read."
      ),
      class = "dmdprices_error_ingredient_columns",
      call = call
    )
  }
  invisible(ingredients)
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
      "i" = "Load a dm+d release that includes the VPI extract with {.fn dmd_load}, or pass {.arg ingredients} to {.fn as_dmd_db}."
    ))
    return(enriched[0, , drop = FALSE])
  }
  .check_ingredient_columns(ing_tbl)

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

  vpi <- matches[idx, , drop = FALSE]

  # The VPI strength is taken from its raw fields and brought to the one
  # convention (.canonical_strength()), never from the table's own canonical
  # columns, so an `ingredients` table built to any convention targets alike.
  can <- .canonical_strength(
    vpi$strength_value,
    vpi$strength_unit,
    vpi$denominator_value,
    vpi$denominator_unit
  )

  # The item quantity is the container volume the product name states
  # ("500mg/50ml" vials hold 50 ml) when that is in the VPI denominator's
  # canonical unit; otherwise it is the VPI's own denominator, one stated unit
  # (1 ml, 1 g), as the dm+d records it.
  row_den_canon <- unname(.canonicalise_unit_name(enriched$denominator_unit))
  vpi_den_canon <- unname(.canonicalise_unit_name(vpi$denominator_unit))
  keep_row_den <- !is.na(enriched$denominator_value) &
    !is.na(row_den_canon) &
    !is.na(vpi_den_canon) &
    row_den_canon == vpi_den_canon
  enriched$denominator_value <- ifelse(
    keep_row_den,
    enriched$denominator_value,
    vpi$denominator_value
  )
  enriched$denominator_unit <- ifelse(
    keep_row_den,
    enriched$denominator_unit,
    vpi$denominator_unit
  )
  enriched$strength_value <- vpi$strength_value
  enriched$strength_unit <- vpi$strength_unit
  enriched$strength_canonical <- can$value
  enriched$strength_unit_canon <- can$unit
  enriched$targeted_ingredient <- vpi$ingredient_name

  # The named ingredient gives an unambiguous dose, so these rows are now
  # optimisable even when the product is a combination. The denominator may
  # have changed, so the pack basis is classified again.
  enriched$unsupported_compound <- FALSE
  enriched$dose_basis <- .pack_dose_basis(enriched)
  enriched$per_item_dose <- .per_item_dose(enriched)

  # Some ingredients are recorded in units that cannot be canonicalised to a
  # mass dose: a non-mass numerator (GBq, mmol, vaccine units) or a denominator
  # with no canonical form (per hour for a patch, per square centimetre). Those
  # rows yield an NA per-item dose and are dropped downstream; warn instead of
  # failing silently, naming the unit at fault.
  na_canon <- is.na(enriched$strength_canonical)
  if (any(na_canon)) {
    num_na <- is.na(.canonicalise_units(
      enriched$strength_value,
      enriched$strength_unit
    )$unit)
    bad_num <- sort(unique(stats::na.omit(
      enriched$strength_unit[na_canon & num_na]
    )))
    bad_den <- sort(unique(stats::na.omit(
      enriched$denominator_unit[na_canon & !num_na]
    )))
    msg <- "{sum(na_canon)} candidate{?s} for {.val {ingredient}} {cli::qty(sum(na_canon))}ha{?s/ve} a non-mass strength and cannot be dosed by mass; skipped."
    if (length(bad_num) > 0L) {
      msg <- c(msg, "i" = "Strength unit{?s}: {.val {bad_num}}.")
    }
    if (length(bad_den) > 0L) {
      msg <- c(
        msg,
        "i" = "Strength denominator unit{?s} with no canonical form: {.val {bad_den}}."
      )
    }
    cli::cli_warn(msg)
  }

  .container_pricing(enriched)
}

# Session-level memo for the dose-independent candidate step.
#
# The memo is keyed on the *content* of the table dmd_price_lookup() searches,
# .db_master(db): `$master` for a <dmd_db>, `db` itself otherwise. That table
# is all .dmd_prepare_candidates() reads (`$ingredients` is applied after the
# memo, uncached), so a <dmd_db> and its bare `$master` share entries. Labels
# and timestamps are not used, because they survive the changes that matter:
# the `dmd_release_label` attribute survives subsetting and price edits of
# dmd_master or of dmd_price_lookup() output, and `$loaded_at` survives an
# in-place edit such as `db$master$basic_price <- new_prices` (and two
# databases can share it, or both lack it). Keying on them served one table's
# costs for another (#28, #29, #30).
#
# rlang::hash() of the ~118k-row bundled table costs about 50 ms, so cheap
# identity checks come first. identical() returns at once when both arguments
# are the same object and otherwise stops at the first difference:
#   1. the bundled dmd_master (the default `db`)  -> "bundled";
#   2. the frame step 3 last hashed (the slot)    -> its remembered key;
#   3. any other frame                            -> "content:<hash>",
#                                                    remembered in the slot.
# Step 1 runs only once the bundled table has been loaded from the package's
# lazy data (.bundled_is_loaded()). Until then no caller can hold it, and
# reading it just to compare would load ~45 MB in a session that only uses
# its own tables. A copy loaded separately, e.g. with data(dmd_master)
# before the bundled table is first used, is keyed by content instead.
# Step 2 assumes copy-on-modify: R cannot change an object the slot still
# references without copying it first. data.table's `:=` and set() edit a
# table in place by reference, so a data.table skips the slot and is hashed
# on every call. A by-reference edit of any other frame (only possible from
# compiled code) is not detected. A non-frame, which dmd_price_lookup() then
# rejects, is hashed without evicting the slot.
#
# Before rlang 1.3.0, rlang::hash() serialised an ALTREP column in its
# current state, so a table could hash differently once a deferred column
# (e.g. as.character(1:n)) had been materialised; rlang >= 1.3.0 walks the
# elements (expanding such a column) and hashes it stably. Either way that
# can cost an extra miss, never a stale hit, and step 2 absorbs it for repeat
# calls on the same object. Attributes are part of the key: identical() and
# rlang::hash() both compare them.
#
# The slot holds one reference to the last table hashed by step 3. That is
# usually the caller's own table; at worst it keeps one superseded table alive
# until another table is hashed.
.db_key_memo <- new.env(parent = emptyenv())

.db_cache_key <- function(db) {
  master <- .db_master(db)
  if (.bundled_is_loaded()) {
    bundled <- tryCatch(dmdprices::dmd_master, error = function(e) NULL)
    if (!is.null(bundled) && identical(master, bundled)) {
      return("bundled")
    }
  }
  if (!is.data.frame(master) || inherits(master, "data.table")) {
    return(paste0("content:", rlang::hash(master)))
  }
  if (!is.null(.db_key_memo$key) && identical(master, .db_key_memo$master)) {
    return(.db_key_memo$key)
  }
  key <- paste0("content:", rlang::hash(master))
  .db_key_memo$master <- master
  .db_key_memo$key <- key
  key
}

# TRUE once the bundled dmd_master has been loaded, i.e. its binding in the
# namespace's lazy-data environment is no longer an unforced promise (or the
# environment cannot be inspected, as before this check). Remembered in
# .db_key_memo once TRUE, so the bundled key stays a few identity checks.
# `lazydata` is an argument for the tests.
.bundled_is_loaded <- function(lazydata = NULL) {
  if (isTRUE(.db_key_memo$bundled_loaded)) {
    return(TRUE)
  }
  if (is.null(lazydata)) {
    lazydata <- tryCatch(
      getNamespaceInfo(asNamespace("dmdprices"), "lazydata"),
      error = function(e) NULL
    )
  }
  loaded <- !is.environment(lazydata) ||
    !exists("dmd_master", envir = lazydata, inherits = FALSE) ||
    !rlang::env_binding_are_lazy(lazydata, "dmd_master")
  if (loaded) {
    .db_key_memo$bundled_loaded <- TRUE
  }
  loaded
}

# Empty the candidate memo, the remembered table key and the bundled-loaded
# flag. Internal; the tests call it through .local_fresh_dose_cache() in
# tests/testthat/helper.R.
.forget_dose_cache <- function() {
  memoise::forget(.dmd_prepare_candidates_memo)
  rm(list = ls(.db_key_memo, all.names = TRUE), envir = .db_key_memo)
  invisible(TRUE)
}

# The cache is capped at 1 GiB. The key hashes the arguments as a list, so
# each keeps its type and full precision. A pasted string would write
# `max_dist = 0.3 / 0.1` as "3" and could not tell the string "3" from the
# number 3, yet dmd_price_lookup() filters differently for each of the three.
.dmd_prepare_candidates_memo <- memoise::memoise(
  .dmd_prepare_candidates,
  hash = function(args) {
    rlang::hash(list(
      args$query,
      .db_cache_key(args$db),
      args$method,
      args$max_dist,
      args$active_only,
      args$price
    ))
  },
  cache = cachem::cache_mem(max_size = 1024 * 1024^2)
)

#' Find dose combinations for a clinical dose
#'
#' Given a dose (e.g. 1000 mg), searches the dm+d for products matching `query`
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
#' when its name lists multiple active strengths. A bracketed strength that
#' only restates the product's strength in another unit dimension (eptacog
#' alfa "1mg (50,000unit)") is the same dose and does not count; one in the
#' same dimension, or one naming another substance ("Iohexol 755mg/ml (Iodine
#' 350mg/ml)"), still does. Supply `ingredient` to dose a combination product
#' against one named active ingredient instead. Packs holding several products
#' whose name gives a mass or unit strength for each one — titration packs
#' ("Danicopan 50mg tablets and Danicopan 100mg tablets") and co-packs of
#' different products — have no single per-item strength either; they are
#' skipped with a separate "multi-product pack" warning, and their products
#' should be costed individually. A pack that states a product's strength only
#' as a percentage ("Fluconazole 150mg capsule and Clotrimazole 2% cream") is
#' not recognised and is costed as its first product. A pack whose name gives
#' no strength ("Generic Otezla tablets treatment initiation pack") is dropped
#' like any other product without a parsed strength, with no warning naming it.
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
#'   same shape as [dmd_master]. Default: bundled [dmd_master]. Candidate
#'   searches are cached for the session by the content of this table, so
#'   editing it between calls with ordinary R code is safe (for example
#'   `db$basic_price <- new_prices`, or `db$master$basic_price <- new_prices`
#'   for a `<dmd_db>`). An edit made in place by reference to a table that is
#'   not a data.table (for example with `data.table::set()`) is not detected.
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
#'   (e.g. radioactivity in GBq, electrolytes in mmol), or per a quantity with
#'   no canonical form (per hour, per square centimetre), cannot be converted
#'   to a mass dose; such candidates are skipped with a warning. The
#'   ingredient's strength is applied to the same item the product's own
#'   strength would be: the container volume the name states ("500mg/50ml"
#'   vials hold 50 ml), the whole pack for a single bottle or tube, or
#'   otherwise one unit of the ingredient's stated denominator, which
#'   over-credits a container whose size appears in the name only as a bare
#'   token ("500ml bags" of a strength recorded per litre count as one litre
#'   each; see the limitations in `vignette("dose_optimisation")`). The
#'   ingredient table must carry the raw dm+d strength fields
#'   (`strength_value`, `strength_unit`, `denominator_value`,
#'   `denominator_unit`); its canonical columns are not read. Requires ingredient
#'   (VPI) data: the bundled [dmd_ingredients] (used when `db` is not a
#'   `<dmd_db>`, including the default), the `$ingredients` table of a
#'   [dmd_load()] database built with `f_vmp_VpiType.csv`, or the `ingredients`
#'   argument of [as_dmd_db()]. With no ingredient data, returns no results and
#'   warns.
#' @param can_split    Logical. `TRUE` (default) assumes that individual items
#'   (tablets, capsules) can be taken from a part-pack, as is normal in
#'   hospital dispensing. `FALSE` requires whole packs to be dispensed, as
#'   is normal in community pharmacy. With `can_split = TRUE` a
#'   concentration-based preparation (liquid, inhaler, vial) is still costed
#'   in whole containers unless `can_split_vials = TRUE`; a pack of several
#'   containers (pre-filled syringes, ampoules, vials) is priced per container,
#'   and its whole-pack cost buys as many packs as the containers need. When
#'   `can_split = FALSE`, every preparation is optimised over whole packs — a
#'   pack of several containers is dispensed as whole packs and `total_items`
#'   counts packs — so `"cheapest"` is the cheapest set of whole packs covering
#'   the dose; reported costs are whole-pack costs rather than pro-rata costs,
#'   and a `"no-pack-splitting"` note is added. `can_split_vials = TRUE` takes
#'   precedence for concentration preparations under either setting.
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
#'
#'   The requested dose is never rounded to the strengths. A dose that no
#'   combination of the group's strengths sums to (2.4 mg against 1 mg
#'   tablets) has no exact combination: `"forbid"` returns no row for the
#'   group, and `"minimise"` and `"allow"` return the smallest combination
#'   that delivers at least the dose (3 mg), with `dose_exact = FALSE` and
#'   `over_delivery` showing the surplus. No policy returns less than the
#'   requested dose. Exactness is judged to one part in a billion of the dose
#'   (never finer than a billionth of a milligram or millilitre), so a dose
#'   that is exact in the strengths' unit, such as 0.3 mg from three 0.1 mg
#'   tablets, counts as exact.
#' @param quiet Logical. `FALSE` (default) warns, once per call, when a
#'   preparation group cannot deliver the dose exactly (and is therefore dropped
#'   under `over_delivery = "forbid"`), when a returned combination delivers
#'   more than the requested dose — saying whether an exact combination existed
#'   — and when a group could not be solved for the dose at all (its strengths
#'   cannot be represented at the precision the dose table allows for this
#'   dose, or the dose table would exceed its cell cap) and so returns no row.
#'   `TRUE` silences all three. Unrelated warnings (unsupported compounds,
#'   multi-product packs, unknown dose counts, ingredient matching) are not
#'   affected.
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
#' # Cheapest and minimum-item combinations of immediate-release metformin
#' # tablets for a 1000 mg dose
#' dmd_dose_optimise(
#'   "metformin", dose = 1000, dose_unit = "mg",
#'   preparation = "tablet|none|oral"
#' )
#'
#' # Equivalent: pass dose as a single string, in any supported unit
#' dmd_dose_optimise("metformin", dose = "1000 mg", preparation = "tablet|none|oral")
#' dmd_dose_optimise("metformin", dose = "1 g", preparation = "tablet|none|oral")
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
  enriched <- .drop_unknown_dose_counts(
    enriched,
    candidate = .preparation_matches(enriched, preparation) &
      .dose_unit_matches(enriched, dose_canon$unit)
  )
  if (nrow(enriched) == 0) {
    return(.empty_dose_result())
  }

  # Drop rows we cannot optimise (no strength, no preparation, or mismatched
  # canonical unit vs requested dose).
  keep <- !is.na(enriched$per_item_dose) &
    .dose_unit_matches(enriched, dose_canon$unit)

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
  # preparation_label.
  if (!is.null(preparation)) {
    enriched <- enriched[
      .preparation_matches(enriched, preparation),
      ,
      drop = FALSE
    ]
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
  unresolved_precision <- character()
  unresolved_table <- character()
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
      } else if (.is_unresolved(row)) {
        if (identical(.unresolved_reason(row), "precision")) {
          unresolved_precision <- c(unresolved_precision, groups$preparation_label[g])
        } else {
          unresolved_table <- c(unresolved_table, groups$preparation_label[g])
        }
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
  .warn_unresolved(unresolved_precision, unresolved_table, quiet)

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
#'   warning per call) rather than the cost of an over-delivered dose. The
#'   requested dose is never rounded to the strengths, and no cost is for less
#'   than the dose. Whole containers (`can_split_vials = FALSE`) and whole
#'   packs (`can_split = FALSE`) are exempt from the policy: they are costed as
#'   the cheapest container or pack covering the dose, without a warning.
#'   Pass `"minimise"` or `"allow"` to cost over-delivering combinations.
#' @param quiet As in [dmd_dose_optimise()]. Because this function returns bare
#'   numbers, the warnings are the only signal that a cost is for an
#'   over-delivered dose in the groups the over-delivery policy governs
#'   (whole-container and whole-pack groups are not warned about);
#'   `TRUE` silences them for bulk costing runs.
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
  dose_unit_info <- .canonicalise_unit(1, dose_unit)
  if (is.na(dose_unit_info$unit)) {
    cli::cli_abort("Unsupported {.arg dose_unit}: {.val {dose_unit}}.")
  }
  unit_canon <- dose_unit_info$unit

  enriched <- .drop_unsupported_compounds(enriched)
  enriched <- .drop_unknown_dose_counts(
    enriched,
    candidate = .preparation_matches(enriched, preparation) &
      .dose_unit_matches(enriched, unit_canon)
  )
  if (nrow(enriched) == 0) {
    return(rep(na_value, length(dose)))
  }

  # ── Static row filters applied once ───────────────────────────────────────
  keep <- !is.na(enriched$per_item_dose) &
    .dose_unit_matches(enriched, unit_canon)
  enriched <- enriched[keep, , drop = FALSE]

  if (!is.null(preparation)) {
    enriched <- enriched[
      .preparation_matches(enriched, preparation),
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
  unresolved_precision <- character()
  unresolved_table <- character()

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
            if (.is_unresolved(row)) {
              if (identical(.unresolved_reason(row), "precision")) {
                unresolved_precision <<- c(
                  unresolved_precision,
                  groups$preparation_label[g]
                )
              } else {
                unresolved_table <<- c(unresolved_table, groups$preparation_label[g])
              }
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
  .warn_unresolved(unresolved_precision, unresolved_table, quiet)
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
    "multi-product pack",
    "doses per pack is unknown",
    "No exact-dose combination exists",
    "Delivering more than the requested dose",
    "could not be resolved"
  )
  call_cost <- function(obj) {
    withCallingHandlers(
      do.call(dmd_dose_cost, c(shared, list(objective = obj))),
      warning = function(w) {
        # cli wraps conditionMessage() to the console width, which can break a
        # pattern across lines; collapse the whitespace before matching.
        msg <- gsub("[[:space:]]+", " ", conditionMessage(w))
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
# A dose off the strengths' grid has no exact combination, so an
# over-delivering row for it is `impossible`.
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

# Warn once about preparation groups the solver could not run for the dose:
# `precision` names groups whose strengths are not whole numbers of grid units
# at the integer scale the dose table allows for the dose, `table` those whose
# dose table would exceed the cell cap. Both return no row, so a caller
# reading bare numbers would otherwise see an NA that is indistinguishable
# from "no product matched". `labels` may repeat (one per objective and, in
# dmd_dose_cost(), per dose).
.warn_unresolved <- function(precision, table, quiet = FALSE) {
  precision <- unique(precision[!is.na(precision)])
  # A group can hit both guards across a dose vector; name it once, under the
  # reason met first.
  table <- setdiff(unique(table[!is.na(table)]), precision)
  n <- length(precision) + length(table)
  if (isTRUE(quiet) || n == 0L) {
    return(invisible())
  }
  msg <- "The requested dose could not be resolved for {n} preparation group{?s}; {?it returns/they return} no row."
  if (length(precision) > 0L) {
    msg <- c(
      msg,
      "*" = "{.val {precision}}: the strengths cannot be represented at the precision the group's dose table allows for this dose."
    )
  }
  if (length(table) > 0L) {
    msg <- c(
      msg,
      "*" = "{.val {table}}: the dose table would exceed 5,000,000 cells."
    )
  }
  cli::cli_warn(c(
    msg,
    "i" = "Pass {.code quiet = TRUE} to silence this."
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
