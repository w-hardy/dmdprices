# dmdprices (development version)

## Bug fixes

- **The requested dose is authoritative: the dose functions no longer round
  it to the precision of the strengths.** `dmd_dose_optimise()`,
  `dmd_dose_cost()` and `dmd_dose_cost_range()` solve on the integer grid of
  a preparation group's strengths, and a dose with finer decimals than the
  strengths was first taken to the nearest whole unit of that grid: 2.4 mg
  against 1 mg tablets was costed as 2 mg, and 6.3 mg of eptacog alfa as
  6 mg (315,120p), with `over_delivery = "forbid"` accepting the
  under-delivering result and the no-exact and over-delivery warnings judged
  against the rounded value. The grid is now only a search space. A dose
  that no combination of the group's strengths sums to has no exact
  combination: `"forbid"` returns no row for the group (and `NA` from
  `dmd_dose_cost()`), with the usual no-exact warning, and `"minimise"` and
  `"allow"` return the smallest combination that delivers at least the dose
  (3 mg for 2.4 mg; 7 mg of eptacog alfa, 367,640p), flagged
  `dose_exact = FALSE` with the surplus in `over_delivery`. No route delivers
  less than the requested dose. Exactness, grid membership and the
  over-delivery notes share one tolerance of one part in a billion of the
  dose (never finer than a billionth of a milligram or millilitre), so a
  dose that is exact in the strengths' unit, such as 0.3 mg from three
  0.1 mg tablets or 2400 micrograms against 0.2 mg tablets, counts as exact.
  The integer scale is no longer raised for a fine dose, so the dose table
  stays as small as the strengths allow (0.25 microgram against 20 mg
  inhalers is still covered by one inhaler), and a group whose strengths the
  capped scale cannot represent is reported in the "could not be resolved"
  warning instead of being summed with rounded strengths; no product in the
  bundled release has such a strength. The "requested dose was rounded"
  warning added in 0.6.2 is removed, since nothing is rounded any more (see
  Behaviour changes).
- **Ingredient-targeted doses (`ingredient =`) applied the ingredient's
  strength to the wrong quantity.** The dm+d states an ingredient strength
  per a stated denominator quantity ("500 mg per 1 litre" for an amino acid
  in an infusion bottle, "10 mg per 1 ml" for rituximab). The dose functions
  converted the numerator to milligrams but kept the denominator as written,
  and then dosed each container as one denominator unit. A 500 ml bottle of
  Aminoplasmal 15% therefore counted 500 g of L-tyrosine rather than 250 mg,
  so `dmd_dose_cost("Aminoplasmal 15%", dose = 3, dose_unit = "g",
  ingredient = "L-Tyrosine")` costed one bottle (2,300p) and now costs
  twelve (27,600p); a 500mg/50ml rituximab vial counted 10 mg (one
  millilitre) rather than 500 mg. Every strength, parsed from a name or taken from the
  VPI data, is now brought to one convention before any arithmetic:
  canonical numerator per one canonical denominator unit (`20mg/g` is
  0.02 mg per mg, `500mg/50ml` is 10 mg per ml). The item an ingredient
  strength is applied to is the item the product's own strength would use:
  the whole pack for a single bottle or tube, or the size the name states
  for one container (see the next entry). Products costable on both paths
  now agree wherever the dm+d records the concentration exactly (375 mg of
  rituximab is 62,866p on both paths, 1200 mg of delgocitinib 59,500p);
  they still differ where the dm+d rounds a concentration (a 128mg/0.36ml
  syringe is recorded as 355.56 mg/ml, so the ingredient path sees
  128.0016 mg) or where the name's figure is the product's mass rather than
  the ingredient's (bone cement, imiquimod and kaolin sachets, progesterone
  applicators, glycerol suppositories), which the ingredient path now gets
  right: in the bundled release 221 of 26,277
  single-ingredient pack rows costable both ways still differ,
  168 of them by under 1% from such rounding. In the bundled
  release this changes the per-item dose of 14,168
  product-ingredient pairs and removes 827 (see the next two entries).
  Re-run any analysis that used `ingredient =` with an earlier version. This
  corrects the 0.6.2 notes that said results with `ingredient =` were
  unchanged by the cream fix.
- **The amount of drug in one container is read from the product name,
  never assumed to be one millilitre or one gram.** A container-count pack
  of a concentration (vials, bags, bottles, unit doses, pre-filled devices)
  was dosed per one unit of the strength's stated denominator: a 0.3 ml unit
  dose of dexamethasone 1.5mg/ml eye drops counted 1.5 mg (one millilitre)
  rather than 0.45 mg, a 2.4 ml tirzepatide 12.5mg/0.6ml device 12.5 mg
  rather than 50 mg, and, with `ingredient =`, a 500 ml bag of a strength
  recorded per litre a whole litre, and a 0.25 g unit dose of a 15mg/g eye
  drop a whole gram. The container's size is now taken from the name: a
  stated size in the strength's dimension ("500ml bags", "0.25g unit dose",
  "3ml pre-filled pens", "1litre Viaflo bags"), read from the product's own
  phrase only, so in an "and"-joined pack the other product's size does not
  count; else the strength denominator where the name states it with a
  number ("500mg/50ml", "10mg/1ml", "4mg/100microlitres", "5,000units/1litre",
  which the strength grammar now parses). A name that states neither
  ("10mg/ml ... ampoules"), or two different sizes, gives no amount, and the
  product is skipped with a warning of class
  `dmdprices_warning_unknown_container_amount` (its `medicines` field names
  them; `quiet = TRUE` does not silence it; `dmd_dose_cost_range()` shows it
  once per call), on both the name-parsed and the `ingredient =` paths. A
  multi-dose pen, cartridge or device is one container: a labelled dose
  draws a whole one unless `can_split_vials = TRUE`, and where the
  container's content is not a whole number of the solver's grid units
  (1.5 ml of 0.25mg/0.37ml is 1.0135 mg) the dose is covered by whole
  containers of the one product that best meets the objective instead of
  being refused. In the bundled release the name-parsed path resizes
  189 pack rows (90 medicines, 61
  priced: unit-dose eye drops and multi-dose pens and devices) and skips
  4 medicines (3 priced); the `ingredient =`
  path skips 239 product-ingredient pairs (81
  medicines, 30 priced) whose container size the name does
  not state, among them medicated plasters and dressings, nebuliser ampoules
  of unstated size and products recorded per gram but sold in millilitre
  unit doses. Of the 8,041 product-ingredient pairs that 0.6.2 dosed
  1000 times too high, 6,193 are now sized by the container the name
  states, 1,142 keep one litre or one gram because that is the
  container, 199 are skipped for an unstated size, and 507
  for an unknown dose count or mismatched units.
- **Packs whose number of doses is unknown are skipped with a warning
  instead of being costed as one dose per millilitre or gram.** For a
  product whose strength is per dose or actuation but whose pack is measured
  in ml or g ("Nicotine 1mg/dose oromucosal spray sugar free" in a 13.2 ml
  bottle, "Lidocaine 10mg/dose spray sugar free" in 50 ml) the dm+d records
  no dose count, and the dose functions treated each millilitre as one dose,
  so their costs were wrong by an order of magnitude in either direction.
  The same applied when the pack and the strength are in different physical
  units ("Clobetasol 500micrograms/g shampoo" in a 125 ml bottle), where a
  density was silently assumed. Such products are now skipped, on both the
  name-parsed and the `ingredient =` paths, with a warning of class
  `dmdprices_warning_unknown_dose_count` that names them (its `medicines`
  field lists them all) and points to `dmd_price_lookup()` for whole-pack
  costs; no dose count is invented. In the bundled release this removes 15
  priced medicines (28 priced pack rows) from the name-parsed path:
  azelastine, benzocaine, colecalciferol, flurbiprofen, lidocaine, nicotine
  and sildenafil sprays, ispaghula husk effervescent granules and tilactase
  oral drops. On the `ingredient =` path it removes 66 priced medicines (182
  product-ingredient pairs), mostly percentage-strength lotions, shampoos,
  scalp applications and emollients whose VPI strength is per gram while the
  pack is in millilitres; 30 of those pairs are still costable from the
  product name. Inhalers and nasal sprays whose pack is counted in doses,
  and bottles, vials and ampoules measured in the strength's own unit, are
  unaffected. The warning names only products the call would otherwise have
  costed: one that the `preparation` filter or the dose unit excludes is
  dropped without it.

## Behaviour changes

- **`over_delivery` is judged against the dose as requested.** Costs change
  for every dose that a group's strengths do not divide: under the default
  `"forbid"` such a dose now returns no row (`NA` from `dmd_dose_cost()` and
  `dmd_dose_cost_range()`) where it returned a rounded-down or rounded-up
  combination, and under `"minimise"` and `"allow"` it returns the smallest
  combination covering the dose where it could return less than the dose.
  Whole containers (`can_split_vials = FALSE`) and whole packs
  (`can_split = FALSE`) remain exempt from the policy and are still costed as
  the cheapest container or pack covering the dose. The "requested dose was
  rounded to the precision of the strengths" warning no longer exists; code
  that matched its text can drop that pattern. The "could not be resolved"
  warning's precision bullet now reads "the strengths cannot be represented
  at the precision the group's dose table allows for this dose" and no
  longer arises for a dose that is merely small.
- **`strength_canonical` means the same thing on every row.** In the
  `combination` tibbles of `dmd_dose_optimise()` and in the
  `dmd_ingredients` dataset, `strength_canonical` is the canonical numerator
  per one canonical denominator unit and `strength_unit_canon` names both
  ("mg/mg", "mg/ml", "unit/ml"). For an ingredient recorded as 20 mg per 1 g
  the columns were 20 and "mg" and are now 0.02 and "mg/mg". In the bundled
  `dmd_ingredients` 6,517 of 26,667 rows change value, 81
  rows whose denominator has no canonical form (per hour, per square
  centimetre, per drop, per application) are now `NA`, and 148
  rows stated in microlitres gain a value; when targeted with
  `ingredient =` such ingredients are skipped with the non-mass-strength
  warning, which now names the denominator unit. Ingredient tables loaded
  with `dmd_load()` or passed to `as_dmd_db()` are read from their raw
  strength fields, so a table built to the old convention targets correctly.
- **Ingredient tables must carry the raw dm+d strength fields.** Ingredient
  targeting now reads `strength_value`, `strength_unit`, `denominator_value`
  and `denominator_unit` from the ingredient table (as in `dmd_ingredients`
  and the `$ingredients` of a `dmd_load()` database) and no longer reads its
  canonical columns, so a table built to any convention targets alike. A
  table passed to `as_dmd_db()` without those columns, or one met during
  targeting, is refused with an error naming the missing columns; 0.6.2
  accepted a table carrying only `strength_canonical` and
  `strength_unit_canon`.
- **Two new dose warnings to match.** Code that silences the dose warnings
  by matching their text should also match "doses per pack is unknown" and
  "amount of drug per container is unknown". `quiet = TRUE` does not silence
  them, like the unsupported-compound and multi-product-pack warnings, and
  `dmd_dose_cost_range()` shows each once per call.

# dmdprices 0.6.2

## Bug fixes

- **Dose costs could be served from the cache of a different price table
  (#28, #29, #30).** `dmd_dose_optimise()`, `dmd_dose_cost()` and
  `dmd_dose_cost_range()` cache their candidate search for the session, but
  recognised a table by a label rather than by its contents. A data frame
  carrying the `dmd_release_label` attribute was recognised by that label,
  which survives subsetting and price edits of `dmd_master` or of
  `dmd_price_lookup()` output. A `<dmd_db>` was recognised by its
  `loaded_at` timestamp, which an in-place edit such as
  `db$master$basic_price <- new_prices` leaves unchanged and which two
  databases can share (or both lack). A second call with the same query and
  settings against a different table could therefore silently return the
  first table's cost. The cache now recognises a table by its contents. The
  bundled `dmd_master` is recognised by identity. Any other table (the
  `$master` of a `<dmd_db>`, or a plain data frame) is recognised by an
  `rlang::hash()` of its contents, and a `<dmd_db>` shares cache entries
  with its own `$master`. Hashing a table the size of `dmd_master` takes
  about 50 ms. Only the most recently hashed table is remembered, so repeat
  calls on one custom table pay this once, while alternating between two
  large custom tables re-hashes each time. A `data.table`, which can be
  edited in place by reference, is hashed on every call. Calls against the
  bundled data are unaffected. `loaded_at` is now purely descriptive, so any
  timestamp is safe in `as_dmd_db()`. This supersedes the 0.6.0
  "Performance" note, which keyed the cache on `loaded_at` and the release
  label.
- **The dose cache no longer confuses `max_dist` values that print alike.**
  Its key pasted the arguments into one string, so `max_dist = 0.3 / 0.1`
  (2.9999999999999996, which prints as 3) and the string `"3"` shared the
  cache entry of `max_dist = 3`, and a fuzzy search could be served the
  other value's candidates. The key now keeps each argument's type and full
  precision.
- **Creams, gels and ointments sold as a single tube or jar had a per-item
  dose 1000 times too small.** For a product whose strength is stated per
  gram (such as `20mg/g` or `50micrograms/g`) and whose pack is one
  container measured in grams, the dose functions multiplied a strength per
  milligram of product by the pack size in grams. A 60 g tube of a 20mg/g
  cream therefore counted as 1.2 mg rather than 1200 mg, and dose costs used
  up to 1000 times too many packs: `dmd_dose_cost("Delgocitinib", dose =
  1200, dose_unit = "mg", objective = "cheapest")` costed 1000 tubes
  (59,500,000p) and now costs one (59,500p). The pack quantity is now
  converted to the strength's canonical unit first. Bottles, inhalers and
  other one-container packs measured in ml or doses are unaffected, and
  results with `ingredient =` are unchanged (see Behaviour changes).
- **The 11 eptacog alfa/beta products whose names state the mass with a unit
  equivalent in brackets are no longer skipped as compounds (#27).** In a
  name such as "Eptacog alfa (activated) 1mg (50,000unit) powder and solvent
  for solution for injection vials", a bracketed strength that stands alone
  and is in a different unit dimension from the product's strength restates
  that strength, so it is no longer counted as a second one. The dose
  functions now cost these products by mass (`dmd_dose_optimise("eptacog
  alfa", dose = 7, dose_unit = "mg")` costs 367,640p). A dose in units does
  not match them: when no other candidate is left, `dmd_dose_optimise()`
  warns that no candidates matched the requested dose unit and
  `dmd_dose_cost()` returns `NA`. A bracketed strength in the same unit
  dimension, or one that names another substance, still keeps a product
  skipped as a compound, for example "Iohexol 755mg/ml (Iodine 350mg/ml)",
  "Mexiletine hydrochloride 200mg (Mexiletine 167mg)" and "Factor VIII
  Inhibitor Bypassing Fraction human 25units/ml (500unit)".
- **`dmd_load()` names the missing `csv/` folder as you supplied it (#31).**
  The message showed the folder in its `normalizePath()` form, which on
  Windows is absolute and backslashed even for a folder that does not exist,
  and which resolves an existing folder on every platform. The message
  therefore depended on the platform and the working directory, and the
  bad-path snapshot test failed on Windows. It is now the same everywhere:
  `dmd_load("loader")` reports `'loader/csv' does not exist.` A leading `~`
  is no longer expanded in the message; the `normalizePath()` form is kept
  on the condition (see Behaviour changes).
- **A periodontal gel whose name lists two strengths ("Doxycycline
  36.4mg/260mg periodontal gel cartridge") was dropped without the
  unsupported-compound warning (#27).** No strength is parsed from its name,
  and its compound flag was `NA` rather than `TRUE`, so it was dropped with
  no warning naming it. It is now skipped with the unsupported-compound
  warning, like other products whose names list several strengths. The
  bundled release has no price for it, so this shows only with
  `active_only = FALSE` or a custom table.
- `dmd_dose_cost_range()` no longer shows a dose warning twice on a narrow
  console. It shows each warning once for both bounds by matching the
  warning's text, which cli wraps to the console width, so a line break
  inside the matched phrase let the second bound's copy through (below 51
  columns for the rounding warning below, and below about 41 for the
  others).
- The `dmd_load()` "No path supplied." hint now shows
  `options(dmdprices.path = "...")` without literal backslashes, so it can be
  copied as written.
- `print()` of `dmd_master_info()` no longer errors ("argument is of length
  zero") for a `<dmd_db>` whose `loaded_at` is `NULL` and that has no
  release label. The dataset label now reads "unknown".

## Behaviour changes

- **Packs that hold several products get their own warning (#27).** The
  dose functions still skip them, but now warn "N multi-product pack(s)
  skipped during dose optimisation." instead of counting them in the
  unsupported-compound warning. This covers multi-strength packs, such as
  "Danicopan 50mg tablets and Danicopan 100mg tablets" or "Memantine
  5mg/10mg/15mg/20mg orodispersible tablets initiation pack sugar free", and
  co-packs of different products, such as "Tixagevimab ... vials and
  Cilgavimab ... vials". The warning lists them as multi-strength packs or
  co-packs and no longer suggests `ingredient =`; cost the products in such
  a pack individually instead. `dmd_dose_cost_range()` shows it once per
  call, and `quiet = TRUE` does not silence it. Code that silences these
  warnings by matching their text should now match "multi-product pack" as
  well as "unsupported compound product". A pack is recognised only when its
  name gives each product's strength in mass or units: packs that give a
  product's strength only as a percentage, such as "Fluconazole 150mg
  capsule and Clotrimazole 2% cream", are not recognised and are still
  costed as their first product, as before.
- **The `dmd_load()` missing-folder error now has a class (#31).** It is
  `dmdprices_error_missing_csv_dir` and carries a `path` field (as supplied)
  and a `csv_dir` field (the `csv/` folder after `normalizePath()`, which
  is absolute when `path` exists, written with forward slashes on every
  platform), so it can be caught with
  `tryCatch(..., dmdprices_error_missing_csv_dir = function(cnd) ...)`. On
  Windows the "Reading dm+d CSV files from ..." progress message now also
  uses forward slashes.
- **Dose costs fall, by up to 1000 times, for creams, gels and ointments
  whose strength is stated per gram and that are sold as a single tube or
  jar**, after the per-item dose fix above. In the bundled data this affects
  19 priced medicines that the dose functions can cost (32 priced pack
  rows), among them testosterone 20mg/g gel (an 85.5 g pack now counts as
  1710 mg, not 1.71 mg) and delgocitinib, calcipotriol, estriol and
  ivermectin preparations. Results with `ingredient =` are unchanged. Re-run
  any analysis that costed these products with an earlier version.
- **A dose with finer decimals than the strengths now gets its own
  warning.** The dose functions take such a dose to the nearest whole unit
  of the strengths' scale under every `over_delivery` policy, as in earlier
  versions: 2.4 mg against 1 mg tablets is costed as 2 mg, and 2.6 mg as
  3 mg. Under `over_delivery = "forbid"` (the default) and `"minimise"` this
  used to raise the over-delivery warning, which called a rounded-down dose
  "Delivering more than the requested dose" and advised passing `"forbid"`,
  which returns the same rounded result. Such a result now warns "The
  requested dose was rounded to the precision of the strengths ..."
  instead, once per call (and once per `dmd_dose_cost_range()` call);
  `quiet = TRUE` silences it, and `?dmd_dose_optimise` documents the
  rounding under `over_delivery`. The warning covers groups the
  over-delivery policy governs; whole-container groups (vials and ampoules
  with `can_split_vials = FALSE`) and whole-pack groups (`can_split =
  FALSE`) round the dose the same way without a warning, as in earlier
  versions. Under `"allow"`, a rounded dose whose
  chosen combination over-delivers now gets the over-delivery warning's "no
  exact-dose combination exists" line; it used to say that an exact-dose
  combination existed. Costs are unchanged. This matters for eptacog alfa,
  now costed by mass: a weight-based 6.3 mg dose is costed as 6 mg
  (315,120p), one 1 mg vial short of the dose.

## Documentation and infrastructure

- R-CMD-check (ubuntu, windows and macOS on R release, plus ubuntu on
  R-devel) now runs on pushes to and pull requests into `develop`, as well as
  `main`/`master`, and can be started by hand (`workflow_dispatch`). Within
  one pull request, or one branch, a newer push cancels the run it
  supersedes. The pkgdown site is now built on pull requests but deployed
  only from `main`/`master`.
- `lifecycle (>= 1.0.2)` is now required: it is the first version whose
  `deprecate_warn()` accepts `what = I(...)`, which the `objective = "both"`
  deprecation uses.
- `dplyr (>= 1.1.0)` is now required: it is the first version with
  `join_by()`, which `dmd_load()` uses; an older dplyr made installation fail
  at lazy-load. The tests now declare `testthat (>= 3.1.9)`, the first
  version with `expect_contains()` (`local_mocked_bindings()` arrived in
  3.1.7).
- `memoise (>= 2.0.0)`, `cli (>= 3.0.0)` and `readr (>= 2.0.0)` are now
  declared. memoise 2.0.0 is the first with the `hash` argument and cachem
  caches, which the dose cache uses (an older memoise made installation
  fail); cli 3.0.0 is the first with `cli_abort()`, `cli_warn()`,
  `cli_inform()` and `cli_progress_step()`; and readr 2.0.0 is the first
  whose `read_delim()` takes `show_col_types`, which `dmd_load()` passes.
- `citation("dmdprices")` now reports the installed package version (it said
  0.5.0).
- README: the dose optimisation example is now 1000 mg of immediate-release
  metformin tablets (`preparation = "tablet|none|oral"`), with a note on what
  an unfiltered call returns (a whole oral-solution bottle with `dose_exact =
  FALSE`, and the combination-product warning), an `over_delivery =
  "minimise"` example, the multi-product pack warning and the optional
  `dmdDataLoader` files. Its NHS CII outputs are rerun on the current rates
  and, like the NHS CII, data sources and troubleshooting vignettes, it
  gives 2014/15 to 2024/25 as the coverage, with 2024/25 provisional. The
  NHS CII vignette's unavailable-year example now uses a year that really is
  unavailable (2014/15 is a supported base year).
- The dose optimisation vignette and `?dmd_dose_optimise` describe
  bracketed restatements and the multi-product pack warning, and the `db`
  argument now says that the candidate cache follows the table's contents.
  The vignette's objectives example uses 1500 mg of metformin, which both
  objectives deliver exactly (no tablet combination makes the 900 mg it
  used), and the first `?dmd_dose_optimise` example likewise moves from
  900 mg to 1000 mg of immediate-release tablets. The `ingredient` argument
  and the "No ingredient data available" warning now point to
  `as_dmd_db(ingredients = )` rather than to rebuilding the bundled data.
  `?as_dmd_db` describes `loaded_at` as display-only, and `?dmd_ingredients`
  no longer says the bundled table may be empty (it has 26,667 rows).
  The vignette's limitations list now also names doses rounded to the
  strengths' precision and a known costing gap, unchanged from earlier
  versions: sprays and granules whose strength is per dose or actuation but
  whose pack is measured in ml or g (nicotine mouth and nasal sprays,
  lidocaine and colecalciferol sprays, ispaghula husk granules) are costed
  as if each ml or g were one dose, because the dm+d gives no dose count.
- The pkgdown home page links the dose optimisation article, and the news
  menu lists 0.6.1 and 0.6.2.
- `.Rbuildignore` now excludes `.git` (a package built from a linked git
  worktree included its `.git` file) and Shiny app `manifest.json` files.
  The `/Meta/` entry in `.gitignore` no longer has a typo.
- The dose optimiser and price lookup apps' DESCRIPTION files now list
  `dplyr`, which both apps call, and the dose optimiser app requires
  `dmdprices (>= 0.6.0)`.

# dmdprices 0.6.1

## Bug fixes

- **Packs of several containers were priced at the whole pack per
  container.** For a concentration preparation whose pack quantity counts
  containers rather than volume or doses (10 pre-filled syringes, 5 ampoules,
  20 nebuliser vials), one optimisation item is one container — as the
  documentation and `per_item_dose` always said — but its price was the whole
  pack, so a single 40 mg enoxaparin syringe from a ten-syringe pack cost ten
  syringes, and the optimiser could prefer a dearer product whose pack held
  one container. Each container now costs its share of the pack
  (`per_item_price_pence = pack price / containers per pack`), whole-pack
  figures buy `ceiling(containers / containers per pack)` packs, vial sharing
  takes a fraction of one container's price, and pack-level coins (whole-pack
  dispensing) carry the whole pack's dose. Single-container packs — a bottle
  or an inhaler whose pack quantity is in the strength's own denominator unit
  — are unchanged. The dose a container delivers still comes from the
  strength's denominator volume, so a pen or bag whose fill volume is not in
  the product name is still one denominator volume per item.
  Whole-pack dispensing (`can_split = FALSE`) now optimises every
  preparation over whole packs: a pack of several containers is dispensed as
  whole packs, `total_items` counts packs for such a group (as it always did
  for solid forms), and `"cheapest"` is the cheapest set of whole packs
  covering the dose. Previously a concentration group under `can_split =
  FALSE` still chose by the pro-rata per-container price and then reported
  that product's whole pack, which after per-container pricing was no
  longer the cheapest available cover and could put `dmd_dose_cost_range()`'s
  lower bound above its upper bound. Single-container packs give the same
  costs and item counts as before (their rows now also carry the
  `"no-pack-splitting"` note the documentation always promised). Two
  consequences of the pack path for these groups: the over-delivery budget
  is one largest pack rather than one container, so `"most_expensive"` and
  `dmd_dose_cost_range()$hi_pence` under `can_split = FALSE` can be several
  times larger than before (an upper bound on whole-pack expenditure, as for
  solid forms); and a dose that a pack over-covers reports `dose_exact =
  FALSE` with an `"over-delivery"` note, where the container path reported
  the container's dose. A concentration row whose pack quantity is zero or
  negative now carries no price (it was priced at the whole pack) and, like a
  solid row, is excluded from the pack coins — a group with no other row
  returns no row.
- **A dose finer than every strength in a preparation group silently
  dropped the group.** The integer scale used by the dose solver was chosen
  from the strengths alone, so a 100 microgram dose against 20 mg-per-inhaler
  products rounded to zero and the inhaler group returned nothing — no row,
  no warning, `NA` from `dmd_dose_cost()`, and the cost range silently taken
  from the remaining groups. The strengths' scale is now raised by powers of
  ten until the dose is at least one unit, so the group is optimised (one
  whole container for such a dose). A raise that would push the group's
  dose table past its 5,000,000-cell cap is not taken, so a group that
  priced before (at the strengths' own scale) still prices. Doses that
  already priced are unaffected: their scale is unchanged, and a dose with
  finer decimals than the strengths is still taken to the nearest whole unit
  of the strengths' scale rather than resolved exactly (which would inflate
  the solver's table).
- **Groups the solver cannot run for a dose are reported once per call.** A
  dose still below the resolvable precision at the capped scale, or one whose
  dose table would exceed the cell cap, returns no row for that group; every
  such group is now named in one warning per call (per `dmd_dose_cost()`
  vector, and once across the two bounds of `dmd_dose_cost_range()`) rather
  than once per group and objective, and `quiet = TRUE` silences it as it
  does the other per-call dose warnings.

# dmdprices 0.6.0

## Dose optimisation now delivers the requested dose exactly by default

`dmd_dose_optimise()`, `dmd_dose_cost()`, and `dmd_dose_cost_range()` gain an
`over_delivery` argument, defaulting to `"forbid"` (#23).

Previously every objective optimised across all combinations delivering *at
least* the dose, with over-delivery only a tie-break. When an over-delivering
combination was strictly cheaper, strictly fewer items, or strictly dearer, an
available exact-dose combination was never surfaced by any objective — a 3 mg
buprenorphine sublingual dose returned 4 mg (`cheapest`), 8 mg (`min_items`),
and 11 mg (`most_expensive`), so `dmd_dose_cost()` silently costed 4 mg.

- `"forbid"` (new default) returns only exact-dose combinations. A preparation
  group that cannot hit the dose exactly returns no row and is named in a single
  warning per call; `dmd_dose_cost()` returns `NA` for such doses.
- `"minimise"` returns the smallest achievable over-delivery, with the requested
  objective applied within it.
- `"allow"` restores the previous behaviour.

The policy applies where one item is an individually administered dose. Whole
pack dispensing (`can_split = FALSE`) and whole containers (vials and ampoules
with `can_split_vials = FALSE`) are exempt — there the surplus is wastage, so
the cheapest pack or container covering the dose is still returned, with an
`"over-delivery-policy-not-applied"` note.

Results gain a `dose_exact` logical column, and `notes` gains `"exact-dose"`,
`"over-delivery-minimised"`, and `"over-delivery-policy-not-applied"` entries,
so an optimised exact dose, an impossible one, and a query that matched nothing
are all distinguishable.

A returned combination that over-delivers now also raises a warning — one per
call, listing the preparation groups and saying whether no exact combination
existed or whether one existed but the objective preferred an over-delivering
combination. This matters most for `dmd_dose_cost()` and `dmd_dose_cost_range()`,
which return bare numbers and so cannot show the `notes` column. The exempt
whole-pack and whole-container results do not warn, since their surplus is
expected wastage. `quiet = TRUE` (new argument on all three functions) silences
this warning and the no-exact one, leaving unrelated warnings intact.

## Behaviour changes

When upgrading from the 0.5.0 build released to main in June 2026 (#12): no
functions were removed or renamed; `over_delivery` and `quiet` are new
arguments and `as_dmd_db()` is a new function, and default results change,
above all through the new `over_delivery = "forbid"` default described above.
That build already contained the changes below. When upgrading from 0.3.0, or
from a development build numbered 0.5.0 made before #12, `ingredient` and
`can_split_vials` may also be new, and the following changes can also alter
**results**:

- **NHS CII 2023/24 figures revised.** Following the PSSRU 2025 manual, the
  provisional 2023/24 rates have been revised (e.g. `pay_and_prices` 2023/24
  moved from `4.31%` to `2.47%`). Any `nhscii()` / `inflate_nhscii()` call
  that spans 2023/24 now returns different numbers than 0.3.0. Coverage also
  now extends back to 2014/15 and forward to 2024/25 (#9, #6).
- **`dmd_price_lookup(method = "partial")` now matches literally, not as a
  regular expression.** Queries that previously relied on regex metacharacters
  (e.g. `"a|b"` as an alternation) will behave differently; plain-text queries
  are unaffected.
- **`dmd_price_lookup()` now also searches branded pack names (`ampp_name`).**
  The same query can return more rows than before (e.g. `"Buvidal"` now
  resolves to its packs). Generic-name queries return at least what they did
  previously.
- **Bundled `dmd_master` refreshed** from Week 34 2025 to Week 15 2026, so
  default price lookups reflect the newer release (different prices/availability)
  and the dataset gains an `is_combination` column.

## Data

- Bundled `dmd_master` and `dmd_ingredients` datasets updated to **dm+d Week 15
  2026 (06 April 2026)**, replacing the previous Week 34 2025 (14 August 2025)
  release.
- `dmd_load()` and `data-raw/dmd_master.R` updated to reflect renamed CSV files
  in this release: `f_vmp_VpiType.csv` (was `f_vmp_VirtualProductIngredientType.csv`),
  `f_ingredient.csv` (was `f_ingredient_IngredientType.csv`), and
  `f_lookup_UoMHistoryInfoType.csv` (was `f_lookup_UnitOfMeasureType.csv`, now
  4-column schema without `INVALID`).
- Bundled `dmd_master` now shows readable pack units for doses
  (inhalers/vaccines → `"dose"`), grams (`"g"`), and pre-filled syringes
  instead of raw SNOMED unit codes. The `dmd_master` documentation now also
  lists the `is_combination` column added with the ingredient data.

## Added

- `as_dmd_db()` — new exported function that builds a `<dmd_db>` from an
  in-memory data frame, so external Drug-Tariff-shaped data (for example the
  `drug_tariff_viii_a` table from NICE's COSTmos package) can be used with
  `dmd_price_lookup()` and `dmd_dose_optimise()`. It fills missing optional
  columns with `NA`, coerces types, and reports any reduced functionality.
- **Combination-product handling (#8).** `dmd_parse_strength()` now detects
  multi-ingredient products (e.g. co-codamol `"8mg/500mg"`) and returns each
  ingredient's strength in a new `components` list-column with `is_combination`
  / `n_components` flags, instead of misreading the mass/mass strength as a
  concentration. This also covers combination inhalers and similar products
  written as `"X micrograms/dose / Name Y micrograms/dose"`.
- `dmd_load()` now reads the dm+d Virtual Product Ingredient (VPI) extract when
  present, exposing a `$ingredients` table of per-ingredient strengths and an
  `is_combination` flag on `$master`. A new bundled [dmd_ingredients] dataset
  holds the same table for the bundled release (26,667 rows for Week 15
  2026).
- `dmd_dose_optimise()`, `dmd_dose_cost()`, and `dmd_dose_cost_range()` gain an
  `ingredient` argument: dose against a single named active ingredient, which
  lets combination products be optimised for one ingredient (e.g. the codeine
  content of co-codamol). Matching is case-insensitive and word-boundary based,
  so `"codeine"` does not also match `"dihydrocodeine"`; a warning is emitted
  when the term resolves to several distinct ingredients, or when a targeted
  ingredient is recorded in a non-mass unit (e.g. GBq, mmol) that cannot be
  dosed by mass. Without ingredient data, combination products continue to be
  skipped with a warning.

- `dmd_dose_cost_range()` — new exported function that returns a tibble with
  `lo_pence` and `hi_pence` columns (one row per dose), giving the cheapest
  and most expensive achievable dose cost in a single call. Designed for
  health-economics range analyses inside `dplyr::mutate()` or
  `dplyr::bind_cols()`. The memoized candidate preparation step is shared with
  `dmd_dose_cost()`, so calling both functions for the same drug incurs the
  expensive lookup work only once.
- `dmd_master_info()` — new exported function returning key metadata (release
  label, load timestamp, AMPP/VMPP/VMP counts, price date range) about
  `dmd_master` or a `dmd_load()` database. Useful for confirming data freshness
  in analysis scripts and Shiny app footers. Returns a `"dmd_db_info"` object
  with a `print()` method.
- `dmd_dose_optimise()` and `dmd_dose_cost()` gain a `"most_expensive"`
  objective, which selects the highest-cost combination of AMPPs. Useful for
  worst-case cost modelling and budget-impact analysis upper bounds.
- `objective` now accepts a **character vector** of any combination of
  `"cheapest"`, `"min_items"`, and `"most_expensive"`. Pass `"all"` as a
  shorthand for all three. The default remains `c("cheapest", "min_items")`.
- `dmd_dose_optimise()` and `dmd_dose_cost()` gain `can_split_vials = FALSE`.
  Set to `TRUE` to cost concentration preparations (vials, ampoules) as a
  fraction of a container (vial sharing), which adds `"vial-sharing"` to the
  `notes` column and returns a non-integer `count` in the combination tibble.
- `bslib`, `cachem`, and `lifecycle` added to `Imports`.

## Changed

- The dose optimiser Shiny app now shows a note below the results table
  explaining that "Dose delivered", "Over-delivery", and "Cost (pence)" are
  rounded for display only (2 d.p., 2 d.p., and 1 d.p. respectively), and that
  full-precision values are preserved in CSV/Excel exports and in the R object
  returned by `dmd_dose_optimise()`.
- All three Shiny apps now surface package warnings **and** errors to the user
  as Bootstrap alert callout boxes, rather than silently swallowing them or
  printing only to the console. For example, the dose optimiser shows
  `cli::cli_warn()` notices (compound products skipped, ambiguous ingredient,
  non-mass units) above the results, and invalid input shows the underlying
  error message. The dm+d price-lookup app footer now also reads Week 15 2026.
- `dmd_price_lookup()` now also searches the branded pack name (`ampp_name`),
  not just the generic `medicine` name, so a query for a brand (e.g.
  `"Buvidal"`) returns its packs while generic queries continue to work as
  before. Applies to all three methods (`partial`, `exact`, `fuzzy`).
- NHS CII rates updated to the PSSRU *Unit Costs of Health and Social Care 2025
  Manual*. Coverage now extends to 2024/25 (provisional), and the previously
  provisional 2023/24 figures have been revised to the values published in the
  2025 manual (#9).
- `nhscii()` and `inflate_nhscii()` now accept 2014/15 as a `from_year`, the
  first row of the NHSCII table (#6).

## Deprecated

- `objective = "both"` in `dmd_dose_optimise()` and `dmd_dose_cost()` is
  deprecated. Replace with `objective = c("cheapest", "min_items")`. A
  `lifecycle::deprecate_warn()` warning is emitted on first use.

## Fixed

- Combination-product detection now trusts the dm+d `is_combination` flag
  (#8). Previously `dmd_dose_optimise()` decided combination-ness from the
  product *name* alone, so 114 bundled combination products whose names show a
  single number — allergen mix solutions ("Generic Tree mix 3 pollen
  500micrograms/ml..."), multi-factor concentrates (Prothromplex Total) — were
  silently dosed on that misread single strength. Where the database carries
  `is_combination` (the bundled data and `dmd_load()` databases), a `TRUE`
  flag now always routes the product through the combination path: it is
  skipped with a warning unless `ingredient` names the active ingredient to
  dose against. The name heuristic is retained as a union, so multi-strength
  names ("X 50mg tablets and X 100mg tablets") stay skipped even when dm+d
  does not flag them. The skip warning now also names example products and the
  `ingredient` remedy, and the dose-optimisation vignette gains a
  "Combination products" section with a worked co-codamol example.
- `dmd_parse_strength()` now parses strengths written with comma thousands
  separators, e.g. nystatin `"100,000units/ml"` (#22). Around 551 bundled
  medicine names carry such strengths (nystatin suspensions, factor VIII/IX
  and other `N,NNNunit` vials); previously they parsed to `NA` and so could not
  be dose-costed, and `dmd_dose_cost()` returned `NA` for them. Two follow-on
  corrections: multi-ingredient names such as
  `"Colecalciferol 1,000unit / Menaquinone-7 45microgram capsules"` previously
  matched mid-number and silently produced a **zero-strength** component
  (`"000unit"` -> 0) with a mangled `drug_stem`; both now parse correctly. Dose
  strings passed to `dmd_dose_optimise()` also accept the comma form
  (`dose = "100,000 units"`). A comma group must be exactly three digits, so
  malformed tokens and European decimal commas are still rejected. Identity
  matching in `dmd_price_lookup()` is unaffected.
- Dose-optimiser combination rows no longer conflate two AMPPs. In the
  splittable path, the cheapest *per-tablet* pack and the cheapest *whole*
  pack of a strength can differ; the row previously showed one pack's identity
  with another pack's `pack_price_pence` / `price_field_used` (e.g. a
  1000-tablet pack labelled with a 28-tablet pack's price). Each row now
  describes a single product consistently — `pack_price_pence`,
  `per_item_price_pence`, the whole-pack subtotal, and `price_field_used` all
  refer to the AMPP named in that row.
- Inhaler (and other per-dose) costing: the `"dose"` pack-unit code is now
  recognised, so a single inhaler is treated as its full actuation count
  (e.g. 200 doses) rather than one actuation priced as a whole pack. Previously
  a 20 mg salbutamol request returned 200 "items" at the whole-inhaler price;
  it now returns one inhaler.
- Cheapest dose optimisation now breaks cost ties by preferring the **lowest
  over-delivery**. Previously it could return an over-delivering combination
  (e.g. 2 × 32 mg = 64 mg for a 40 mg target) when an exact-dose combination of
  equal cost existed, because the tie-break inspected the fewest-items path
  rather than the cheapest path's over-delivery.
- Pack units now resolve via the dm+d unit-of-measure lookup as a fallback, so
  container codes not in the curated short-label table (e.g. the pre-filled
  syringe unit on depot injections like buprenorphine prolonged-release) show
  their proper label instead of a raw SNOMED code. Curated short labels
  (`"ml"`, `"tablet"`, …) still take precedence. Takes effect when the bundled
  data is rebuilt (`data-raw/dmd_master.R`) or a release is loaded with
  `dmd_load()`.
- `dmd_price_lookup(method = "partial")` now matches the query as a literal
  substring rather than a regular expression, so queries containing regex
  metacharacters (e.g. the `"[I-131]"` in radiopharmaceutical names) no longer
  error.
- `dmd_dose_cost(objective = "most_expensive")` now returns the worst-case cost
  (maximum across preparation groups) instead of silently returning the
  cheapest. Aggregation across multiple objectives uses each objective's
  natural extremum.
- `dmd_dose_optimise(objective = "most_expensive", can_split = FALSE)` now
  selects the dearest whole-pack combination rather than falling through to
  the cheapest branch. The notes column reads `"most-expensive-pack-per-dose"`
  on this path.
- `dmd_dose_optimise(objective = "most_expensive")` now follows a true
  max-cost DP path rather than selecting the highest of the cheapest paths.
- Concentration-based products now calculate the active quantity per container
  correctly when the pack quantity shares the concentration denominator unit
  (for example, `10mg/5ml` in a `100 ml` bottle).
- Unsupported compound products with multiple active strengths in one VMP name
  are skipped with a warning rather than optimised against an ambiguous dose.
- `print.dmd_dose_combination()` and the dose-optimiser Shiny app's
  combination formatter use `%g` instead of `%d` so fractional
  vial-sharing counts (e.g. `0.5`) render without a warning.
- The dose optimiser Shiny app now renders the selected-row combination detail
  table through a normal `DTOutput()` / `renderDT()` pair.
- `DT` moved back to `Imports` (from `Suggests`) so `run_dmd_price_lookup()`
  works on a fresh install without a separate `install.packages("DT")` step.
- `dmd_dose_optimise()` result columns are now in the same order as the empty
  scaffold returned when no candidates are found (`dose_cost_pence` was
  previously appended after `notes` rather than between `cost_whole_pack_pence`
  and `price_field_used`).
- `dmd_dose_cost()` now emits an informative error when `dose` is a character
  string, explaining the difference from `dmd_dose_optimise()`.
- Memoization cache is now capped at 1 GB via `cachem::cache_mem()` to prevent
  unbounded memory growth in long-running sessions.
- Dead code removed from `.best_target()` internal function (`min_items` branch
  had a redundant feasibility filter that was always a no-op).

## Performance

- The memoized candidate preparation step now keys on lightweight scalars
  (`dmd_db$loaded_at`, or the `dmd_release_label` attribute of the bundled
  `dmd_master`) rather than hashing the full 118k-row tibble on every call.
  This eliminates a ~10 ms per-call digest overhead for the common case where
  the database does not change within a session. (Superseded in 0.6.2:
  keying on these labels could serve stale costs, so the cache now keys on
  the table's contents; #28, #29, #30.)
- `.dose_dp()` internal DP function: the inner per-strength loop is now fully
  vectorised using `which.min()` and R vector arithmetic, replacing a pure R
  nested loop. This reduces loop overhead for the outer DP iterations and
  yields a 2–5× speedup for typical drug queries.

## Documentation

- `dmd_dose_optimise()` `@return` now documents that `count` in the
  `combination` tibble means individual dispensing units (tablets/containers)
  when `can_split = TRUE`, and whole packs when `can_split = FALSE`.
- Vignette `dose_optimisation` documents whole-pack dispensing, vial sharing,
  vectorised costing, cost ranges, and compound-product skipping.
- The README and apps vignette now list all three Shiny apps as hosted and
  locally runnable, including the dose optimiser app.

# dmdprices 0.5.0

## Added

- `dmd_dose_cost()` — vectorised companion to `dmd_dose_optimise()`. Accepts a
  numeric vector of doses and returns a plain numeric vector of costs in pence.
  Designed for use inside `dplyr::mutate()` without `purrr::map_dbl()`.
- `preparation` argument of `dmd_dose_optimise()` and `dmd_dose_cost()` now
  accepts a plain case-insensitive substring (e.g. `"infusion"`) rather than
  requiring the exact preparation group key.

## Performance

- The expensive dose-independent work in `dmd_dose_optimise()` (price lookup,
  strength parsing, preparation classification) is now memoized for the session
  via `memoise`. Repeated calls for the same drug within a session (e.g. across
  all rows of a table) incur that cost only once.

# dmdprices 0.4.0

## Added

- `dmd_dose_optimise()` — given a clinical dose, returns the cheapest and/or
  minimum-item combination of AMPPs that delivers it. Preparations (e.g.
  immediate-release vs modified-release tablets, oral solutions,
  solution-for-injection) are segregated automatically. Each result row
  includes a `combination` list-column identifying the specific branded
  products picked.
- `dmd_parse_strength()` — helper exposing the VMP-name strength parser (amount,
  unit, optional denominator for concentrations such as `mg/ml`,
  `microgram/dose`).

# dmdprices 0.3.0

## Added

- `nhscii()` — compute NHS Cost Inflation Index factors between financial years.
- `inflate_nhscii()` — adjust costs using NHS CII rates.
- Both functions support "pay_and_prices", "pay", and "prices" indices covering
  2015/16–2023/24 (provisional).
- `run_dmd_price_lookup()` — launch the dm+d price lookup Shiny app locally.
- `run_inflate_nhscii()` — launch the NHS CII cost adjuster Shiny app locally.
- Hosted interactive apps on Posit Connect Cloud.

# dmdprices 0.2.0

## Added

- `dmd_load()` — loads a more recent dm+d release from a local `dmdDataLoader`
  CSV directory.
- `dmd_price_lookup()` — queries the pricing table by medicine name with
  "partial", "exact", and "fuzzy" match methods.
- Bundled `dmd_master` dataset (Week 34 2025, 14 August 2025) for zero-setup
  use.
- Output columns mirror the NHS Drug Tariff Part VIIIA CSV format.
