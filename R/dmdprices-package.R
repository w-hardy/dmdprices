#' dmdprices: Look Up Medicine Prices from the NHS dm+d
#'
#' `dmdprices` provides two main functions:
#'
#' * [dmd_load()] — reads the CSV output of the NHSBSA dm+d extract tool and
#'   builds a joined pricing database.
#' * [dmd_price_lookup()] — queries that database by medicine name, returning a
#'   tibble in Drug Tariff Part VIIIA format.
#'
#' ## Typical workflow
#'
#' ```r
#' library(dmdprices)
#'
#' # Load once per session (or set options(dmdprices.path = "...") in .Rprofile)
#' db <- dmd_load("path/to/dmdDataLoader")
#'
#' # Query
#' dmd_price_lookup(db, "metformin")
#' ```
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom dplyr arrange filter group_by inner_join join_by left_join
#'   mutate n_distinct rename select slice_max ungroup coalesce
#' @importFrom readr col_character cols read_delim
#' @importFrom rlang .data is_string `:=`
#' @importFrom stringr regex str_detect str_squish str_to_lower str_to_upper
#' @importFrom cli cli_abort cli_inform cli_progress_step cli_warn
#' @importFrom stringdist stringdist
## usethis namespace: end
NULL
