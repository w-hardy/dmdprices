# Strength parsing and preparation classification for VMP names.
# See dmd_dose_optimise() for the user-facing consumer.

# ── Unit canonicalisation ─────────────────────────────────────────────────────

# Canonical bases for each input unit. Mass units canonicalise to "mg",
# volume to "ml", biological activity to "unit".
.unit_table <- tibble::tribble(
  ~input       , ~canonical  , ~factor  ,
  "g"          , "mg"        ,     1000 ,
  "mg"         , "mg"        ,        1 ,
  "microgram"  , "mg"        , 1 / 1000 ,
  "micrograms" , "mg"        , 1 / 1000 ,
  "mcg"        , "mg"        , 1 / 1000 ,
  "ng"         , "mg"        , 1 / 1e6  ,
  "nanogram"   , "mg"        , 1 / 1e6  ,
  "nanograms"  , "mg"        , 1 / 1e6  ,
  "ml"         , "ml"        ,        1 ,
  "litre"      , "ml"        ,     1000 ,
  "litres"     , "ml"        ,     1000 ,
  "l"          , "ml"        ,     1000 ,
  "unit"       , "unit"      ,        1 ,
  "units"      , "unit"      ,        1 ,
  "u"          , "unit"      ,        1 ,
  # Count-like denominators for concentrations expressed per-dose or
  # per-actuation. Canonicalised to themselves so strength_unit_canon
  # keeps a readable label like "mg/dose" or "mg/actuation".
  "dose"       , "dose"      ,        1 ,
  "doses"      , "dose"      ,        1 ,
  "actuation"  , "actuation" ,        1 ,
  "actuations" , "actuation" ,        1
)

.canonicalise_unit <- function(value, unit) {
  if (is.null(unit) || is.na(unit)) {
    return(list(value = NA_real_, unit = NA_character_))
  }
  u <- tolower(unit)
  row <- .unit_table[.unit_table$input == u, , drop = FALSE]
  if (nrow(row) == 0) {
    return(list(value = NA_real_, unit = NA_character_))
  }
  list(
    value = value * row$factor[1],
    unit = row$canonical[1]
  )
}

# ── Strength parser ───────────────────────────────────────────────────────────

# Regex captures an optional strength token of the form
# `<amt><unit>` optionally followed by `/<den_amt><den_unit>`.
# Examples matched: "500mg", "25 microgram", "2.5mg/5ml", "100units/ml",
# "100micrograms/dose".
.strength_regex <- paste0(
  "(?i)",
  "(?<drug>.+?)",
  "\\s+",
  "(?<amt>\\d+(?:\\.\\d+)?)",
  "\\s*",
  "(?<unit>micrograms?|mcg|mg|ng|nanograms?|g|units?|u)",
  "(?:",
  "\\s*/\\s*",
  "(?<den_amt>\\d+(?:\\.\\d+)?)?",
  "\\s*",
  "(?<den_unit>ml|g|mg|dose|doses|actuation|actuations)",
  ")?",
  "\\s+",
  "(?<tail>.*)$"
)

# ── Combination (multi-ingredient) products ───────────────────────────────────

# Mass / biological-activity units that a true ingredient strength can take.
# A combination product (e.g. co-codamol "8mg/500mg") lists two or more of
# these joined by "/". A concentration (e.g. "10mg/5ml") instead has a
# volume / dose / count denominator and is NOT a combination.
#
# Standalone grams ("g") are deliberately excluded: a "<mass>mg/<n>g" pattern
# (e.g. "250mg/5g vaginal cream") is a mass-per-gram (w/w) concentration, not a
# two-ingredient combination. Such names fall through to the single-strength
# parser, which captures the per-gram denominator.
.mass_unit_alt <- "micrograms?|mcg|mg|ng|nanograms?|units?|u"

# Matches names whose strength is a run of two or more mass tokens joined by
# "/", optionally followed by a single volume/dose denominator that applies to
# the whole combination (e.g. co-trimoxazole "80mg/400mg/5ml suspension").
# Capture groups: 1 drug, 2 block, 3 den_amt, 4 den_unit, 5 tail.
.combination_regex <- paste0(
  "(?i)^",
  "(.+?)\\s+",
  "(",
  "\\d+(?:\\.\\d+)?\\s*(?:", .mass_unit_alt, ")",
  "(?:\\s*/\\s*\\d+(?:\\.\\d+)?\\s*(?:", .mass_unit_alt, "))+",
  ")",
  "(?:\\s*/\\s*(\\d+(?:\\.\\d+)?)?\\s*(ml|litres?|l|doses?|actuations?))?",
  "(?:\\s+(.*))?$"
)

# Zero-row template for the per-ingredient `components` list-column.
.empty_components <- function() {
  tibble::tibble(
    value = numeric(),
    unit = character(),
    canonical_value = numeric(),
    canonical_unit = character()
  )
}

# Build a one-row strength tibble with a uniform schema (used by every branch
# of .parse_strength_one() so combination and non-combination rows bind cleanly).
.strength_row <- function(
  drug_stem,
  strength_value,
  strength_unit,
  denominator_value,
  denominator_unit,
  tail,
  strength_canonical,
  strength_unit_canon,
  is_combination = FALSE,
  components = NULL
) {
  if (is.null(components)) {
    components <- .empty_components()
  }
  tibble::tibble(
    drug_stem = drug_stem,
    strength_value = strength_value,
    strength_unit = strength_unit,
    denominator_value = denominator_value,
    denominator_unit = denominator_unit,
    tail = tail,
    strength_canonical = strength_canonical,
    strength_unit_canon = strength_unit_canon,
    is_combination = is_combination,
    n_components = nrow(components),
    components = list(components)
  )
}

# Parse a single "<amt><unit>" mass token into a one-row component tibble,
# or NULL if it is not a recognised mass token.
.parse_one_component <- function(token) {
  m <- regmatches(
    token,
    regexec(
      paste0("(?i)^\\s*(\\d+(?:\\.\\d+)?)\\s*(", .mass_unit_alt, ")\\s*$"),
      token,
      perl = TRUE
    )
  )[[1]]
  if (length(m) == 0) {
    return(NULL)
  }
  amt <- as.numeric(m[2])
  unit <- tolower(m[3])
  can <- .canonicalise_unit(amt, unit)
  tibble::tibble(
    value = amt,
    unit = unit,
    canonical_value = can$value,
    canonical_unit = can$unit
  )
}

# Returns a strength row for a combination product, or NULL if `name` is not a
# combination (so the caller falls back to single-strength parsing).
.parse_combination_one <- function(name) {
  m <- regmatches(name, regexec(.combination_regex, name, perl = TRUE))[[1]]
  if (length(m) == 0) {
    return(NULL)
  }

  drug <- m[2]
  block <- m[3]
  den_amt <- suppressWarnings(as.numeric(m[4]))
  den_unit <- m[5]
  tail <- m[6]

  tokens <- trimws(strsplit(block, "/", fixed = TRUE)[[1]])
  comps <- lapply(tokens, .parse_one_component)
  comps <- comps[!vapply(comps, is.null, logical(1))]
  if (length(comps) < 2L) {
    return(NULL)
  }
  components <- dplyr::bind_rows(comps)

  if (is.na(den_unit) || !nzchar(den_unit)) {
    den_unit <- NA_character_
    den_amt <- NA_real_
  } else {
    den_unit <- tolower(den_unit)
    if (is.na(den_amt)) {
      den_amt <- 1
    }
  }

  .strength_row(
    drug_stem = trimws(drug),
    strength_value = NA_real_,
    strength_unit = NA_character_,
    denominator_value = den_amt,
    denominator_unit = den_unit,
    tail = if (is.na(tail)) NA_character_ else trimws(tail),
    strength_canonical = NA_real_,
    strength_unit_canon = NA_character_,
    is_combination = TRUE,
    components = components
  )
}

# Strength token within one ingredient segment: `<amt><unit>` optionally
# followed by a `/<den_amt><den_unit>` concentration denominator.
.segment_strength_regex <- paste0(
  "(?i)(\\d+(?:\\.\\d+)?)\\s*(",
  .mass_unit_alt,
  ")(?:\\s*/\\s*(\\d+(?:\\.\\d+)?)?\\s*(ml|litres?|l|doses?|actuations?|g))?"
)

# Returns a strength row for a multi-ingredient product that lists each
# ingredient with its own concentration, separated by spaced slashes, e.g.
# "Fluticasone propionate 100micrograms/dose / Salmeterol 12.75micrograms/dose
# dry powder inhaler". Returns NULL if `name` is not of this form.
#
# This differs from .parse_combination_one(), which handles same-denominator
# mass runs joined by bare slashes (e.g. co-codamol "8mg/500mg").
.parse_concentration_combination_one <- function(name) {
  segments <- strsplit(name, "\\s+/\\s+", perl = TRUE)[[1]]
  if (length(segments) < 2L) {
    return(NULL)
  }

  comps <- list()
  den_unit <- NA_character_
  den_amt <- NA_real_
  drug_stem <- NA_character_
  tail <- NA_character_

  for (k in seq_along(segments)) {
    seg <- segments[k]
    pos <- regexpr(.segment_strength_regex, seg, perl = TRUE)
    if (pos == -1L) {
      next
    }
    m <- regmatches(seg, regexec(.segment_strength_regex, seg, perl = TRUE))[[1]]
    amt <- suppressWarnings(as.numeric(m[2]))
    unit <- tolower(m[3])
    can <- .canonicalise_unit(amt, unit)
    comps[[length(comps) + 1L]] <- tibble::tibble(
      value = amt,
      unit = unit,
      canonical_value = can$value,
      canonical_unit = can$unit
    )

    # Capture the (shared) per-dose / per-volume denominator from the first
    # segment that carries one.
    if (is.na(den_unit) && !is.na(m[5]) && nzchar(m[5])) {
      den_unit <- tolower(m[5])
      den_amt <- if (is.na(m[4]) || !nzchar(m[4])) 1 else as.numeric(m[4])
    }

    if (k == 1L) {
      drug_stem <- trimws(substr(seg, 1L, pos - 1L))
    }
    after <- trimws(substr(seg, pos + attr(pos, "match.length"), nchar(seg)))
    if (nzchar(after)) {
      tail <- after
    }
  }

  if (length(comps) < 2L) {
    return(NULL)
  }

  .strength_row(
    drug_stem = if (is.na(drug_stem) || !nzchar(drug_stem)) {
      NA_character_
    } else {
      drug_stem
    },
    strength_value = NA_real_,
    strength_unit = NA_character_,
    denominator_value = den_amt,
    denominator_unit = den_unit,
    tail = tail,
    strength_canonical = NA_real_,
    strength_unit_canon = NA_character_,
    is_combination = TRUE,
    components = dplyr::bind_rows(comps)
  )
}

.parse_strength_one <- function(name) {
  if (is.na(name) || !nzchar(name)) {
    return(.strength_row(
      drug_stem = NA_character_,
      strength_value = NA_real_,
      strength_unit = NA_character_,
      denominator_value = NA_real_,
      denominator_unit = NA_character_,
      tail = NA_character_,
      strength_canonical = NA_real_,
      strength_unit_canon = NA_character_
    ))
  }

  comb <- .parse_combination_one(name)
  if (!is.null(comb)) {
    return(comb)
  }

  conc_comb <- .parse_concentration_combination_one(name)
  if (!is.null(conc_comb)) {
    return(conc_comb)
  }

  m <- regmatches(name, regexec(.strength_regex, name, perl = TRUE))[[1]]
  if (length(m) == 0) {
    return(.strength_row(
      drug_stem = name,
      strength_value = NA_real_,
      strength_unit = NA_character_,
      denominator_value = NA_real_,
      denominator_unit = NA_character_,
      tail = NA_character_,
      strength_canonical = NA_real_,
      strength_unit_canon = NA_character_
    ))
  }

  drug <- unname(m[2])
  amt <- suppressWarnings(as.numeric(m[3]))
  unit <- unname(m[4])
  den_amt <- suppressWarnings(as.numeric(m[5]))
  den_unit <- unname(m[6])
  tail <- unname(m[7])

  if (is.na(den_unit) || !nzchar(den_unit)) {
    den_unit <- NA_character_
    den_amt <- NA_real_
  } else if (is.na(den_amt)) {
    # e.g. "100units/ml" with implicit denominator of 1
    den_amt <- 1
  }

  can_num <- .canonicalise_unit(amt, unit)
  if (!is.na(den_unit)) {
    can_den <- .canonicalise_unit(den_amt, den_unit)
    strength_canonical <- can_num$value / can_den$value
    strength_unit_canon <- paste0(can_num$unit, "/", can_den$unit)
  } else {
    strength_canonical <- can_num$value
    strength_unit_canon <- can_num$unit
  }

  component <- if (is.na(amt)) {
    .empty_components()
  } else {
    tibble::tibble(
      value = amt,
      unit = tolower(unit),
      canonical_value = can_num$value,
      canonical_unit = can_num$unit
    )
  }

  .strength_row(
    drug_stem = trimws(drug),
    strength_value = amt,
    strength_unit = tolower(unit),
    denominator_value = den_amt,
    denominator_unit = if (is.na(den_unit)) {
      NA_character_
    } else {
      tolower(den_unit)
    },
    tail = trimws(tail),
    strength_canonical = strength_canonical,
    strength_unit_canon = strength_unit_canon,
    is_combination = FALSE,
    components = component
  )
}

# ── Dose-string parser ────────────────────────────────────────────────────────

# Parses a user-supplied dose string such as "250 mg", "250mg", or "0.25 g"
# into a list(value = <numeric>, unit = <character>).
# Accepts all units recognised by .canonicalise_unit().
.parse_dose_string <- function(x) {
  x <- trimws(x)
  unit_pat <- paste0(
    "micrograms?|mcg|mg|ng|nanograms?|g|ml|",
    "litres?|l\\b|units?|u\\b|",
    "doses?|actuations?"
  )
  m <- regmatches(
    x,
    regexec(
      paste0("^(\\d+(?:\\.\\d+)?)\\s*(", unit_pat, ")$"),
      x,
      perl = TRUE,
      ignore.case = TRUE
    )
  )[[1]]
  if (length(m) == 0) {
    cli::cli_abort(
      c(
        "{.arg dose} could not be parsed as a dose string: {.val {x}}.",
        "i" = paste0(
          "Expected a number followed by a unit, ",
          "e.g. {.val {\"250 mg\"}}, {.val {\"0.25 g\"}}, ",
          "{.val {\"500mcg\"}}."
        )
      )
    )
  }
  list(value = as.numeric(m[2]), unit = tolower(m[3]))
}

#' Parse a dm+d VMP name into drug stem, strength, and remainder
#'
#' Extracts a numeric strength and optional per-denominator concentration
#' (e.g. `mg/ml`, `microgram/dose`) from a VMP name. Also returns a canonical
#' form (mass in mg, volume in ml, biological activity as `"unit"`).
#'
#' Combination (multi-ingredient) products such as co-codamol
#' (`"8mg/500mg"`) or co-careldopa (`"25mg/100mg"`) are detected and their
#' individual ingredient strengths returned in the `components` list-column,
#' rather than being misread as a single mass-per-mass concentration. A
#' trailing volume/dose denominator on a combination liquid (e.g. co-trimoxazole
#' `"80mg/400mg/5ml"`) is captured in `denominator_value` / `denominator_unit`.
#'
#' @param name Character vector of VMP names.
#' @return A [tibble][tibble::tibble] with one row per input, with columns:
#'   `drug_stem`, `strength_value`, `strength_unit`, `denominator_value`,
#'   `denominator_unit`, `tail`, `strength_canonical`, `strength_unit_canon`,
#'   `is_combination` (logical), `n_components` (integer count of parsed
#'   ingredients), and `components` (a list-column of per-ingredient tibbles
#'   with `value`, `unit`, `canonical_value`, and `canonical_unit`). For
#'   combination products `strength_value` / `strength_canonical` are `NA`
#'   because a single scalar strength is not meaningful; use `components`.
#'
#' @export
#'
#' @examples
#' dmd_parse_strength(c(
#'   "Metformin 500mg tablets",
#'   "Morphine 10mg/5ml oral solution",
#'   "Salbutamol 100micrograms/dose inhaler CFC free"
#' ))
#'
#' # Combination products expose per-ingredient strengths
#' res <- dmd_parse_strength("Co-codamol 8mg/500mg tablets")
#' res$is_combination
#' res$components[[1]]
dmd_parse_strength <- function(name) {
  if (!is.character(name)) {
    cli::cli_abort("{.arg name} must be a character vector.")
  }
  out <- lapply(name, .parse_strength_one)
  dplyr::bind_rows(out)
}

# ── Preparation classifier ────────────────────────────────────────────────────

# Each entry: pattern (case-insensitive regex) → classification token.
# Order matters — more specific forms first.
.form_patterns <- list(
  list(
    "modified-release capsule",
    "modified-release capsule|m/?r capsule|prolonged-release capsule|sustained-release capsule"
  ),
  list(
    "modified-release tablet",
    "modified-release tablet|m/?r tablet|prolonged-release tablet|sustained-release tablet"
  ),
  list(
    "gastro-resistant tablet",
    "gastro-?resistant tablet|enteric-?coated tablet"
  ),
  list(
    "gastro-resistant capsule",
    "gastro-?resistant capsule|enteric-?coated capsule"
  ),
  list("orodispersible tablet", "orodispersible tablet"),
  list("chewable tablet", "chewable tablet"),
  list("effervescent tablet", "effervescent tablet"),
  list("sublingual tablet", "sublingual tablet"),
  list("dispersible tablet", "dispersible tablet"),
  list("soluble tablet", "soluble tablet"),
  list("tablet", "\\btablets?\\b"),
  list("capsule", "\\bcapsules?\\b"),
  list("oral solution", "oral solution|oral liquid"),
  list("oral suspension", "oral suspension"),
  list("oral drops", "oral drops"),
  list("syrup", "\\bsyrup\\b"),
  list("elixir", "\\belixir\\b"),
  list("granules", "\\bgranules\\b"),
  list("sachet", "\\bsachets?\\b|powder for .* sachet"),
  list("suppository", "\\bsupposit"),
  list("pessary", "\\bpessar"),
  list("enema", "\\benema"),
  list("solution for infusion", "solution for infusion|infusion"),
  list("solution for injection", "solution for injection|injection"),
  list("powder for solution", "powder for (?:solution|reconstitution)"),
  list("patch", "\\bpatch"),
  list("inhaler", "inhaler|inhalation"),
  list("nebuliser liquid", "nebuliser liquid|nebuliser solution"),
  list("cream", "\\bcream\\b"),
  list("ointment", "\\bointment\\b"),
  list("gel", "\\bgel\\b"),
  list("eye drops", "eye drops"),
  list("ear drops", "ear drops"),
  list("nasal drops", "nasal drops"),
  list("nasal spray", "nasal spray"),
  list("spray", "\\bspray\\b"),
  list("pre-filled pen", "pre-?filled pen"),
  list("pre-filled syringe", "pre-?filled syringe"),
  list("pen", "\\bpen\\b"),
  list("lozenge", "\\blozenges?\\b"),
  list("ampoule", "\\bampoules?\\b"),
  list("vial", "\\bvials?\\b")
)

.modifier_patterns <- list(
  list(
    "modified-release",
    "modified-release|m/?r\\b|prolonged-release|sustained-release"
  ),
  list("gastro-resistant", "gastro-?resistant|enteric-?coated"),
  list("orodispersible", "orodispersible"),
  list("chewable", "chewable"),
  list("effervescent", "effervescent"),
  list("sublingual", "sublingual"),
  list("dispersible", "dispersible"),
  list("soluble", "soluble")
)

.route_patterns <- list(
  list("intravenous", "intravenous|iv infusion|for infusion"),
  list("subcutaneous", "subcutaneous|sub-cutaneous"),
  list("intramuscular", "intramuscular"),
  list("rectal", "suppositor|enema|rectal"),
  list("vaginal", "pessar|vaginal"),
  list("topical", "\\bcream\\b|\\bointment\\b|\\bgel\\b|\\bpatch"),
  list("inhaled", "inhaler|inhalation|nebuliser"),
  list("intranasal", "nasal"),
  list("ophthalmic", "eye drops"),
  list("otic", "ear drops"),
  list(
    "oral",
    "oral solution|oral suspension|oral liquid|oral drops|\\bsyrup\\b|\\belixir\\b|\\btablet|\\bcapsule|\\bgranules|\\bsachet|\\blozenge|chewable|orodispersible|sublingual|soluble|dispersible"
  ),
  list("injection", "injection|ampoule|vial|pre-?filled")
)

.match_first <- function(text, patterns, default = "unclassified") {
  if (is.na(text) || !nzchar(text)) {
    return(default)
  }
  for (p in patterns) {
    if (stringr::str_detect(text, stringr::regex(p[[2]], ignore_case = TRUE))) {
      return(p[[1]])
    }
  }
  default
}

# Returns a tibble with form / modifier / route / group-key columns for each
# input string (typically the `tail` from .parse_strength_one()).
.classify_preparation <- function(tail) {
  if (length(tail) == 0) {
    return(tibble::tibble(
      form = character(),
      modifier = character(),
      route = character(),
      preparation_group = character(),
      preparation_label = character()
    ))
  }
  form <- unname(vapply(
    tail,
    .match_first,
    character(1),
    patterns = .form_patterns
  ))
  modifier <- unname(vapply(
    tail,
    .match_first,
    character(1),
    patterns = .modifier_patterns,
    default = "none"
  ))
  route <- unname(vapply(
    tail,
    .match_first,
    character(1),
    patterns = .route_patterns
  ))

  group <- paste(form, modifier, route, sep = "|")
  label <- ifelse(
    modifier == "none",
    paste0(form, " (", route, ")"),
    paste0(modifier, " ", form, " (", route, ")")
  )

  tibble::tibble(
    form = form,
    modifier = modifier,
    route = route,
    preparation_group = group,
    preparation_label = label
  )
}
