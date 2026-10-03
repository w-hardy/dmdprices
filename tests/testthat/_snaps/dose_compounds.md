# packs are skipped with a multi-product pack warning

    Code
      res <- dmd_dose_optimise("s and ", dose = 50, dose_unit = "mg", db = db,
        objective = "cheapest")
    Condition
      Warning:
      2 multi-product packs skipped during dose optimisation.
      x Multi-strength pack: "Danicopan 50mg tablets and Danicopan 100mg tablets".
      x Co-pack of different products: "Tixagevimab 150mg/1.5ml solution for injection vials and Cilgavimab 150mg/1.5ml solution for injection vials".
      i A pack holding several products has no single per-item strength; cost its products individually.

