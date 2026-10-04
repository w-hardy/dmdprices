# a container of unknown size returns no row and a classed warning

    Code
      res <- dmd_dose_optimise("Morphine", dose = 10, dose_unit = "mg", db = db,
        preparation = "injection", objective = "cheapest")
    Condition
      Warning:
      1 product skipped during dose optimisation: the amount of drug per container is unknown.
      x E.g. "Morphine 10mg/ml solution for injection ampoules".
      i The strength is per ml or per g, but the name states neither the container's size ("500ml bags", "0.25g unit dose") nor a numeric strength denominator ("10mg/1ml"), so the dose in one vial, bag, bottle or unit dose cannot be derived. Cost them as whole packs with `dmd_price_lookup()`.

