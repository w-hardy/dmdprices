# Changelog

All notable changes to `dmdprices` will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## dmdprices 0.2.0

### Added

- `dmd_load()` — loads a more recent dm+d release from a local `dmdDataLoader`
  CSV directory.
- `dmd_price_lookup()` — queries the pricing table by medicine name with
  `"partial"`, `"exact"`, and `"fuzzy"` match methods.
- Bundled `dmd_master` dataset (Week 34 2025, 14 August 2025) for zero-setup
  use.
- Output columns mirror the NHS Drug Tariff Part VIIIA CSV format.
