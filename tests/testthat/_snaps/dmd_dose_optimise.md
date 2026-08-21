# string dose with extra dose_unit warns and uses string unit

    Code
      out <- dmd_dose_optimise("metformin", dose = "900 mg", dose_unit = "g", db = db,
        preparation = "tablet|none|oral")
    Condition
      Warning:
      Parsed unit "mg" from the `dose` string differs from supplied `dose_unit` "g"; using the value from `dose`.

# unparseable dose string gives informative error

    Code
      dmd_dose_optimise("metformin", dose = "lots", db = db)
    Condition
      Error in `.parse_dose_string()`:
      ! `dose` could not be parsed as a dose string: "lots".
      i Expected a number followed by a unit, e.g. "250 mg", "0.25 g", "500mcg".

# can_split must be a single logical

    Code
      dmd_dose_optimise("metformin", dose = 500, dose_unit = "mg", db = db,
        can_split = "yes")
    Condition
      Error in `dmd_dose_optimise()`:
      ! `can_split` must be a single logical value (TRUE or FALSE).

# objective = 'both' triggers a deprecation warning

    Code
      out <- dmd_dose_optimise("metformin", dose = 1000, dose_unit = "mg", db = db,
        preparation = "tablet|none|oral", objective = "both")
    Condition
      Warning:
      `objective = "both"` was deprecated in dmdprices 0.6.0.
      i Use objective = c("cheapest", "min_items") or objective = "all" instead.

# objective = character(0) errors with a helpful message

    Code
      dmd_dose_optimise("metformin", dose = 500, dose_unit = "mg", db = db,
        objective = character(0))
    Condition
      Error in `dmd_dose_optimise()`:
      ! `objective` must contain at least one of "cheapest", "min_items", "most_expensive" (or "all").

---

    Code
      dmd_dose_cost("metformin", dose = 500, dose_unit = "mg", db = db, objective = character(
        0))
    Condition
      Error in `dmd_dose_cost()`:
      ! `objective` must contain at least one of "cheapest", "min_items", "most_expensive" (or "all").

# objective = 'bogus' errors via match.arg

    Code
      dmd_dose_optimise("metformin", dose = 500, dose_unit = "mg", db = db,
        objective = "bogus")
    Condition
      Error in `match.arg()`:
      ! 'arg' should be one of "cheapest", "min_items", "most_expensive"

# compound products are skipped with a warning

    Code
      res <- dmd_dose_optimise("co-codamol", dose = 8, dose_unit = "mg", db = compound_db)
    Condition
      Warning:
      1 unsupported compound product skipped during dose optimisation.

---

    Code
      cost <- dmd_dose_cost("co-codamol", dose = 8, dose_unit = "mg", db = compound_db)
    Condition
      Warning:
      1 unsupported compound product skipped during dose optimisation.

---

    Code
      range <- dmd_dose_cost_range("co-codamol", dose = 8, dose_unit = "mg", db = compound_db)
    Condition
      Warning:
      1 unsupported compound product skipped during dose optimisation.

# ingredient targeting doses combination products by one ingredient

    Code
      res_default <- dmd_dose_optimise("co", dose = 60, dose_unit = "mg", db = db)
    Condition
      Warning:
      2 unsupported compound products skipped during dose optimisation.

# ingredient targeting warns and returns nothing without VPI data

    Code
      res <- dmd_dose_optimise("metformin", dose = 500, dose_unit = "mg", db = db_no_vpi,
        ingredient = "metformin")
    Condition
      Warning:
      No ingredient data available to target "metformin".
      i Load a dm+d release that includes the VPI extract with `dmd_load()`, or rebuild the bundled data.

# ingredient argument is validated

    Code
      dmd_dose_optimise("metformin", dose = 500, ingredient = c("a", "b"))
    Condition
      Error in `.validate_ingredient()`:
      ! `ingredient` must be NULL or a single non-empty string.

---

    Code
      dmd_dose_optimise("metformin", dose = 500, ingredient = "")
    Condition
      Error in `.validate_ingredient()`:
      ! `ingredient` must be NULL or a single non-empty string.

# ambiguous ingredient term warns and uses all matches

    Code
      out <- dmd_dose_optimise("sodium", dose = 100, dose_unit = "mg", db = db,
        ingredient = "sodium", objective = "cheapest")
    Condition
      Warning:
      `ingredient` "sodium" matched 2 distinct ingredients: "Sodium chloride" and "Sodium lactate".
      i All matches are used; supply a more specific name to narrow this.

# targeting a non-mass ingredient warns and yields no dose

    Code
      res <- dmd_dose_optimise("Sodium iodide", dose = 1, dose_unit = "mg", db = db,
        ingredient = "Sodium iodide")
    Condition
      Warning:
      1 candidate for "Sodium iodide" has a non-mass strength and cannot be dosed by mass; skipped.
      i Strength unit: "gbq".
      Warning:
      No candidates matched the requested dose unit ("mg") after parsing; returning empty result.

# compound rows are skipped while supported rows still optimise

    Code
      res <- dmd_dose_optimise("testdrug", dose = 100, dose_unit = "mg", db = mixed_db,
        objective = "cheapest")
    Condition
      Warning:
      1 unsupported compound product skipped during dose optimisation.

# preparation filter that matches no group warns and returns empty

    Code
      res <- dmd_dose_optimise("metformin", dose = 500, dose_unit = "mg", db = db,
        preparation = "nonexistent-preparation-xyz")
    Condition
      Warning:
      No candidates remain after filtering to preparation "nonexistent-preparation-xyz".

