# Dose combination optimisation helpers for dmd_dose_optimise().
# All functions here are internal.

# ── Integer scaling ───────────────────────────────────────────────────────────

# Safe wrapper around .pick_scale() that applies two additional caps so that
# dose_canonical * s never overflows as.integer() and stays within the DP
# table hard cap (dp_cap cells). Without this, a repeating-decimal strength
# (e.g. 1400 mg / 11.7 ml = 119.658...) can push the scale to 1e7, causing
# 900 * 1e7 = 9e9 > .Machine$integer.max, which coerces to NA_integer_ and
# triggers "missing value where TRUE/FALSE needed" in .optimise_group().
#
# Returns the minimum of: the base scale from .pick_scale() (capped at
# max_scale), an integer-overflow cap, and a DP-table-size cap. The effective
# result may be well below max_scale when strengths or dose are large.

.pick_scale_safe <- function(
  strengths,
  dose_canonical,
  max_scale = 1e6,
  dp_cap = 5e6
) {
  s <- .pick_scale(strengths, max_scale)
  all_vals <- c(strengths, dose_canonical)
  all_vals <- all_vals[!is.na(all_vals) & all_vals > 0]
  if (length(all_vals) == 0) {
    return(s)
  }
  # Cap (a): no value overflows as.integer()
  max_safe_int <- floor(.Machine$integer.max / max(all_vals))
  # Cap (b): dose_canonical * s stays within the DP table limit, keeping
  # dose_int + max_over arithmetic safely in integer range
  max_safe_dp <- floor(dp_cap / dose_canonical)
  min(s, max(max_safe_int, 1L), max(max_safe_dp, 1L))
}

# Pick an integer scale factor that turns all supplied values into integers
# (within tolerance). Caps at 1e6 so we don't blow up the DP table.
.pick_scale <- function(values, max_scale = 1e6) {
  s <- 1
  tol <- 1e-9
  for (v in values) {
    if (is.na(v)) {
      next
    }
    while (s <= max_scale && abs(v * s - round(v * s)) > tol) {
      s <- s * 10
    }
  }
  s
}

# ── Pack-level coin builder ──────────────────────────────────────────────────

# Adds a `pack_dose` column to group_df: the total canonical dose delivered
# by purchasing one whole pack of each AMPP row.
#
# For solid-form rows (no denominator_unit): pack_dose = per_item_dose × pack_size
# (e.g. 500 mg tablet × 28 = 14,000 mg per pack).
# For concentration rows (denominator_unit present): per_item_dose already
# encodes the full container dose, so pack_dose = per_item_dose unchanged.
.build_pack_df <- function(group_df) {
  is_concentration <- !is.na(group_df$denominator_unit)
  group_df$pack_dose <- ifelse(
    is_concentration,
    group_df$per_item_dose,
    group_df$per_item_dose * group_df$pack_size
  )
  group_df
}

# ── Dose DP ───────────────────────────────────────────────────────────────────

# Runs an unbounded-knapsack DP over integer per-item doses.
#
# strengths_int : integer vector of per-item doses in scaled integer units
# per_item_price: numeric vector of pro-rata per-item prices (pence). Same
#                 length as strengths_int.
# dose_int      : integer target in scaled units.
# max_over      : max allowed over-delivery in scaled units.
#
# Returns a list with `min_items`, `min_cost`, `max_cost`, `items_back`,
# `cost_back`, and `max_back`
# vectors indexed 1..(dose_int + max_over + 1) — index = t + 1.
.dose_dp <- function(strengths_int, per_item_price, dose_int, max_over) {
  T <- as.integer(dose_int + max_over)
  INF <- Inf

  min_items <- rep(INF, T + 1L)
  min_cost <- rep(INF, T + 1L)
  max_cost <- rep(-INF, T + 1L)
  max_items <- rep(-INF, T + 1L)
  items_back <- rep(NA_integer_, T + 1L)
  cost_back <- rep(NA_integer_, T + 1L)
  max_back <- rep(NA_integer_, T + 1L)

  min_items[1] <- 0
  min_cost[1] <- 0
  max_cost[1] <- 0
  max_items[1] <- 0

  # Replace NA prices with Inf so they never win min_cost but still allow
  # min_items reconstruction. For max_cost, replace NA with -Inf.
  price_for_cost <- per_item_price
  price_for_cost[is.na(price_for_cost)] <- Inf
  price_for_max <- per_item_price
  price_for_max[is.na(price_for_max)] <- -Inf

  for (t in 1L:T) {
    valid <- which(strengths_int <= t)
    if (length(valid) == 0L) next

    prev_idxs <- t - strengths_int[valid] + 1L

    # Fewest-items update: find the valid strength whose predecessor has the
    # fewest items already, then apply if it beats the current cell.
    cand_items <- min_items[prev_idxs] + 1
    best_i <- which.min(cand_items)
    if (cand_items[best_i] < min_items[t + 1L]) {
      min_items[t + 1L] <- cand_items[best_i]
      items_back[t + 1L] <- valid[best_i]
    }

    # Cheapest update: same logic for cost.
    cand_cost <- min_cost[prev_idxs] + price_for_cost[valid]
    best_c <- which.min(cand_cost)
    if (cand_cost[best_c] < min_cost[t + 1L]) {
      min_cost[t + 1L] <- cand_cost[best_c]
      cost_back[t + 1L] <- valid[best_c]
    }

    # Most-expensive update: maximize cost, with more items as the within-cell
    # tie-break so target-level ties can be resolved consistently later.
    cand_max_cost <- max_cost[prev_idxs] + price_for_max[valid]
    cand_max_items <- max_items[prev_idxs] + 1
    # Maximise cost, breaking equal-cost ties in favour of more items so the
    # within-cell choice matches the tie-break documented above.
    best_m <- order(-cand_max_cost, -cand_max_items)[1L]
    if (
      cand_max_cost[best_m] > max_cost[t + 1L] ||
        (
          cand_max_cost[best_m] == max_cost[t + 1L] &&
            cand_max_items[best_m] > max_items[t + 1L]
        )
    ) {
      max_cost[t + 1L] <- cand_max_cost[best_m]
      max_items[t + 1L] <- cand_max_items[best_m]
      max_back[t + 1L] <- valid[best_m]
    }
  }

  list(
    min_items = min_items,
    min_cost = min_cost,
    max_cost = max_cost,
    max_items = max_items,
    items_back = items_back,
    cost_back = cost_back,
    max_back = max_back
  )
}

# Reconstruct the strength-index → count map by following back-pointers.
.reconstruct <- function(back, strengths_int, target_t) {
  counts <- integer(length(strengths_int))
  t <- target_t
  while (t > 0) {
    i <- back[t + 1L]
    if (is.na(i)) {
      # Shouldn't happen if `target_t` is reachable, but guard anyway.
      return(NULL)
    }
    counts[i] <- counts[i] + 1L
    t <- t - strengths_int[i]
  }
  counts
}

# ── Over-delivery policy ─────────────────────────────────────────────────────

# Sentinel returned by .optimise_group_items() when the over-delivery policy is
# "forbid" and no exact-dose combination exists for the group. Distinguishes
# "this group cannot deliver the dose exactly" (case 2) from "this group has no
# usable candidates at all" (case 3, signalled by NULL). Callers aggregate these
# and warn once per call rather than once per group.
.no_exact_result <- function() {
  structure(list(), class = "dmd_no_exact")
}

.is_no_exact <- function(x) {
  inherits(x, "dmd_no_exact")
}

# Records, on a returned result row, that the over-delivery policy governed this
# group and whether the group could have delivered the dose exactly. Carried as
# attributes rather than columns: the caller reads them to build one warning per
# call, and dplyr::bind_rows() drops them before the tibble reaches the user.
# Groups exempt from the policy carry neither, which is what keeps them out of
# the over-delivery warning.
.set_policy_info <- function(res, exact_feasible) {
  attr(res, "policy_applied") <- TRUE
  attr(res, "exact_feasible") <- exact_feasible
  res
}

.policy_row <- function(x) {
  isTRUE(attr(x, "policy_applied", exact = TRUE))
}

.exact_feasible <- function(x) {
  isTRUE(attr(x, "exact_feasible", exact = TRUE))
}

# dplyr::bind_rows() carries the attributes of a single input through, so strip
# them explicitly before the result reaches the user.
.drop_policy_info <- function(x) {
  attr(x, "policy_applied") <- NULL
  attr(x, "exact_feasible") <- NULL
  x
}

# Restrict the candidate target positions according to the over-delivery policy.
# `feasible` and `ts` are parallel vectors over the candidate targets; the return
# value is a vector of positions into them (possibly empty).
#
#   "allow"    all feasible targets — cost / item count decides, over-delivery is
#              only a tie-break (the historical behaviour).
#   "minimise" the feasible target with the smallest over-delivery.
#   "forbid"   the exact target only.
#
# "minimise" and "forbid" both collapse to a single target, so the objective then
# only chooses which back-pointer path to follow to that target.
.restrict_targets <- function(feasible, ts, dose_int, over_delivery) {
  keep <- which(feasible)
  if (length(keep) == 0L || identical(over_delivery, "allow")) {
    return(keep)
  }
  if (identical(over_delivery, "forbid")) {
    return(keep[ts[keep] == dose_int])
  }
  # "minimise"
  over <- ts[keep] - dose_int
  keep[which.min(over)]
}

# ── Pick the best target t for each objective ────────────────────────────────

.best_target <- function(
  dp,
  dose_int,
  max_over,
  objective,
  over_delivery = "allow"
) {
  ts <- dose_int:(dose_int + max_over)
  idx <- ts + 1L
  items_vec <- dp$min_items[idx]
  cost_vec <- dp$min_cost[idx]

  allowed <- .restrict_targets(
    is.finite(items_vec),
    ts,
    dose_int,
    over_delivery
  )
  if (length(allowed) == 0L) {
    return(NULL)
  }
  # Blank out the disallowed targets so every feasibility test below — including
  # the cost-side ones — sees only the targets the policy permits, leaving the
  # objective and tie-break logic itself untouched.
  drop <- setdiff(seq_along(ts), allowed)
  items_vec[drop] <- Inf
  cost_vec[drop] <- Inf

  feasible <- is.finite(items_vec)

  if (objective == "min_items") {
    # Smallest items; tie-break by smallest over-delivery, then cost.
    cand <- which(feasible & items_vec == min(items_vec[feasible]))
    over <- ts[cand] - dose_int
    sub <- cand[which(over == min(over))]
    if (length(sub) > 1) {
      cs <- cost_vec[sub]
      sub <- sub[which.min(cs)]
    }
    chosen <- sub[1]
    return(list(
      t = ts[chosen],
      items = items_vec[chosen],
      cost = cost_vec[chosen],
      back = dp$items_back
    ))
  }

  # cheapest
  finite_cost <- is.finite(cost_vec)
  if (!any(finite_cost)) {
    # No priced combination — fall back to min-items ordering but record NA cost.
    cand <- which(feasible)
    over <- ts[cand] - dose_int
    sub <- cand[which(over == min(over))]
    chosen <- sub[which.min(items_vec[sub])][1]
    return(list(
      t = ts[chosen],
      items = items_vec[chosen],
      cost = NA_real_,
      back = dp$items_back
    ))
  }
  cand <- which(cost_vec == min(cost_vec[finite_cost]))
  cand <- cand[cand %in% which(finite_cost)]
  if (length(cand) > 1) {
    # Tie-break: smallest over-delivery first (least wasted drug), then fewer
    # items. `items_vec` (dp$min_items) reflects the fewest-items path to each
    # target, which need not be the cheapest path, so over-delivery — a property
    # of the target itself — is the reliable primary key on a cost tie.
    over <- ts[cand] - dose_int
    sub <- cand[which(over == min(over))]
    if (length(sub) > 1) {
      sub <- sub[which.min(items_vec[sub])]
    }
    chosen <- sub[1]
  } else {
    chosen <- cand[1]
  }
  list(
    t = ts[chosen],
    items = items_vec[chosen],
    cost = cost_vec[chosen],
    back = dp$cost_back
  )
}


# Like .best_target() but selects the target that MAXIMISES cost (most expensive).
# Tie-breaks: most items, then largest over-delivery.
.best_target_max <- function(dp, dose_int, max_over, over_delivery = "allow") {
  ts <- dose_int:(dose_int + max_over)
  idx <- ts + 1L
  min_items_vec <- dp$min_items[idx]
  items_vec <- dp$max_items[idx]
  cost_vec <- dp$max_cost[idx]

  allowed <- .restrict_targets(
    is.finite(min_items_vec),
    ts,
    dose_int,
    over_delivery
  )
  if (length(allowed) == 0L) {
    return(NULL)
  }
  # As in .best_target(): disallowed targets are made infeasible (and unpriced)
  # so the selection below only ever sees policy-permitted targets.
  drop <- setdiff(seq_along(ts), allowed)
  min_items_vec[drop] <- Inf
  cost_vec[drop] <- -Inf

  feasible <- is.finite(min_items_vec)
  finite_cost <- is.finite(cost_vec)

  if (!any(feasible)) {
    return(NULL)
  }

  if (!any(finite_cost & feasible)) {
    # No priced option — return the feasible target with most items as proxy.
    cand <- which(feasible)
    chosen <- cand[which.max(min_items_vec[cand])][1]
    return(list(
      t = ts[chosen],
      items = min_items_vec[chosen],
      cost = NA_real_,
      back = dp$items_back
    ))
  }

  cand <- which(finite_cost & feasible)
  max_cost <- max(cost_vec[cand])
  top <- cand[cost_vec[cand] == max_cost]

  if (length(top) > 1) {
    # Tie-break: most items
    it <- items_vec[top]
    sub <- top[it == max(it)]
    if (length(sub) > 1) {
      over <- ts[sub] - dose_int
      sub <- sub[which.max(over)]
    }
    chosen <- sub[1]
  } else {
    chosen <- top[1]
  }

  list(
    t = ts[chosen],
    items = items_vec[chosen],
    cost = cost_vec[chosen],
    back = dp$max_back
  )
}


# ── Group-level optimisation ─────────────────────────────────────────────────

# Runs the optimisation for one preparation group.
#
# group_df: tibble of AMPP rows for a single (medicine_root, preparation_group,
#   dose_unit) combination. Must contain columns: per_item_dose,
#   strength_canonical, strength_unit_canon, pack_size, pack_price_pence,
#   per_item_price_pence, medicine, ampp_name, vmpp_snomed_code,
#   ampp_snomed_code, price_field_used, price_fallback.
# dose_canonical: numeric target dose in canonical mass/volume units.
# dose_unit_canon: canonical mass/volume unit ("mg", "ml", or "unit").
# objective: "cheapest", "min_items", or "most_expensive".
# medicine_root, preparation_group, preparation_label: group identifiers.
# can_split: logical. FALSE = whole packs must be dispensed for solid forms;
#   concentration-based preparations are always whole-container regardless.
# can_split_vials: logical. TRUE = concentration preparations may be costed
#   as a fraction of a container (vial sharing). Default FALSE.
# over_delivery: "forbid", "minimise", or "allow". Applies only where an "item"
#   is an individually administered dose (the item DP over solid forms), because
#   there over-delivery is extra drug given to the patient. Whole-pack mode and
#   whole-container preparations are exempt: their over-delivery is wastage, and
#   the cheapest pack/container covering the dose remains the costing answer.
.optimise_group <- function(
  group_df,
  dose_canonical,
  dose_unit_canon,
  objective,
  medicine_root,
  preparation_group,
  preparation_label,
  can_split = TRUE,
  can_split_vials = FALSE,
  over_delivery = "allow"
) {
  # Detect whether every row in this group is concentration-based.
  all_concentration <- all(!is.na(group_df$denominator_unit))

  # Vial-sharing path: bypass DP entirely; cost the exact fraction needed.
  if (all_concentration && can_split_vials) {
    return(.optimise_group_vial_share(
      group_df = group_df,
      dose_canonical = dose_canonical,
      dose_unit_canon = dose_unit_canon,
      objective = objective,
      medicine_root = medicine_root,
      preparation_group = preparation_group,
      preparation_label = preparation_label
    ))
  }

  # Use pack-level DP when whole packs must be dispensed AND the preparation
  # is a solid form. Concentration preparations are always whole-container
  # regardless of can_split, so they take the standard path.
  use_pack_dp <- !can_split && !all_concentration

  # Whole packs and whole containers deliver surplus into the pack or the vial,
  # not into the patient, so the over-delivery policy governs neither. When it
  # does not apply, the group is optimised as if "allow" had been requested and
  # says so in its notes.
  policy_applies <- !use_pack_dp && !all_concentration
  note_exemption <- !policy_applies && !identical(over_delivery, "allow")

  if (use_pack_dp) {
    .optimise_group_packs(
      group_df = group_df,
      dose_canonical = dose_canonical,
      dose_unit_canon = dose_unit_canon,
      objective = objective,
      medicine_root = medicine_root,
      preparation_group = preparation_group,
      preparation_label = preparation_label,
      policy_exempt = note_exemption
    )
  } else {
    .optimise_group_items(
      group_df = group_df,
      dose_canonical = dose_canonical,
      dose_unit_canon = dose_unit_canon,
      objective = objective,
      medicine_root = medicine_root,
      preparation_group = preparation_group,
      preparation_label = preparation_label,
      over_delivery = if (policy_applies) over_delivery else "allow",
      policy_applies = policy_applies,
      policy_exempt = note_exemption
    )
  }
}

# ── Item-level optimisation (can_split = TRUE or concentration) ───────────────

# Runs the DP with per-item (tablet/container) coins. One DP unit = one tablet
# or one concentration container. Costs are pro-rata (pack_price / pack_size)
# for solid forms; whole-container price for concentration forms.
.optimise_group_items <- function(
  group_df,
  dose_canonical,
  dose_unit_canon,
  objective,
  medicine_root,
  preparation_group,
  preparation_label,
  over_delivery = "allow",
  policy_applies = FALSE,
  policy_exempt = FALSE
) {
  # The DP operates on per-item canonical doses: for tablets/capsules this
  # is the strength itself; for liquids it is concentration × pack_size so
  # one "item" corresponds to one container.
  strengths <- sort(unique(group_df$per_item_dose))
  strengths <- strengths[!is.na(strengths) & strengths > 0]
  if (length(strengths) == 0) {
    return(NULL)
  }

  is_max <- identical(objective, "most_expensive")

  # Objective-specific per-item price per per_item_dose level. The DP needs the
  # highest priced AMPP for the max-cost path and the cheapest for all others.
  price_per_strength <- vapply(
    strengths,
    function(s) {
      rows <- group_df[group_df$per_item_dose == s, , drop = FALSE]
      if (all(is.na(rows$per_item_price_pence))) {
        return(NA_real_)
      }
      if (is_max) {
        max(rows$per_item_price_pence, na.rm = TRUE)
      } else {
        min(rows$per_item_price_pence, na.rm = TRUE)
      }
    },
    numeric(1)
  )

  scale <- .pick_scale_safe(strengths, dose_canonical)
  strengths_int <- as.integer(round(strengths * scale))
  dose_int <- as.integer(round(dose_canonical * scale))

  if (dose_int <= 0) {
    return(NULL)
  }
  max_strength <- max(strengths_int)
  max_over <- max_strength

  if ((dose_int + max_over + 1L) > 5e6) {
    cli::cli_warn(
      "Dose DP table for group {.val {preparation_label}} would exceed 5,000,000 cells; skipping."
    )
    return(NULL)
  }

  dp <- .dose_dp(strengths_int, price_per_strength, dose_int, max_over)

  best <- if (is_max) {
    .best_target_max(dp, dose_int, max_over, over_delivery)
  } else {
    .best_target(dp, dose_int, max_over, objective, over_delivery)
  }

  if (is.null(best)) {
    # Under "forbid" the only reason selection can fail on an otherwise usable
    # group is that no combination lands exactly on the dose. Report that
    # separately so callers can warn about it once.
    if (identical(over_delivery, "forbid")) {
      return(.no_exact_result())
    }
    return(NULL)
  }

  # For "most_expensive" we want the most expensive AMPP per strength, not cheapest.
  pick_ampp <- if (is_max) {
    function(rows) {
      priced <- rows[!is.na(rows$per_item_price_pence), , drop = FALSE]
      if (nrow(priced) == 0) {
        rows[1, , drop = FALSE]
      } else {
        priced[which.max(priced$per_item_price_pence), , drop = FALSE]
      }
    }
  } else {
    function(rows) {
      priced <- rows[!is.na(rows$per_item_price_pence), , drop = FALSE]
      if (nrow(priced) == 0) {
        rows[1, , drop = FALSE]
      } else {
        priced[which.min(priced$per_item_price_pence), , drop = FALSE]
      }
    }
  }

  counts <- .reconstruct(best$back, strengths_int, best$t)
  if (is.null(counts)) {
    return(NULL)
  }

  combo_rows <- list()
  cost_prorata <- 0
  cost_whole <- 0
  price_fallback <- FALSE
  notes <- character()

  for (i in seq_along(strengths)) {
    if (counts[i] == 0L) {
      next
    }
    s <- strengths[i]
    rows <- group_df[group_df$per_item_dose == s, , drop = FALSE]

    chosen <- pick_ampp(rows)
    subtotal_prorata <- if (is.na(chosen$per_item_price_pence)) {
      NA_real_
    } else {
      chosen$per_item_price_pence * counts[i]
    }

    # Whole-pack figures describe buying *the same* AMPP whole (the one being
    # split), so identity, per-item price, and pack price in this row all refer
    # to a single product. Previously the whole-pack price came from a
    # separately chosen cheapest/dearest-whole-pack AMPP, which produced rows
    # that labelled one pack with another pack's price (e.g. a 1000-tablet pack
    # shown with a 28-tablet pack's price).
    items_per_pack <- chosen$items_per_pack
    if (
      is.na(chosen$pack_price_pence) ||
        is.na(items_per_pack) ||
        items_per_pack <= 0
    ) {
      packs_to_buy <- NA_integer_
      subtotal_whole <- NA_real_
    } else {
      packs_to_buy <- as.integer(ceiling(counts[i] / items_per_pack))
      subtotal_whole <- as.numeric(packs_to_buy * chosen$pack_price_pence)
    }

    if (isTRUE(chosen$price_fallback)) {
      price_fallback <- TRUE
    }

    combo_rows[[length(combo_rows) + 1L]] <- tibble::tibble(
      medicine = chosen$medicine,
      ampp_name = chosen$ampp_name,
      vmpp_snomed_code = chosen$vmpp_snomed_code,
      ampp_snomed_code = chosen$ampp_snomed_code,
      strength_canonical = chosen$strength_canonical,
      strength_unit = chosen$strength_unit_canon,
      per_item_dose = s,
      per_item_dose_unit = dose_unit_canon,
      count = counts[i],
      pack_size = chosen$pack_size,
      packs_to_buy = packs_to_buy,
      pack_price_pence = chosen$pack_price_pence,
      per_item_price_pence = chosen$per_item_price_pence,
      subtotal_prorata_pence = subtotal_prorata,
      subtotal_whole_pack_pence = subtotal_whole
    )

    cost_prorata <- cost_prorata +
      (if (is.na(subtotal_prorata)) 0 else subtotal_prorata)
    cost_whole <- cost_whole +
      (if (is.na(subtotal_whole)) 0 else subtotal_whole)
  }

  combination <- dplyr::bind_rows(combo_rows)
  dose_delivered <- best$t / scale
  over_amount <- dose_delivered - dose_canonical

  if (over_amount > 0) {
    notes <- c(notes, "over-delivery")
    if (identical(over_delivery, "minimise")) {
      notes <- c(notes, "over-delivery-minimised")
    }
  }
  if (policy_exempt) {
    notes <- c(notes, "over-delivery-policy-not-applied")
  }
  if (price_fallback) {
    notes <- c(notes, "price-field-fallback")
  }
  if (is_max) {
    notes <- c(notes, "most-expensive-AMPP-per-strength")
  } else if (nrow(combination) > 0) {
    notes <- c(notes, "cheapest-AMPP-per-strength")
  }

  res <- .assemble_result(
    combination = combination,
    dose_delivered = dose_delivered,
    dose_canonical = dose_canonical,
    dose_unit_canon = dose_unit_canon,
    scale = scale,
    cost_prorata = cost_prorata,
    cost_whole = cost_whole,
    total_items = sum(combination$count),
    notes = notes,
    medicine_root = medicine_root,
    preparation_group = preparation_group,
    preparation_label = preparation_label,
    objective = objective,
    group_df = group_df
  )

  if (!policy_applies) {
    return(res)
  }
  # An exact target is reachable iff the DP found any item combination summing
  # to the dose itself, whatever this objective settled on.
  .set_policy_info(res, is.finite(dp$min_items[dose_int + 1L]))
}

# ── Vial-sharing optimisation (can_split_vials = TRUE, concentration only) ────
#
# Bypasses the DP. For each product, fraction = dose_canonical / per_item_dose.
# Cost = fraction * per_item_price_pence. Selects cheapest / most expensive /
# fewest-items product. count in the combination tibble is the non-integer
# fraction used. Adds "vial-sharing" to notes.
.optimise_group_vial_share <- function(
  group_df,
  dose_canonical,
  dose_unit_canon,
  objective,
  medicine_root,
  preparation_group,
  preparation_label
) {
  # Only keep rows with a valid per_item_dose and price.
  priced <- group_df[
    !is.na(group_df$per_item_dose) &
      group_df$per_item_dose > 0 &
      !is.na(group_df$per_item_price_pence),
    ,
    drop = FALSE
  ]

  if (nrow(priced) == 0) {
    # Fall back to whole-vial costing with any available row.
    priced <- group_df[
      !is.na(group_df$per_item_dose) & group_df$per_item_dose > 0,
      ,
      drop = FALSE
    ]
    if (nrow(priced) == 0) return(NULL)
  }

  fractions <- dose_canonical / priced$per_item_dose
  costs <- fractions * priced$per_item_price_pence

  chosen_idx <- switch(
    objective,
    most_expensive = which.max(costs),
    min_items = which.min(fractions),
    which.min(costs) # cheapest (default)
  )
  chosen <- priced[chosen_idx, , drop = FALSE]
  frac <- fractions[chosen_idx]
  cost <- costs[chosen_idx]

  notes <- "vial-sharing"
  if (isTRUE(chosen$price_fallback)) {
    notes <- c(notes, "price-field-fallback")
  }

  combo <- tibble::tibble(
    medicine = chosen$medicine,
    ampp_name = chosen$ampp_name,
    vmpp_snomed_code = chosen$vmpp_snomed_code,
    ampp_snomed_code = chosen$ampp_snomed_code,
    strength_canonical = chosen$strength_canonical,
    strength_unit = chosen$strength_unit_canon,
    per_item_dose = chosen$per_item_dose,
    per_item_dose_unit = dose_unit_canon,
    count = frac, # non-integer fraction of container
    pack_size = chosen$pack_size,
    packs_to_buy = NA_integer_,
    pack_price_pence = chosen$pack_price_pence,
    per_item_price_pence = chosen$per_item_price_pence,
    subtotal_prorata_pence = cost,
    subtotal_whole_pack_pence = cost
  )

  .assemble_result(
    combination = combo,
    dose_delivered = dose_canonical, # exact — no over-delivery
    dose_canonical = dose_canonical,
    dose_unit_canon = dose_unit_canon,
    scale = 1,
    cost_prorata = cost,
    cost_whole = cost,
    total_items = frac,
    notes = notes,
    medicine_root = medicine_root,
    preparation_group = preparation_group,
    preparation_label = preparation_label,
    objective = objective,
    group_df = group_df
  )
}


# ── Pack-level optimisation (can_split = FALSE, solid forms) ──────────────────

# Runs the DP with whole-pack coins. One DP unit = one pack of a given AMPP.
# Coin dose  = per_item_dose × pack_size  (e.g. 500 mg × 28 = 14,000 mg)
# Coin cost  = pack_price_pence
# total_items in the result = number of packs dispensed.
.optimise_group_packs <- function(
  group_df,
  dose_canonical,
  dose_unit_canon,
  objective,
  medicine_root,
  preparation_group,
  preparation_label,
  policy_exempt = FALSE
) {
  pack_df <- .build_pack_df(group_df)

  # One DP coin per unique pack_dose. The coin price is the cheapest (or,
  # when objective is "most_expensive", the dearest) priced pack at that
  # pack_dose level.
  pack_doses <- sort(unique(pack_df$pack_dose[
    !is.na(pack_df$pack_dose) & pack_df$pack_dose > 0
  ]))
  if (length(pack_doses) == 0) {
    return(NULL)
  }

  is_max <- identical(objective, "most_expensive")

  # For most_expensive we seed the DP with the dearest pack per pack_dose and
  # later reconstruct with the dearest AMPP; for the other objectives we keep
  # the cheapest-per-pack_dose behaviour.
  price_per_pack_dose <- vapply(
    pack_doses,
    function(d) {
      rows <- pack_df[
        !is.na(pack_df$pack_dose) &
          pack_df$pack_dose == d &
          !is.na(pack_df$pack_price_pence),
        ,
        drop = FALSE
      ]
      if (nrow(rows) == 0) {
        return(NA_real_)
      }
      if (is_max) {
        max(rows$pack_price_pence, na.rm = TRUE)
      } else {
        min(rows$pack_price_pence, na.rm = TRUE)
      }
    },
    numeric(1)
  )

  scale <- .pick_scale_safe(pack_doses, dose_canonical)
  strengths_int <- as.integer(round(pack_doses * scale))
  dose_int <- as.integer(round(dose_canonical * scale))

  if (dose_int <= 0) {
    return(NULL)
  }
  max_strength <- max(strengths_int)
  max_over <- max_strength

  if ((dose_int + max_over + 1L) > 5e6) {
    cli::cli_warn(
      "Dose DP table for group {.val {preparation_label}} would exceed 5,000,000 cells; skipping."
    )
    return(NULL)
  }

  dp <- .dose_dp(strengths_int, price_per_pack_dose, dose_int, max_over)
  best <- if (is_max) {
    .best_target_max(dp, dose_int, max_over)
  } else {
    .best_target(dp, dose_int, max_over, objective)
  }
  if (is.null(best)) {
    return(NULL)
  }

  counts <- .reconstruct(best$back, strengths_int, best$t)
  if (is.null(counts)) {
    return(NULL)
  }

  combo_rows <- list()
  cost_whole <- 0
  price_fallback <- FALSE
  notes <- character()

  for (i in seq_along(pack_doses)) {
    if (counts[i] == 0L) {
      next
    }
    d <- pack_doses[i]
    rows <- pack_df[
      !is.na(pack_df$pack_dose) & pack_df$pack_dose == d,
      ,
      drop = FALSE
    ]

    # Pick the cheapest / most expensive priced pack for this pack_dose,
    # mirroring the objective used to seed the DP.
    priced <- rows[!is.na(rows$pack_price_pence), , drop = FALSE]
    if (nrow(priced) == 0) {
      chosen <- rows[1, , drop = FALSE]
      subtotal_whole <- NA_real_
    } else {
      pick <- if (is_max) which.max else which.min
      chosen <- priced[pick(priced$pack_price_pence), , drop = FALSE]
      subtotal_whole <- chosen$pack_price_pence * counts[i]
    }

    if (isTRUE(chosen$price_fallback)) {
      price_fallback <- TRUE
    }

    packs_to_buy <- as.integer(counts[i])

    combo_rows[[length(combo_rows) + 1L]] <- tibble::tibble(
      medicine = chosen$medicine,
      ampp_name = chosen$ampp_name,
      vmpp_snomed_code = chosen$vmpp_snomed_code,
      ampp_snomed_code = chosen$ampp_snomed_code,
      strength_canonical = chosen$strength_canonical,
      strength_unit = chosen$strength_unit_canon,
      per_item_dose = chosen$per_item_dose,
      per_item_dose_unit = dose_unit_canon,
      count = packs_to_buy, # packs bought
      pack_size = chosen$pack_size,
      packs_to_buy = packs_to_buy,
      pack_price_pence = chosen$pack_price_pence,
      per_item_price_pence = chosen$per_item_price_pence,
      # In pack mode pro-rata cost is meaningless; set equal to whole-pack.
      subtotal_prorata_pence = subtotal_whole,
      subtotal_whole_pack_pence = subtotal_whole
    )

    cost_whole <- cost_whole +
      (if (is.na(subtotal_whole)) 0 else subtotal_whole)
  }

  combination <- dplyr::bind_rows(combo_rows)
  dose_delivered <- best$t / scale
  over_amount <- dose_delivered - dose_canonical

  if (over_amount > 0) {
    notes <- c(notes, "over-delivery")
  }
  if (policy_exempt) {
    notes <- c(notes, "over-delivery-policy-not-applied")
  }
  if (price_fallback) {
    notes <- c(notes, "price-field-fallback")
  }
  notes <- c(notes, "no-pack-splitting")
  if (nrow(combination) > 0) {
    notes <- c(
      notes,
      if (is_max) "most-expensive-pack-per-dose" else "cheapest-pack-per-dose"
    )
  }

  # total_items = packs dispensed (the discrete units in a community setting).
  total_packs <- as.integer(sum(combination$packs_to_buy, na.rm = TRUE))

  .assemble_result(
    combination = combination,
    dose_delivered = dose_delivered,
    dose_canonical = dose_canonical,
    dose_unit_canon = dose_unit_canon,
    scale = scale,
    cost_prorata = cost_whole, # pack mode: prorata == whole
    cost_whole = cost_whole,
    total_items = total_packs,
    notes = notes,
    medicine_root = medicine_root,
    preparation_group = preparation_group,
    preparation_label = preparation_label,
    objective = objective,
    group_df = group_df
  )
}

# ── Shared result assembler ───────────────────────────────────────────────────

.assemble_result <- function(
  combination,
  dose_delivered,
  dose_canonical,
  dose_unit_canon,
  scale, # kept for documentation; dose_delivered already converted
  cost_prorata,
  cost_whole,
  total_items,
  notes,
  medicine_root,
  preparation_group,
  preparation_label,
  objective,
  group_df
) {
  over_delivery <- dose_delivered - dose_canonical
  # Exactness is reported as a flag rather than left to the caller comparing a
  # floating-point difference to zero.
  dose_exact <- abs(over_delivery) <= 1e-9 * max(1, dose_canonical)
  if (dose_exact) {
    notes <- c(notes, "exact-dose")
  }
  # Report the price field of the AMPPs actually chosen (matched back to the
  # group by AMPP code), so price_field_used is consistent with the pack prices
  # shown in each combination row rather than reflecting some other AMPP in the
  # group.
  chosen_pf <- group_df$price_field_used[
    match(combination$ampp_snomed_code, group_df$ampp_snomed_code)
  ]
  price_field_used <- chosen_pf[!is.na(chosen_pf)][1]

  tibble::tibble(
    medicine_root = medicine_root,
    preparation_group = preparation_group,
    preparation_label = preparation_label,
    objective = objective,
    dose_requested = dose_canonical,
    dose_unit = dose_unit_canon,
    dose_delivered = dose_delivered,
    dose_delivered_unit = dose_unit_canon,
    over_delivery = over_delivery,
    dose_exact = dose_exact,
    total_items = as.numeric(total_items),
    cost_prorata_pence = if (any(is.na(combination$subtotal_prorata_pence))) {
      NA_real_
    } else {
      cost_prorata
    },
    cost_whole_pack_pence = if (
      any(is.na(combination$subtotal_whole_pack_pence))
    ) {
      NA_real_
    } else {
      cost_whole
    },
    price_field_used = price_field_used,
    combination = list(structure(
      combination,
      class = c("dmd_dose_combination", class(combination))
    )),
    notes = paste(unique(notes), collapse = "; ")
  )
}
