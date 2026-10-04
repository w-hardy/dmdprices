# the warning text names the products and the reason

    Code
      res <- dmd_dose_optimise("spray", dose = 4.5, dose_unit = "mg", db = db,
        objective = "cheapest", over_delivery = "minimise")
    Condition
      Warning:
      3 products skipped during dose optimisation: the number of doses per pack is unknown.
      x E.g. "Flurbiprofen 2.92mg/actuation oromucosal spray sugar free", "Lidocaine 10mg/dose spray sugar free", and "Nicotine 1mg/dose oromucosal spray sugar free".
      i The strength is per dose or actuation but the pack is measured in ml or g, or the pack and the strength are in different units, and the dm+d records no dose count for such packs. Cost them as whole packs with `dmd_price_lookup()`.

