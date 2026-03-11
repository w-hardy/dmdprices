#' dmdprices: Look Up Medicine Prices from the NHS dm+d
#'
#' `dmdprices` provides tools for querying NHS medicine prices and adjusting
#' costs for inflation:
#'
#' * [dmd_price_lookup()] — search the bundled dm+d dataset by medicine name.
#' * [dmd_load()] — load a more recent dm+d release from a local
#'   `dmdDataLoader` CSV directory.
#' * [nhscii()] — compute NHS Cost Inflation Index factors between financial
#'   years.
#' * [inflate_nhscii()] — adjust costs using NHS CII rates.
#' * [run_dmd_price_lookup()] — launch the price lookup Shiny app locally.
#' * [run_inflate_nhscii()] — launch the cost adjuster Shiny app locally.
#'
#' ## Typical workflow
#'
#' ```r
#' library(dmdprices)
#'
#' # Search bundled data — no setup needed
#' dmd_price_lookup("metformin")
#'
#' # Adjust a cost for inflation
#' inflate_nhscii(100, "2019/20", "2023/24")
#'
#' # Load a more recent dm+d release
#' db <- dmd_load("path/to/dmdDataLoader")
#' dmd_price_lookup("metformin", db = db)
#' ```
#'
#' @seealso <https://w-hardy.github.io/dmdprices/>
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
