# The dose-candidate cache (#28, #29, #30).
#
# dmd_dose_optimise(), dmd_dose_cost() and dmd_dose_cost_range() memoise their
# dose-independent candidate step for the session. A cached candidate set may
# be reused only for a table with identical content. Each test starts and ends
# with an empty cache (.local_fresh_dose_cache()) and makes the calls it
# compares back to back: a stale hit needs both calls to share one cache, so
# nothing may empty it between them.

.bup_8mg <- "Buprenorphine 8mg sublingual tablets sugar free"

# The cost of an 8 mg dose through one entry point. .fake_sublingual_db()
# prices the 8 mg tablet at 4900p for 7, so one tablet costs 700p.
.cost_8mg <- function(entry, db) {
  switch(
    entry,
    dmd_dose_cost = dmd_dose_cost(
      .bup_8mg,
      dose = 8,
      dose_unit = "mg",
      db = db,
      method = "exact",
      objective = "cheapest",
      quiet = TRUE
    ),
    dmd_dose_optimise = dmd_dose_optimise(
      .bup_8mg,
      dose = 8,
      dose_unit = "mg",
      db = db,
      method = "exact",
      objective = "cheapest",
      quiet = TRUE
    )$dose_cost_pence,
    dmd_dose_cost_range = dmd_dose_cost_range(
      .bup_8mg,
      dose = 8,
      dose_unit = "mg",
      db = db,
      method = "exact",
      quiet = TRUE
    )$lo_pence
  )
}

.dose_entries <- c("dmd_dose_cost", "dmd_dose_optimise", "dmd_dose_cost_range")

# Whether the memo holds the candidate set for `query` in `db` (default
# max_dist, active_only and price).
.has_candidates <- function(query, db, method = "partial") {
  memoise::has_cache(.dmd_prepare_candidates_memo)(
    query = query,
    db = db,
    method = method,
    max_dist = 3,
    active_only = TRUE,
    price = "basic_price"
  )
}

# ── #28: a plain tibble carrying the release label ────────────────────────────

# Subsets of dmd_master and dmd_price_lookup() output keep the
# `dmd_release_label` attribute, which the old key treated as the content.
.labelled_master <- function() {
  m <- .fake_sublingual_db()$master
  attr(m, "dmd_release_label") <- "Week 15 2026 (06 April 2026)"
  m
}

for (entry in .dose_entries) {
  test_that(paste0(entry, "() re-costs a repriced labelled tibble (#28)"), {
    .local_fresh_dose_cache()
    cheap <- .labelled_master()
    dear <- cheap
    dear$basic_price <- dear$basic_price * 9L

    expect_equal(.cost_8mg(entry, cheap), 700)
    expect_equal(.cost_8mg(entry, dear), 6300)
  })
}

# ── #29: a <dmd_db> edited in place, NULL or duplicate loaded_at ──────────────

for (entry in .dose_entries) {
  test_that(paste0(entry, "() sees an in-place edit of db$master (#29)"), {
    .local_fresh_dose_cache()
    db <- .fake_sublingual_db()

    expect_equal(.cost_8mg(entry, db), 700)
    db$master$basic_price <- db$master$basic_price * 9L
    expect_equal(.cost_8mg(entry, db), 6300)
  })
}

test_that("<dmd_db>s without a loaded_at keep their own prices (#29)", {
  .local_fresh_dose_cache()
  m1 <- .fake_sublingual_db()$master
  m3 <- m1
  m3$basic_price <- m3$basic_price * 3L
  db1 <- structure(list(master = m1, loaded_at = NULL), class = "dmd_db")
  db3 <- structure(list(master = m3, loaded_at = NULL), class = "dmd_db")

  expect_equal(.cost_8mg("dmd_dose_cost", db1), 700)
  expect_equal(.cost_8mg("dmd_dose_cost", db3), 2100)
})

test_that("as_dmd_db()s sharing a loaded_at keep their own prices (#29)", {
  .local_fresh_dose_cache()
  ts <- as.POSIXct("2026-01-01 12:00:00", tz = "UTC")
  m1 <- .fake_sublingual_db()$master
  m3 <- m1
  m3$basic_price <- m3$basic_price * 3L
  db1 <- as_dmd_db(m1, loaded_at = ts)
  db3 <- as_dmd_db(m3, loaded_at = ts)

  expect_equal(.cost_8mg("dmd_dose_cost", db1), 700)
  expect_equal(.cost_8mg("dmd_dose_cost", db3), 2100)
})

# ── #30: fixtures sharing .fixed_loaded_at ────────────────────────────────────

test_that("fixtures sharing .fixed_loaded_at do not share candidates (#30)", {
  .local_fresh_dose_cache()
  base <- .fake_container_pack_db()
  wide <- base
  wide$master <- rbind(
    base$master,
    tibble::tibble(
      medicine = "Enoxaparin sodium 80mg/0.8ml solution for injection pre-filled syringes",
      pack_size = 10,
      unit = "pre-filled disposable injection",
      vmp_snomed_code = "V80",
      vmpp_snomed_code = "VPP80",
      drug_tariff_category = "Part VIIIA Category C",
      basic_price = 5513L,
      nhs_indicative_price = 5513L,
      price_basis = "NHS Indicative Price",
      price_date = "2025-08-08",
      ampp_name = "Enoxaparin 80mg/0.8ml pre-filled syringes 10 pre-filled disposable injection",
      ampp_snomed_code = "APP_SYR80"
    )
  )
  expect_identical(wide$loaded_at, base$loaded_at)

  candidates <- function(db) {
    .dmd_prepare_candidates_memo(
      query = "enoxaparin",
      db = db,
      method = "partial",
      max_dist = 3,
      active_only = TRUE,
      price = "basic_price"
    )
  }
  n_base <- nrow(candidates(base))
  n_wide <- nrow(candidates(wide))
  expect_equal(n_wide, n_base + 1L)
})

# ── Equal content still shares the cache ──────────────────────────────────────

test_that("equal content shares a key across loaded_at values and wrappers", {
  .local_fresh_dose_cache()
  a <- .fake_dose_db()
  b <- .fake_dose_db(loaded_at = .fixed_loaded_at + 3600)

  expect_identical(.db_cache_key(b), .db_cache_key(a))
  # The memoised step reads only the searched table, so a <dmd_db> and its
  # bare $master share entries.
  expect_identical(.db_cache_key(a$master), .db_cache_key(a))

  dmd_dose_cost(
    "metformin",
    dose = 1000,
    dose_unit = "mg",
    db = a,
    quiet = TRUE
  )
  expect_true(.has_candidates("metformin", b))
  expect_true(.has_candidates("metformin", a$master))
})

test_that("a table keeps its key after an ALTREP column is materialised", {
  .local_fresh_dose_cache()
  db <- .fake_dose_db()
  # Precondition: the fixture's vmp_snomed_code (as.character(seq_len())) is
  # an ALTREP deferred string, which rlang::hash() serialises differently once
  # the optimiser has read its elements.
  hash_before <- rlang::hash(db$master)
  key_before <- .db_cache_key(db)
  dmd_dose_optimise(
    "metformin",
    dose = 500,
    dose_unit = "mg",
    db = db,
    quiet = TRUE
  )
  skip_if(
    identical(rlang::hash(db$master), hash_before),
    "The fixture has no ALTREP column whose hash changes once materialised."
  )

  expect_identical(.db_cache_key(db), key_before)
  expect_true(.has_candidates("metformin", db))
})

# ── The identity checks ───────────────────────────────────────────────────────

test_that("bundled dmd_master keys by identity; a modified copy by content", {
  .local_fresh_dose_cache()
  expect_identical(.db_cache_key(dmdprices::dmd_master), "bundled")
  wrapped <- structure(list(master = dmdprices::dmd_master), class = "dmd_db")
  expect_identical(.db_cache_key(wrapped), "bundled")

  m <- dmdprices::dmd_master
  i <- which(!is.na(m$basic_price))[[1]]
  m$basic_price[i] <- m$basic_price[i] + 1L
  expect_match(.db_cache_key(m), "^content:[0-9a-f]+$")
})

test_that("an unloaded bundled table is not loaded just to key another table", {
  # Installed, the bundled dmd_master is an unforced promise in the
  # namespace's lazy-data environment until it is first used. Keying a
  # custom table must not force it (about 45 MB). Under load_all() the
  # binding is not lazy, so this builds a lazy-data environment of its own.
  .local_fresh_dose_cache()
  lazydata <- new.env(parent = emptyenv())
  delayedAssign(
    "dmd_master",
    stop("The bundled table was loaded."),
    assign.env = lazydata
  )
  expect_false(.bundled_is_loaded(lazydata))
  expect_true(rlang::env_binding_are_lazy(lazydata, "dmd_master"))
  expect_null(.db_key_memo$bundled_loaded)

  # Until then a custom table is keyed by content, and so is a copy of the
  # bundled table loaded separately (e.g. with data()).
  local_mocked_bindings(.bundled_is_loaded = function(lazydata = NULL) FALSE)
  db <- .fake_sublingual_db()
  expect_identical(
    .db_cache_key(db),
    paste0("content:", rlang::hash(db$master))
  )
  expect_match(.db_cache_key(dmdprices::dmd_master), "^content:[0-9a-f]+$")
})

test_that("the bundled table counts as loaded once forced, and stays so", {
  .local_fresh_dose_cache()
  lazydata <- new.env(parent = emptyenv())
  delayedAssign("dmd_master", data.frame(x = 1), assign.env = lazydata)
  expect_false(.bundled_is_loaded(lazydata))

  get("dmd_master", envir = lazydata)
  expect_true(.bundled_is_loaded(lazydata))
  expect_true(.db_key_memo$bundled_loaded)

  # Remembered: an environment that still holds a promise is not inspected.
  unforced <- new.env(parent = emptyenv())
  delayedAssign("dmd_master", stop("Inspected."), assign.env = unforced)
  expect_true(.bundled_is_loaded(unforced))

  # No lazy-data binding (or no environment) counts as loaded.
  .forget_dose_cache()
  expect_null(.db_key_memo$bundled_loaded)
  expect_true(.bundled_is_loaded(new.env(parent = emptyenv())))
  .forget_dose_cache()
  expect_true(.bundled_is_loaded(list()))
})

test_that("keying the bundled table leaves the remembered table in place", {
  .local_fresh_dose_cache()
  db <- .fake_sublingual_db()
  key <- .db_cache_key(db)

  expect_identical(.db_cache_key(dmdprices::dmd_master), "bundled")
  expect_identical(.db_key_memo$key, key)
})

test_that("repeat calls on a table use the remembered key; edits re-hash", {
  .local_fresh_dose_cache()
  db <- .fake_sublingual_db()
  key <- .db_cache_key(db)
  expect_identical(key, paste0("content:", rlang::hash(db$master)))

  # A sentinel in the slot shows the second call never reaches rlang::hash().
  .db_key_memo$key <- "content:sentinel"
  expect_identical(.db_cache_key(db), "content:sentinel")

  db$master$basic_price[[4]] <- 4901L
  rehashed <- paste0("content:", rlang::hash(db$master))
  expect_identical(.db_cache_key(db), rehashed)
  expect_identical(.db_key_memo$key, rehashed)
})

test_that("a data.table is hashed on every call and never remembered", {
  # data.table's `:=` and set() edit a table in place, so an object compared
  # with identical() against a remembered reference to itself would match
  # after a price edit. data.table is not a dependency: its class is enough to
  # exercise the guard.
  .local_fresh_dose_cache()
  m <- .fake_sublingual_db()$master
  class(m) <- c("data.table", "data.frame")

  expect_match(.db_cache_key(m), "^content:[0-9a-f]+$")
  expect_null(.db_key_memo$master)
  expect_match(
    .db_cache_key(structure(list(master = m), class = "dmd_db")),
    "^content:[0-9a-f]+$"
  )
  expect_null(.db_key_memo$master)
})

test_that("an invalid db does not evict the remembered table", {
  .local_fresh_dose_cache()
  db <- .fake_sublingual_db()
  key <- .db_cache_key(db)

  expect_match(.db_cache_key("not a table"), "^content:[0-9a-f]+$")
  expect_error(
    dmd_dose_cost(.bup_8mg, dose = 8, dose_unit = "mg", db = list(1)),
    "must be a"
  )
  expect_identical(.db_key_memo$key, key)
})

test_that(".forget_dose_cache() empties the memo and the remembered key", {
  .local_fresh_dose_cache()
  db <- .fake_sublingual_db()
  .cost_8mg("dmd_dose_cost", db)
  expect_true(.has_candidates(.bup_8mg, db, method = "exact"))
  expect_false(is.null(.db_key_memo$key))

  .forget_dose_cache()
  expect_null(.db_key_memo$key)
  expect_null(.db_key_memo$master)
  expect_false(.has_candidates(.bup_8mg, db, method = "exact"))
})
