# dmdprices: Look Up Medicine Prices from the NHS dm+d

`dmdprices` provides tools for querying NHS medicine prices and
adjusting costs for inflation:

## Details

- [`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md)
  — search the bundled dm+d dataset by medicine name.

- [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
  — load a more recent dm+d release from a local `dmdDataLoader` CSV
  directory.

- [`nhscii()`](https://w-hardy.github.io/dmdprices/reference/nhscii.md)
  — compute NHS Cost Inflation Index factors between financial years.

- [`inflate_nhscii()`](https://w-hardy.github.io/dmdprices/reference/inflate_nhscii.md)
  — adjust costs using NHS CII rates.

- [`run_dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/run_dmd_price_lookup.md)
  — launch the price lookup Shiny app locally.

- [`run_inflate_nhscii()`](https://w-hardy.github.io/dmdprices/reference/run_inflate_nhscii.md)
  — launch the cost adjuster Shiny app locally.

### Typical workflow

    library(dmdprices)

    # Search bundled data — no setup needed
    dmd_price_lookup("metformin")

    # Adjust a cost for inflation
    inflate_nhscii(100, "2019/20", "2023/24")

    # Load a more recent dm+d release
    db <- dmd_load("path/to/dmdDataLoader")
    dmd_price_lookup("metformin", db = db)

## See also

<https://w-hardy.github.io/dmdprices/>

## Author

**Maintainer**: Will Hardy <w.hardy@bangor.ac.uk>
