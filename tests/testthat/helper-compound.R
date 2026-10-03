# Fake dmd_db for #27: names that carry more than one strength token. Names
# are real dm+d VMP names; rows and prices are fake.
# - eptacog alfa: a mass strength restated in activity units in brackets, as
#   1 / 2 / 5 mg syringes at 500 / 1000 / 2500 pence (a flat 500p per mg);
# - iohexol: a per-ml strength with the iodine content in brackets, a
#   competing same-dimension basis, so it stays skipped as a compound;
# - a titration pack and a co-pack, which stay skipped as multi-product packs.
# Its own loaded_at keeps its dose-cache key apart from the other fixtures
# while the cache is keyed on loaded_at (#30).
.fake_multi_strength_db <- function(loaded_at = .fixed_loaded_at + 27) {
  master <- tibble::tibble(
    medicine = c(
      "Eptacog alfa (activated) 1mg (50,000unit) powder and solvent for solution for injection pre-filled syringes",
      "Eptacog alfa (activated) 2mg (100,000unit) powder and solvent for solution for injection pre-filled syringes",
      "Eptacog alfa (activated) 5mg (250,000unit) powder and solvent for solution for injection pre-filled syringes",
      "Iohexol 755mg/ml (Iodine 350mg/ml) solution for injection 50ml bottles",
      "Danicopan 50mg tablets and Danicopan 100mg tablets",
      "Tixagevimab 150mg/1.5ml solution for injection vials and Cilgavimab 150mg/1.5ml solution for injection vials"
    ),
    pack_size = c(1, 1, 1, 10, 84, 1),
    unit = c(
      "pre-filled disposable injection",
      "pre-filled disposable injection",
      "pre-filled disposable injection",
      "bottle",
      "tablet",
      "pack"
    ),
    vmp_snomed_code = paste0("V", 1:6),
    vmpp_snomed_code = paste0("VPP", 1:6),
    drug_tariff_category = rep("Part VIIIA Category M", 6),
    basic_price = c(500L, 1000L, 2500L, 30000L, 900L, 1000L),
    nhs_indicative_price = c(500L, 1000L, 2500L, 30000L, 900L, 1000L),
    price_basis = rep("NHS Indicative Price", 6),
    price_date = rep("2025-08-08", 6),
    ampp_name = paste("Fake AMPP", 1:6),
    ampp_snomed_code = paste0("APP", 1:6),
    is_combination = rep(FALSE, 6)
  )
  structure(list(master = master, loaded_at = loaded_at), class = "dmd_db")
}
