# Dose combination optimisation helpers for dmd_dose_optimise().
# All functions here are internal.

# ── Integer scaling ───────────────────────────────────────────────────────────

# Safe wrapper around .pick_scale() that applies two additional caps so that
# dose_canonical * s never overflows as.integer() and stays within the DP
# table hard cap (dp_cap cells).  Without this, a repeating-decimal strength
# (e.g. 1400 mg / 11.7 ml = 119.658...) can push the scale to 1e7, causing
# 900 * 1e7 = 9e9 > .Machine$integer.max, which coerces to NA_integer_ and
# triggers "missing value where TRUE/FALSE needed" in .optimise_group().

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

# ── Pro-rata per-item price ───────────────────────────────────────────────────

.per_item_price <- function(pack_price, pack_size) {
  if (is.na(pack_price) || is.na(pack_size) || pack_size <= 0) {
    return(NA_real_)
  }
  pack_price / pack_size
}

# ── Whole-pack cost for one strength ──────────────────────────────────────────

# Given a list of (items_per_pack, pack_price) AMPPs and a required item
# count, find the cheapest single-AMPP whole-pack solution and return the
# chosen AMPP index, packs_to_buy, and total cost. Returns NA fields if none
# priced.
.whole_pack_cheapest <- function(ampps, count_needed) {
  if (count_needed <= 0) {
    return(list(ampp_row = NA_integer_, packs = 0L, cost = 0))
  }
  pack_sizes <- ampps$items_per_pack
  pack_prices <- ampps$pack_price_pence
  ok <- !is.na(pack_sizes) & !is.na(pack_prices) & pack_sizes > 0
  if (!any(ok)) {
    return(list(ampp_row = NA_integer_, packs = NA_integer_, cost = NA_real_))
  }
  idx <- which(ok)
  packs <- ceiling(count_needed / pack_sizes[idx])
  costs <- packs * pack_prices[idx]
  best <- which.min(costs)
  list(
    ampp_row = idx[best],
    packs = as.integer(packs[best]),
    cost = as.numeric(costs[best])
  )
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
# Returns a list with `min_items`, `min_cost`, `items_back`, `cost_back`
# vectors indexed 1..(dose_int + max_over + 1) — index = t + 1.
.dose_dp <- function(strengths_int, per_item_price, dose_int, max_over) {
  T <- as.integer(dose_int + max_over)
  INF <- Inf

  min_items <- rep(INF, T + 1L)
  min_cost <- rep(INF, T + 1L)
  items_back <- rep(NA_integer_, T + 1L)
  cost_back <- rep(NA_integer_, T + 1L)

  min_items[1] <- 0
  min_cost[1] <- 0

  # Replace NA prices with Inf so they never win min_cost but still allow
  # min_items reconstruction.
  price_for_cost <- per_item_price
  price_for_cost[is.na(price_for_cost)] <- Inf

  for (t in 1L:T) {
    for (i in seq_along(strengths_int)) {
      s <- strengths_int[i]
      if (s > t) {
        next
      }
      prev_idx <- t - s + 1L

      cand_items <- min_items[prev_idx] + 1
      if (cand_items < min_items[t + 1L]) {
        min_items[t + 1L] <- cand_items
        items_back[t + 1L] <- i
      }

      cand_cost <- min_cost[prev_idx] + price_for_cost[i]
      if (cand_cost < min_cost[t + 1L]) {
        min_cost[t + 1L] <- cand_cost
        cost_back[t + 1L] <- i
      }
    }
  }

  list(
    min_items = min_items,
    min_cost = min_cost,
    items_back = items_back,
    cost_back = cost_back
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

# ── Pick the best target t for each objective ────────────────────────────────

.best_target <- function(dp, dose_int, max_over, objective) {
  ts <- dose_int:(dose_int + max_over)
  idx <- ts + 1L
  items_vec <- dp$min_items[idx]
  cost_vec <- dp$min_cost[idx]

  feasible <- is.finite(items_vec)
  if (!any(feasible)) {
    return(NULL)
  }

  if (objective == "min_items") {
    # Smallest items; tie-break by smallest over-delivery, then cost.
    cand <- which(items_vec == min(items_vec[feasible]))
    cand <- cand[cand %in% which(feasible)]
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
    # Tie-break: fewer items, then smaller over-delivery.
    it <- items_vec[cand]
    sub <- cand[which(it == min(it))]
    if (length(sub) > 1) {
      over <- ts[sub] - dose_int
      sub <- sub[which.min(over)]
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
# objective: "cheapest" or "min_items".
# medicine_root, preparation_group, preparation_label: group identifiers.
# can_split: logical. FALSE = whole packs must be dispensed for solid forms;
#   concentration-based preparations are always whole-container regardless.
.optimise_group <- function(
  group_df,
  dose_canonical,
  dose_unit_canon,
  objective,
  medicine_root,
  preparation_group,
  preparation_label,
  can_split = TRUE
) {
  # The DP operates on per-item canonical doses: for tablets/capsules this
  # is the strength itself; for liquids it is concentration × pack_size so
  # one "item" corresponds to one container.
  strengths <- sort(unique(group_df$per_item_dose))
  strengths <- strengths[!is.na(strengths) & strengths > 0]
  if (length(strengths) == 0) {
    return(NULL)
  }

  # Detect whether every row in this group is concentration-based.
  # Concentration items (liquids, inhalers, vials) are inherently unsplittable
  # because one "item" already equals one whole container.
  all_concentration <- all(!is.na(group_df$denominator_unit))

  # When can_split = FALSE we still run the DP with per-item (pro-rata) prices,
  # because the DP cannot easily accommodate pack-size constraints. The
  # reported *cost* is then taken from the whole-pack totals, which is the
  # binding cost for community dispensing. For concentration-based preparations
  # the two costs are identical (items_per_pack == 1), so this distinction
  # only matters for solid-form preparations.

  # Cheapest per-item price per per_item_dose level.
  cheapest_per_strength <- vapply(
    strengths,
    function(s) {
      rows <- group_df[group_df$per_item_dose == s, , drop = FALSE]
      if (all(is.na(rows$per_item_price_pence))) {
        return(NA_real_)
      }
      min(rows$per_item_price_pence, na.rm = TRUE)
    },
    numeric(1)
  )

  scale <- .pick_scale_safe(strengths, dose_canonical)
  strengths_int <- as.integer(round(strengths * scale))
  dose_int <- as.integer(round(dose_canonical * scale))

  if (dose_int <= 0) {
    return(NULL)
  }
  # Searching up to `max_strength` beyond the target guarantees we find a
  # reachable t whenever one exists (the DP is unbounded knapsack).
  max_strength <- max(strengths_int)
  max_over <- max_strength

  # Hard cap for safety.
  if ((dose_int + max_over + 1L) > 5e6) {
    cli::cli_warn(
      "Dose DP table for group {.val {preparation_label}} would exceed 5,000,000 cells; skipping."
    )
    return(NULL)
  }

  dp <- .dose_dp(strengths_int, cheapest_per_strength, dose_int, max_over)
  best <- .best_target(dp, dose_int, max_over, objective)
  if (is.null(best)) {
    return(NULL)
  }

  counts <- .reconstruct(best$back, strengths_int, best$t)
  if (is.null(counts)) {
    return(NULL)
  }

  # Build the per-strength combination, using the cheapest AMPP row per
  # strength for pro-rata and the cheapest whole-pack AMPP for whole-pack.
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

    # Pro-rata chosen AMPP: cheapest per-item.
    priced <- rows[!is.na(rows$per_item_price_pence), , drop = FALSE]
    if (nrow(priced) == 0) {
      # Unpriced — record with NA costs.
      chosen <- rows[1, , drop = FALSE]
      subtotal_prorata <- NA_real_
    } else {
      chosen <- priced[which.min(priced$per_item_price_pence), , drop = FALSE]
      subtotal_prorata <- chosen$per_item_price_pence * counts[i]
    }

    # Whole-pack: pick cheapest AMPP for this strength (from priced rows).
    wp_rows <- if (nrow(priced) > 0) priced else rows
    wp <- .whole_pack_cheapest(wp_rows, counts[i])
    if (is.na(wp$cost)) {
      wp_ampp <- rows[1, , drop = FALSE]
      packs_to_buy <- NA_integer_
      subtotal_whole <- NA_real_
    } else {
      wp_ampp <- wp_rows[wp$ampp_row, , drop = FALSE]
      packs_to_buy <- wp$packs
      subtotal_whole <- wp$cost
    }

    if (isTRUE(chosen$price_fallback) || isTRUE(wp_ampp$price_fallback)) {
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
      pack_price_pence = wp_ampp$pack_price_pence,
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
  over_delivery <- dose_delivered - dose_canonical

  if (over_delivery > 0) {
    notes <- c(notes, "over-delivery")
  }
  if (price_fallback) {
    notes <- c(notes, "price-field-fallback")
  }
  if (!can_split && !all_concentration) {
    notes <- c(notes, "no-pack-splitting")
  }
  if (nrow(combination) > 0) {
    notes <- c(notes, "cheapest-AMPP-per-strength")
  }

  total_items <- sum(combination$count)
  price_field_used <- unique(group_df$price_field_used)
  price_field_used <- price_field_used[!is.na(price_field_used)][1]

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
    total_items = as.integer(total_items),
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
