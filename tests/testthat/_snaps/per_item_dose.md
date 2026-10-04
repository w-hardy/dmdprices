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

