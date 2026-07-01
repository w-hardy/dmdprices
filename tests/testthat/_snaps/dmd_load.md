# dmd_load() errors informatively on bad path

    Code
      dmd_load("nonexistent/path")
    Condition
      Error in `dmd_load()`:
      ! 'nonexistent/path/csv' does not exist.
      i `path` should be the `dmdDataLoader` folder that contains a `csv/` subdirectory.

# dmd_load() errors when no path supplied and option unset

    Code
      dmd_load()
    Condition
      Error in `dmd_load()`:
      ! No path supplied.
      i Provide `path` or set `options(dmdprices.path = \"...\")`

# print.dmd_db summarises the pricing hierarchy

    Code
      print(.fake_dose_db())
    Message
      v dm+d database loaded at 2025-08-08 09:00
      * 12 VMPs | 12 VMPPs | 12 AMPPs
      * 11 Drug Tariff prices | 12 NHS Indicative Prices

# print.dmd_db reports ingredient/combination counts when present

    Code
      print(.fake_ingredient_db())
    Message
      v dm+d database loaded at 2025-08-08 09:00
      * 3 VMPs | 3 VMPPs | 3 AMPPs
      * 3 Drug Tariff prices | 3 NHS Indicative Prices
      * 2 ingredients | 2 combination VMPs

