# a VPI denominator with no canonical unit is skipped with a warning naming it

    Code
      targeted <- .targeted("Expatch transdermal", "Expatchine")
    Condition
      Warning:
      1 candidate for "Expatchine" has a non-mass strength and cannot be dosed by mass; skipped.
      i Strength denominator unit with no canonical form: "hour".

# the non-mass warning names a bad numerator and a bad denominator together

    Code
      targeted <- .targeted("Expatch", "Expatchine")
    Condition
      Warning:
      2 candidates for "Expatchine" have a non-mass strength and cannot be dosed by mass; skipped.
      i Strength unit: "GBq".
      i Strength denominator unit with no canonical form: "hour".

# an ingredient table without the raw strength fields is refused

    Code
      .targeted("Rituximab", "Rituximab", db = canon_only)
    Condition
      Error in `.apply_ingredient_targeting()`:
      ! `ingredients` lacks the columns "strength_value", "strength_unit", "denominator_value", and "denominator_unit".
      i Ingredient targeting reads the raw dm+d VPI strength fields "strength_value", "strength_unit", "denominator_value", and "denominator_unit", as in `dmd_ingredients` and the `$ingredients` of a `dmd_load()` database; the canonical columns are not read.

