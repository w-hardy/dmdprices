# exact match returns nothing for non-matching query

    Code
      res <- dmd_price_lookup("aspirin 75mg tablets", db = db, method = "exact")
    Condition
      Warning:
      No medicines found matching "aspirin 75mg tablets" with method = "exact".

# dmd_price_lookup() errors on non-dmd_db / non-tibble input

    Code
      dmd_price_lookup("metformin", db = "bad")
    Condition
      Error in `dmd_price_lookup()`:
      ! `db` must be a <dmd_db> object or a tibble with a `medicine` column.
      i Use the bundled `dmd_master` dataset or create a <dmd_db> with `dmd_load()`.

# dmd_price_lookup() errors on empty query

    Code
      dmd_price_lookup("  ", db = db)
    Condition
      Error in `dmd_price_lookup()`:
      ! `query` must be a non-empty character string.

