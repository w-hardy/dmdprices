# Strength parsing and preparation classification for VMP names.
# See dmd_dose_optimise() for the user-facing consumer.

# ── Unit canonicalisation ─────────────────────────────────────────────────────

# Canonical bases for each input unit. Mass units canonicalise to "mg",
# volume to "ml", biological activity to "unit".
.unit_table <- tibble::tribble(
  ~input,        ~canonical, ~factor,
  "g",           "mg",       1000,
  "mg",          "mg",       1,
  "microgram",   "mg",       1 / 1000,
  "micrograms",  "mg",       1 / 1000,
  "mcg",         "mg",       1 / 1000,
  "ng",          "mg",       1 / 1e6,
  "nanogram",    "mg",       1 / 1e6,
  "nanograms",   "mg",       1 / 1e6,
  "ml",          "ml",       1,
  "litre",       "ml",       1000,
  "litres",      "ml",       1000,
  "l",           "ml",       1000,
  "unit",        "unit",     1,
  "units",       "unit",     1,
  "u",           "unit",     1,
  # Count-like denominators for concentrations expressed per-dose or
  # per-actuation. Canonicalised to themselves so strength_unit_canon
  # keeps a readable label like "mg/dose" or "mg/actuation".
  "dose",        "dose",     1,
  "doses",       "dose",     1,
  "actuation",   "actuation",1,
  "actuations",  "actuation",1
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
    unit  = row$canonical[1]
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

.parse_strength_one <- function(name) {
  if (is.na(name) || !nzchar(name)) {
    return(tibble::tibble(
      drug_stem            = NA_character_,
      strength_value       = NA_real_,
      strength_unit        = NA_character_,
      denominator_value    = NA_real_,
      denominator_unit     = NA_character_,
      tail                 = NA_character_,
      strength_canonical   = NA_real_,
      strength_unit_canon  = NA_character_
    ))
  }

  m <- regmatches(name, regexec(.strength_regex, name, perl = TRUE))[[1]]
  if (length(m) == 0) {
    return(tibble::tibble(
      drug_stem            = name,
      strength_value       = NA_real_,
      strength_unit        = NA_character_,
      denominator_value    = NA_real_,
      denominator_unit     = NA_character_,
      tail                 = NA_character_,
      strength_canonical   = NA_real_,
      strength_unit_canon  = NA_character_
    ))
  }

  drug    <- unname(m[2])
  amt     <- suppressWarnings(as.numeric(m[3]))
  unit    <- unname(m[4])
  den_amt <- suppressWarnings(as.numeric(m[5]))
  den_unit <- unname(m[6])
  tail    <- unname(m[7])

  if (is.na(den_unit) || !nzchar(den_unit)) {
    den_unit <- NA_character_
    den_amt  <- NA_real_
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

  tibble::tibble(
    drug_stem            = trimws(drug),
    strength_value       = amt,
    strength_unit        = tolower(unit),
    denominator_value    = den_amt,
    denominator_unit     = if (is.na(den_unit)) NA_character_ else tolower(den_unit),
    tail                 = trimws(tail),
    strength_canonical   = strength_canonical,
    strength_unit_canon  = strength_unit_canon
  )
}

#' Parse a dm+d VMP name into drug stem, strength, and remainder
#'
#' Extracts a numeric strength and optional per-denominator concentration
#' (e.g. `mg/ml`, `microgram/dose`) from a VMP name. Also returns a canonical
#' form (mass in mg, volume in ml, biological activity as `"unit"`).
#'
#' @param name Character vector of VMP names.
#' @return A [tibble][tibble::tibble] with one row per input, with columns:
#'   `drug_stem`, `strength_value`, `strength_unit`, `denominator_value`,
#'   `denominator_unit`, `tail`, `strength_canonical`, `strength_unit_canon`.
#'
#' @export
#'
#' @examples
#' dmd_parse_strength(c(
#'   "Metformin 500mg tablets",
#'   "Morphine 10mg/5ml oral solution",
#'   "Salbutamol 100micrograms/dose inhaler CFC free"
#' ))
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
  list("modified-release capsule", "modified-release capsule|m/?r capsule|prolonged-release capsule|sustained-release capsule"),
  list("modified-release tablet",  "modified-release tablet|m/?r tablet|prolonged-release tablet|sustained-release tablet"),
  list("gastro-resistant tablet",  "gastro-?resistant tablet|enteric-?coated tablet"),
  list("gastro-resistant capsule", "gastro-?resistant capsule|enteric-?coated capsule"),
  list("orodispersible tablet",    "orodispersible tablet"),
  list("chewable tablet",          "chewable tablet"),
  list("effervescent tablet",      "effervescent tablet"),
  list("sublingual tablet",        "sublingual tablet"),
  list("dispersible tablet",       "dispersible tablet"),
  list("soluble tablet",           "soluble tablet"),
  list("tablet",                   "\\btablets?\\b"),
  list("capsule",                  "\\bcapsules?\\b"),
  list("oral solution",            "oral solution|oral liquid"),
  list("oral suspension",          "oral suspension"),
  list("oral drops",               "oral drops"),
  list("syrup",                    "\\bsyrup\\b"),
  list("elixir",                   "\\belixir\\b"),
  list("granules",                 "\\bgranules\\b"),
  list("sachet",                   "\\bsachets?\\b|powder for .* sachet"),
  list("suppository",              "\\bsupposit"),
  list("pessary",                  "\\bpessar"),
  list("enema",                    "\\benema"),
  list("solution for infusion",    "solution for infusion|infusion"),
  list("solution for injection",   "solution for injection|injection"),
  list("powder for solution",      "powder for (?:solution|reconstitution)"),
  list("patch",                    "\\bpatch"),
  list("inhaler",                  "inhaler|inhalation"),
  list("nebuliser liquid",         "nebuliser liquid|nebuliser solution"),
  list("cream",                    "\\bcream\\b"),
  list("ointment",                 "\\bointment\\b"),
  list("gel",                      "\\bgel\\b"),
  list("eye drops",                "eye drops"),
  list("ear drops",                "ear drops"),
  list("nasal drops",              "nasal drops"),
  list("nasal spray",              "nasal spray"),
  list("spray",                    "\\bspray\\b"),
  list("pre-filled pen",           "pre-?filled pen"),
  list("pre-filled syringe",       "pre-?filled syringe"),
  list("pen",                      "\\bpen\\b"),
  list("lozenge",                  "\\blozenges?\\b"),
  list("ampoule",                  "\\bampoules?\\b"),
  list("vial",                     "\\bvials?\\b")
)

.modifier_patterns <- list(
  list("modified-release",         "modified-release|m/?r\\b|prolonged-release|sustained-release"),
  list("gastro-resistant",         "gastro-?resistant|enteric-?coated"),
  list("orodispersible",           "orodispersible"),
  list("chewable",                 "chewable"),
  list("effervescent",             "effervescent"),
  list("sublingual",               "sublingual"),
  list("dispersible",              "dispersible"),
  list("soluble",                  "soluble")
)

.route_patterns <- list(
  list("intravenous",     "intravenous|iv infusion|for infusion"),
  list("subcutaneous",    "subcutaneous|sub-cutaneous"),
  list("intramuscular",   "intramuscular"),
  list("rectal",          "suppositor|enema|rectal"),
  list("vaginal",         "pessar|vaginal"),
  list("topical",         "\\bcream\\b|\\bointment\\b|\\bgel\\b|\\bpatch"),
  list("inhaled",         "inhaler|inhalation|nebuliser"),
  list("intranasal",      "nasal"),
  list("ophthalmic",      "eye drops"),
  list("otic",            "ear drops"),
  list("oral",            "oral solution|oral suspension|oral liquid|oral drops|\\bsyrup\\b|\\belixir\\b|\\btablet|\\bcapsule|\\bgranules|\\bsachet|\\blozenge|chewable|orodispersible|sublingual|soluble|dispersible"),
  list("injection",       "injection|ampoule|vial|pre-?filled")
)

.match_first <- function(text, patterns, default = "unclassified") {
  if (is.na(text) || !nzchar(text)) return(default)
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
  form     <- unname(vapply(tail, .match_first, character(1), patterns = .form_patterns))
  modifier <- unname(vapply(tail, .match_first, character(1), patterns = .modifier_patterns, default = "none"))
  route    <- unname(vapply(tail, .match_first, character(1), patterns = .route_patterns))

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
