# as_dmd_db() errors without a medicine column

    Code
      as_dmd_db(df)
    Condition
      Error in `as_dmd_db()`:
      ! `master` must have a medicine column.
      i Every <dmd_db> is searched by medicine name.

# as_dmd_db() errors when no usable price is present

    Code
      as_dmd_db(no_price)
    Condition
      Error in `as_dmd_db()`:
      ! `master` has no usable prices.
      x Both basic_price and nhs_indicative_price are entirely missing.
      i Supply at least one price column, in pence.

---

    Code
      as_dmd_db(all_na)
    Condition
      Error in `as_dmd_db()`:
      ! `master` has no usable prices.
      x Both basic_price and nhs_indicative_price are entirely missing.
      i Supply at least one price column, in pence.

# as_dmd_db() warns once about degraded functionality

    Code
      db <- as_dmd_db(df)
    Condition
      Warning:
      Built a <dmd_db> with reduced functionality:
      * No ampp_name: brand-name search is disabled (`dmd_price_lookup()` matches the generic name only).
      * No ampp_snomed_code: pack identifiers are `NA` (`dmd_master_info()` reports 0 AMPPs).
      * Missing pack_size and unit columns: dose optimisation is unavailable or degraded.

# as_dmd_db() coerces character pack_size and flags unparseable values

    Code
      db <- as_dmd_db(df)
    Condition
      Warning:
      Built a <dmd_db> with reduced functionality:
      * 1 pack_size value could not be coerced to numeric and became `NA`.

