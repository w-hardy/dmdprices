# one unresolved-dose warning per call names every dropped group

    Code
      res <- dmd_dose_optimise("finedrug", dose = 6000.125, dose_unit = "mg", db = .fake_unresolvable_db(),
      over_delivery = "minimise")
    Condition
      Warning:
      The requested dose could not be resolved for 2 preparation groups; they return no row.
      * "capsule (oral)" and "tablet (oral)": the strengths cannot be represented at the precision the group's dose table allows for this dose.
      i Pass `quiet = TRUE` to silence this.

