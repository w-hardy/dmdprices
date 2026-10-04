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

# Vectorised .canonicalise_unit(): `value` and `unit` are parallel vectors.
# Returns the canonical values and unit labels, NA where the unit has no
# canonical form.
.canonicalise_units <- function(value, unit) {
  n <- length(value)
  out_value <- rep(NA_real_, n)
  out_unit <- rep(NA_character_, n)
  if (n == 0L) {
    return(list(value = out_value, unit = out_unit))
  }
  idx <- match(tolower(as.character(unit)), .unit_table$input)
  ok <- !is.na(idx)
  out_value[ok] <- value[ok] * .unit_table$factor[idx[ok]]
  out_unit[ok] <- .unit_table$canonical[idx[ok]]
  list(value = out_value, unit = out_unit)
}

# The one convention for `strength_canonical` / `strength_unit_canon`, whether
# a strength comes from a parsed product name or from the dm+d VPI data: the
# canonical numerator per ONE canonical denominator unit, in slash form
# ("20mg/g" is 0.02 "mg/mg"; "500mg/50ml" is 10 "mg/ml"; "100units/ml" is 100
# "unit/ml"), or the canonical numerator alone when there is no denominator
# ("500mg" is 500 "mg"). A denominator unit with no stated value means one of
# it. A numerator or denominator unit with no canonical form gives NA for both,
# so a strength per hour or per square centimetre is never mistaken for a
# mass. Vectorised over parallel inputs; the denominator arguments recycle.
.canonical_strength <- function(
  value,
  unit,
  den_value = NA_real_,
  den_unit = NA_character_
) {
  n <- length(value)
  den_value <- rep_len(den_value, n)
  den_unit <- rep_len(den_unit, n)
  has_den <- !is.na(den_unit)
  den_value[has_den & is.na(den_value)] <- 1
  num <- .canonicalise_units(value, unit)
  den <- .canonicalise_units(den_value, den_unit)
  out_value <- ifelse(has_den, num$value / den$value, num$value)
  out_unit <- ifelse(has_den, paste0(num$unit, "/", den$unit), num$unit)
  # No strength without a value, a canonical unit on each side and a positive
  # denominator quantity; the unit is dropped with the value so that a row
  # never carries a unit for a strength it does not have.
  bad <- is.na(num$value) |
    is.na(num$unit) |
    (has_den & (is.na(den$unit) | !(den$value > 0)))
  out_value[bad] <- NA_real_
  out_unit[bad] <- NA_character_
  list(value = out_value, unit = out_unit)
}

# ── Container size stated in the name ────────────────────────────────────────

# The amount of one container of a concentration (a vial, bag, bottle, unit
# dose, pre-filled device) is never assumed: it is read from the product name
# as a bare size token in the strength denominator's physical dimension
# ("500ml bags", "0.25g unit dose", "2.4ml pre-filled disposable devices"), or
# failing that from an explicit numeric strength denominator ("10mg/1ml",
# "500mg/50ml"). An implicit "per ml" or "per g" with no size token names no
# container, and two different sizes are ambiguous; both give NA, which the
# dose functions treat as an unknown amount and skip with a warning.
.container_words <- paste0(
  "(?:bags?|bottles?|vials?|ampoules?|cartridges?|syringes?|pens?|sachets?|",
  "cassettes?|devices?|applicators?|tubes?|pouch(?:es)?|jars?|enemas?|",
  "unit\\s+doses?|containers?|cans?|droppers?)"
)
.container_modifiers <- paste0(
  "(?:(?:pre-?filled|disposable|plastic|polyethylene|glass|multidose|",
  "multi-dose|single-?dose|single-?use|sterile)\\s+)*"
)
# A size token: a number (not part of a strength expression, so not preceded
# by "/" or a digit) and a volume or mass unit, followed by a container word.
.container_token_rx <- paste0(
  "(?<![/\\d.,])(\\d+(?:[.,]\\d+)?)\\s?",
  "(ml|millilitres?|litres?|l|g|grams?|mg|kg)\\s+",
  .container_modifiers,
  .container_words,
  "\\b"
)
.container_unit_dimension <- c(
  ml = "ml", millilitre = "ml", millilitres = "ml", litre = "ml", litres = "ml",
  l = "ml", g = "mg", gram = "mg", grams = "mg", mg = "mg", kg = "mg"
)
.container_unit_factor <- c(
  ml = 1, millilitre = 1, millilitres = 1, litre = 1000, litres = 1000,
  l = 1000, g = 1000, gram = 1000, grams = 1000, mg = 1, kg = 1e6
)

# Canonical amount (ml or mg) of one container as the name states it, in
# `dimension` ("ml" or "mg"); NA when the name states no size in that
# dimension or states two different ones. Vectorised over `medicine`.
.container_amount <- function(medicine, dimension) {
  n <- length(medicine)
  dimension <- rep_len(dimension, n)
  out <- rep(NA_real_, n)
  if (n == 0L) {
    return(out)
  }
  hits <- regmatches(
    medicine,
    gregexpr(.container_token_rx, medicine, perl = TRUE, ignore.case = TRUE)
  )
  for (i in seq_len(n)) {
    tokens <- hits[[i]]
    if (is.na(medicine[i]) || length(tokens) == 0L) {
      next
    }
    parts <- regmatches(
      tokens,
      regexec(.container_token_rx, tokens, perl = TRUE, ignore.case = TRUE)
    )
    unit <- tolower(vapply(parts, `[`, character(1), 3L))
    value <- as.numeric(gsub(",", "", vapply(parts, `[`, character(1), 2L)))
    keep <- .container_unit_dimension[unit] %in% dimension[i]
    amounts <- unique(value[keep] * unname(.container_unit_factor[unit[keep]]))
    if (length(amounts) == 1L) {
      out[i] <- amounts
    }
  }
  out
}

# The container amounts a name supports in each physical dimension: the stated
# size, else the strength denominator when it is explicit and in that
# dimension. `den_value`/`den_unit` are the parsed strength denominator.
.container_quantities <- function(medicine, den_value, den_unit) {
  n <- length(medicine)
  den_value <- rep_len(den_value, n)
  den_unit <- rep_len(den_unit, n)
  explicit <- !is.na(medicine) & grepl("/\\s?\\d", medicine)
  den <- .canonicalise_units(den_value, den_unit)
  fill <- function(amount, dimension) {
    use_den <- is.na(amount) & explicit & !is.na(den$unit) & den$unit == dimension
    amount[use_den] <- den$value[use_den]
    amount
  }
  list(
    ml = fill(.container_amount(medicine, "ml"), "ml"),
    mg = fill(.container_amount(medicine, "mg"), "mg")
  )
}

# ── Numeric strength grammar ─────────────────────────────────────────────────

# Numeric strength token: digits with optional comma thousands groups and an
# optional decimal part ("500", "2.5", "100,000", "1,234.5"). dm+d writes large
# biological-activity strengths with commas (e.g. nystatin "100,000units/ml");
# see issue #22. A comma group must be exactly three digits, so malformed
# tokens ("1,00") and European decimal commas ("1,5") never match.
.strength_num <- "\\d+(?:,\\d{3})*(?:\\.\\d+)?"

# Convert a captured numeric token to numeric, stripping thousands commas.
# NA-safe: unmatched optional capture groups pass through as NA.
.strength_amount <- function(x) {
  suppressWarnings(as.numeric(gsub(",", "", x, fixed = TRUE)))
}

# ── Strength tokens, bracketed restatements and packs (#27) ──────────────────
#
# These helpers feed .is_unsupported_compound() in dmd_dose_optimise.R. They
# live here because they are built from .strength_num and .unit_table at load
# time, and dmd_dose_optimise.R collates before this file.

# Strength token: an amount with a mass or biological-activity unit. Volume
# and count units ("20ml solvent", "28 tablets") are not strengths.
# .strength_num accepts comma thousands groups so a "1,000unit" token is
# matched from its true start rather than from the digits after the comma.
.strength_token_regex <- paste0(
  "(?i)", .strength_num, "\\s*",
  "(?:micrograms?|mcg|mg|ng|nanograms?|g|units?|u)\\b"
)

# Number of matches of `pattern` in each element of `x`: 0 for no match or NA.
.count_matches <- function(x, pattern) {
  vapply(
    gregexpr(pattern, x, perl = TRUE),
    function(m) if (is.na(m[1L]) || m[1L] == -1L) 0L else length(m),
    integer(1)
  )
}

# Number of strength tokens in each name (0 for a name with none, or NA).
.strength_token_count <- function(name) {
  .count_matches(name, .strength_token_regex)
}

# A bracketed segment holding nothing but one strength token, optionally with
# a "/denominator": eptacog alfa's "(50,000unit)", or "(10mg/ml)". Capture 1 is
# the token's unit. "(Iodine 350mg/ml)" names a substance, so it is not bare.
.bare_paren_strength_regex <- paste0(
  "(?i)\\(\\s*", .strength_num, "\\s*",
  "(micrograms?|mcg|mg|ng|nanograms?|g|units?|u)",
  "(?:\\s*/\\s*(?:", .strength_num, ")?\\s*[a-z]+)?\\s*\\)"
)

# Canonical unit ("mg", "ml", "unit", ...) of each unit label; NA if unknown.
# Vectorised equivalent of .canonicalise_unit(1, unit)$unit.
.canonical_unit_of <- function(unit) {
  .unit_table$canonical[match(tolower(unit), .unit_table$input)]
}

# Number of bare bracketed strengths in each name that restate the parsed
# strength in another unit dimension: eptacog alfa "1mg (50,000unit)" is one
# mass dose restated as activity (#27). A bracketed value in the same
# dimension ("200mg (Mexiletine 167mg)", "25units/ml (500unit)") is a competing
# dose basis and is not a restatement, nor is a bracketed strength that names
# another substance ("(Iodine 350mg/ml)"). With no parsed strength there is
# nothing to restate, so the count is 0.
.restatement_count <- function(name, strength_unit) {
  primary <- .canonical_unit_of(strength_unit)
  bare <- regmatches(
    name,
    gregexpr(.bare_paren_strength_regex, name, perl = TRUE)
  )
  vapply(
    seq_along(bare),
    function(i) {
      if (is.na(primary[i]) || length(bare[[i]]) == 0L) {
        return(0L)
      }
      unit <- sub(.bare_paren_strength_regex, "\\1", bare[[i]], perl = TRUE)
      canon <- .canonical_unit_of(unit)
      sum(!is.na(canon) & canon != primary[i])
    },
    integer(1)
  )
}

# Strength tokens in each name that give a dose basis of their own: every
# token, less the restatements above. Each restatement is itself a token, so
# the result is never negative and never above .strength_token_count().
.dose_strength_count <- function(name, strength_unit) {
  .strength_token_count(name) - .restatement_count(name, strength_unit)
}

# One complete product phrase within a pack name: an optional drug name, a
# strength (with optional "/denominator"s), then at least one more word (the
# form). Capture 1 is the drug name. "Liposomal Iron 15mg" has no form, so it
# is an ingredient of one product rather than a product of its own.
.pack_phrase_regex <- paste0(
  "^\\s*(.*?)\\s*",
  .strength_num,
  "\\s*(?i:micrograms?|mcg|mg|ng|nanograms?|g|units?|u)\\b",
  "(?:\\s*/\\s*(?:", .strength_num, ")?\\s*[A-Za-z]+)*",
  "\\s+[A-Za-z]"
)

# Classify names that are packs of several products (#27):
# - "multi_strength_pack" when every product phrase names the same drug
#   ("Danicopan 50mg tablets and Danicopan 100mg tablets") or the name says
#   "initiation pack" / "titration pack";
# - "co_pack" when the phrases name different products ("Tixagevimab ...
#   vials and Cilgavimab ... vials");
# - NA otherwise, including combination products.
# Phrases are split on " and " followed by a capital or a digit, so dm+d's
# "powder and solvent" idiom never splits, and every part must be a full
# product phrase.
.pack_kind <- function(name) {
  out <- rep(NA_character_, length(name))
  titration <- grepl(
    "(?i)\\b(?:initiation|titration)\\s+pack\\b",
    name,
    perl = TRUE
  )
  out[titration] <- "multi_strength_pack"
  parts <- strsplit(name, "\\s+and\\s+(?=[A-Z0-9])", perl = TRUE)
  for (i in which(lengths(parts) >= 2L & !titration)) {
    m <- regmatches(
      parts[[i]],
      regexec(.pack_phrase_regex, parts[[i]], perl = TRUE)
    )
    if (any(lengths(m) == 0L)) {
      next
    }
    drugs <- tolower(trimws(vapply(m, `[[`, character(1), 2L)))
    same_drug <- all(nzchar(drugs)) && length(unique(drugs)) == 1L
    out[i] <- if (same_drug) "multi_strength_pack" else "co_pack"
  }
  out
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
  "(?<amt>", .strength_num, ")",
  "\\s*",
  "(?<unit>micrograms?|mcg|mg|ng|nanograms?|g|units?|u)",
  "(?:",
  "\\s*/\\s*",
  "(?<den_amt>(?:", .strength_num, "))?",
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
  .strength_num, "\\s*(?:", .mass_unit_alt, ")",
  "(?:\\s*/\\s*", .strength_num, "\\s*(?:", .mass_unit_alt, "))+",
  ")",
  "(?:\\s*/\\s*((?:", .strength_num, "))?\\s*(ml|litres?|l|doses?|actuations?))?",
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
      paste0("(?i)^\\s*(", .strength_num, ")\\s*(", .mass_unit_alt, ")\\s*$"),
      token,
      perl = TRUE
    )
  )[[1]]
  if (length(m) == 0) {
    return(NULL)
  }
  amt <- .strength_amount(m[2])
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
  den_amt <- .strength_amount(m[4])
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
  "(?i)(", .strength_num, ")\\s*(",
  .mass_unit_alt,
  ")(?:\\s*/\\s*((?:", .strength_num, "))?\\s*(ml|litres?|l|doses?|actuations?|g))?"
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
    amt <- .strength_amount(m[2])
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
      den_amt <- if (is.na(m[4]) || !nzchar(m[4])) 1 else .strength_amount(m[4])
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
  amt <- .strength_amount(m[3])
  unit <- unname(m[4])
  den_amt <- .strength_amount(m[5])
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
  can <- .canonical_strength(amt, unit, den_amt, den_unit)
  strength_canonical <- can$value
  strength_unit_canon <- can$unit

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
      paste0("^(", .strength_num, ")\\s*(", unit_pat, ")$"),
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
  list(value = .strength_amount(m[2]), unit = tolower(m[3]))
}

#' Parse a dm+d VMP name into drug stem, strength, and remainder
#'
#' Extracts a numeric strength and optional per-denominator concentration
#' (e.g. `mg/ml`, `microgram/dose`) from a VMP name. Also returns a canonical
#' form (mass in mg, volume in ml, biological activity as `"unit"`).
#'
#' Strengths written with comma thousands separators, as dm+d does for large
#' biological-activity values (e.g. nystatin `"100,000units/ml"`), parse
#' identically to their plain forms.
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
#'   "Salbutamol 100micrograms/dose inhaler CFC free",
#'   "Nystatin 100,000units/ml oral suspension"
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
