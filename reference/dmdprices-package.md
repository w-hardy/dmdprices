# dmdprices: Look Up Medicine Prices from the NHS dm+d

`dmdprices` provides two main functions:

## Details

- [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
  — reads the CSV output of the NHSBSA dm+d extract tool and builds a
  joined pricing database.

- [`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md)
  — queries that database by medicine name, returning a tibble in Drug
  Tariff Part VIIIA format.

### Typical workflow

    library(dmdprices)

    # Load once per session (or set options(dmdprices.path = "...") in .Rprofile)
    db <- dmd_load("path/to/dmdDataLoader")

    # Query
    dmd_price_lookup(db, "metformin")

## See also

Useful links:

- <https://github.com/w-hardy/dmdprices>

- Report bugs at <https://github.com/w-hardy/dmdprices/issues>

## Author

**Maintainer**: Will Hardy <w.hardy@bangor.ac.uk>
