# Interactive Apps

Three Shiny apps are available for interactive use without writing any R
code. All three apps can be accessed online (hosted on Posit Connect
Cloud), and all three can be run locally if you have `dmdprices`
installed.

------------------------------------------------------------------------

## dm+d Price Lookup

Search for medicine prices from the bundled dm+d dataset by name, with
partial, exact, or fuzzy matching.

**Run locally:**

``` r

dmdprices::run_dmd_price_lookup()
```

**Online (hosted):**

Your browser does not support iframes. [Open the app
directly.](https://w-hardy-dmd-price-lookup.share.connect.posit.cloud)

------------------------------------------------------------------------

## dm+d Dose Optimiser

Find dose-delivering AMPP combinations by cheapest, minimum-items, or
most-expensive objective.

**Run locally:**

``` r

dmdprices::run_dmd_dose_optimise()
```

**Online (hosted):**

Your browser does not support iframes. [Open the app
directly.](https://w-hardy-dmd-dose-optimise.share.connect.posit.cloud)

------------------------------------------------------------------------

## NHS CII Cost Adjuster

Inflate or deflate a cost between NHS financial years using the PSSRU
NHS Cost Inflation Index.

**Run locally:**

``` r

dmdprices::run_inflate_nhscii()
```

**Online (hosted):**

Your browser does not support iframes. [Open the app
directly.](https://w-hardy-inflate-nhscii.share.connect.posit.cloud)

------------------------------------------------------------------------

## Warnings and errors

All three apps surface the underlying package’s warnings and errors
directly in the interface as coloured callout boxes shown above the
results:

- **Warnings** (yellow) report non-fatal notices from functions such as
  [`dmd_dose_optimise()`](https://w-hardy.github.io/dmdprices/reference/dmd_dose_optimise.md)
  — for example when unsupported compound products are skipped, an
  ingredient name is ambiguous, or a strength is recorded in a non-mass
  unit. Results are still shown alongside the warning.
- **Errors** (red) report a failed call — for example an invalid
  financial year in the NHS CII adjuster or a malformed query — and
  explain what to change.

The same notices are the `cli` warnings and errors you would see when
calling the functions directly in R, so the apps and the package behave
consistently.

------------------------------------------------------------------------

## Deploying your own instance

All three apps are included in the package under `inst/shiny/` and can
be deployed to any Shiny-compatible host:

``` r

# Deploy to Posit Connect Cloud (free tier)
rsconnect::deployApp(
  appDir    = system.file("shiny", "dmd_price_lookup", package = "dmdprices"),
  appName   = "dmd-price-lookup",
  appTitle  = "dm+d Price Lookup"
)

rsconnect::deployApp(
  appDir    = system.file("shiny", "dmd_dose_optimise", package = "dmdprices"),
  appName   = "dmd-dose-optimise",
  appTitle  = "dm+d Dose Optimiser"
)

rsconnect::deployApp(
  appDir    = system.file("shiny", "inflate_nhscii", package = "dmdprices"),
  appName   = "inflate-nhscii",
  appTitle  = "NHS CII Cost Adjuster"
)
```

## Updating an existing deployment

The apps do **not** bundle their own copy of the data. Each `app.R`
calls [`library(dmdprices)`](https://w-hardy.github.io/dmdprices/), and
the app `DESCRIPTION` files declare `Remotes: w-hardy/dmdprices`, so the
prices, NHS CII rates, and app behaviour all come from the installed
`dmdprices` package. **To refresh a live app to a newer release of the
package, you redeploy it** — there is no separate data upload step.

``` r

# 1. Install the version you want the app to serve (default branch = main)
remotes::install_github("w-hardy/dmdprices")

# 2. Redeploy with the SAME appName to update the existing app in place
#    (the share URL does not change). forceUpdate avoids the overwrite prompt.
rsconnect::deployApp(
  appDir      = system.file("shiny", "dmd_price_lookup", package = "dmdprices"),
  appName     = "dmd-price-lookup",
  appTitle    = "dm+d Price Lookup",
  forceUpdate = TRUE
)
# ...repeat for "dmd-dose-optimise" and "inflate-nhscii".
```

[`system.file()`](https://rdrr.io/r/base/system.file.html) resolves to
your *locally installed* `dmdprices`, so run step 1 first (or pass a
working-tree path such as `appDir = "inst/shiny/..."`).

**Previewing unreleased changes.** `Remotes: w-hardy/dmdprices` installs
from the default branch (`main`). To preview work that is still on a
feature branch, install that branch before redeploying:

``` r

remotes::install_github("w-hardy/dmdprices@develop")
```

**Dependencies.** The apps do not ship a pinned `manifest.json` or
`renv.lock`. `rsconnect::deployApp()` detects each app’s R package
dependencies at deploy time and Posit Connect Cloud installs them,
resolving versions against the platform’s current R. This avoids
freezing package versions to an R release that the platform may later
upgrade past (which can force failing source builds of pinned
dependencies).

After redeploying, confirm each app’s footer shows the expected dm+d
release and PSSRU manual, that a brand search (e.g. `"Buvidal"`) returns
results, and that the NHS CII adjuster offers the latest financial year.

------------------------------------------------------------------------

## Data attribution

**dm+d Price Lookup** and **dm+d Dose Optimiser** use the NHS Dictionary
of Medicines and Devices (dm+d), Week 15 2026 release, published by the
NHS Business Services Authority (NHSBSA). © Crown copyright. Licensed
under the [Open Government Licence
v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).

**NHS CII Cost Adjuster** uses inflation rates from Jones et al. (2026),
*Unit Costs of Health and Social Care 2025 Manual*, published by the
Personal Social Services Research Unit (University of Kent) & Centre for
Health Economics (University of York).
<https://doi.org/10.22024/UniKent/01.02.115569>

Licensed under [CC BY-NC-SA
4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

------------------------------------------------------------------------

## Reporting issues

If you encounter a problem with any app or the underlying package
functions, please open an issue on the [GitHub issues
tracker](https://github.com/w-hardy/dmdprices/issues).
