# Changelog

## dmdprices (development version)

### Added

- [`nhscii()`](https://w-hardy.github.io/dmdprices/reference/nhscii.md)
  — compute NHS Cost Inflation Index factors between financial years.
- [`inflate_nhscii()`](https://w-hardy.github.io/dmdprices/reference/inflate_nhscii.md)
  — adjust costs using NHS CII rates.
- Both functions support “pay_and_prices”, “pay”, and “prices” indices
  covering 2015/16–2023/24 (provisional).

## dmdprices 0.2.0

### Added

- [`dmd_load()`](https://w-hardy.github.io/dmdprices/reference/dmd_load.md)
  — loads a more recent dm+d release from a local `dmdDataLoader` CSV
  directory.
- [`dmd_price_lookup()`](https://w-hardy.github.io/dmdprices/reference/dmd_price_lookup.md)
  — queries the pricing table by medicine name with “partial”, “exact”,
  and “fuzzy” match methods.
- Bundled `dmd_master` dataset (Week 34 2025, 14 August 2025) for
  zero-setup use.
- Output columns mirror the NHS Drug Tariff Part VIIIA CSV format.
