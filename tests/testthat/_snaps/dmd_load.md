# dmd_load() errors informatively on bad path

    Code
      dmd_load("nonexistent/path")
    Condition
      Error in `dmd_load()`:
      ! 'nonexistent/path/csv' does not exist.
      i `path` should be the `dmdDataLoader` folder that contains a `csv/` subdirectory.

# dmd_load() errors when no path supplied and option unset

    Code
      dmd_load()
    Condition
      Error in `dmd_load()`:
      ! No path supplied.
      i Provide `path` or set `options(dmdprices.path = \"...\")`

