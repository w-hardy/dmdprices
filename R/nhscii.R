#' NHS Cost Inflation Index (NHS CII) annual rates
#'
#' Internal annual percentage rates used by [nhscii()] and [inflate_nhscii()].
#' Values currently cover financial years 2014/15 to 2024/25.
#'
#' @details
#' Source: Jones KC et al. (2026). Unit Costs of Health and Social Care 2025
#' Manual. PSSRU (University of Kent) & Centre for Health Economics (University
#' of York). \doi{10.22024/UniKent/01.02.115569}.
#' Licensed under CC BY-NC-SA 4.0.
#'
#' Per the PSSRU manual, the most recent year's values (currently 2024/25) are
#' provisional. This is standard for each annual publication: the latest year
#' is provisional and is typically revised in the following year's manual, after
#' which it remains stable. Accordingly, the 2023/24 figures published as
#' provisional in the previous manual have been revised here using the 2025
#' manual.
#'
#' @keywords internal
#' @noRd
.nhscii_rates <- list(
  pay_and_prices = stats::setNames(
    c(NA_real_, 0.40, 2.09, 1.24, 1.60, 2.14, 2.49, 2.58, 7.32, 2.47, 4.02),
    c(
      "2014/15",
      "2015/16",
      "2016/17",
      "2017/18",
      "2018/19",
      "2019/20",
      "2020/21",
      "2021/22",
      "2022/23",
      "2023/24",
      "2024/25"
    )
  ),
  prices = stats::setNames(
    c(NA_real_, 0.56, 2.06, 1.30, 1.59, 1.30, 0.84, 1.72, 7.15, 2.98, 2.04),
    c(
      "2014/15",
      "2015/16",
      "2016/17",
      "2017/18",
      "2018/19",
      "2019/20",
      "2020/21",
      "2021/22",
      "2022/23",
      "2023/24",
      "2024/25"
    )
  ),
  pay = stats::setNames(
    c(NA_real_, 0.30, 2.10, 1.21, 1.60, 2.58, 3.41, 3.07, 7.41, 2.18, 5.11),
    c(
      "2014/15",
      "2015/16",
      "2016/17",
      "2017/18",
      "2018/19",
      "2019/20",
      "2020/21",
      "2021/22",
      "2022/23",
      "2023/24",
      "2024/25"
    )
  )
)

.validate_scalar <- function(x, arg, call = rlang::caller_env()) {
  if (length(x) != 1L || is.na(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be a single, non-missing value.",
      call = call
    )
  }
}

.normalize_fin_year <- function(x, arg = "year", call = rlang::caller_env()) {
  .validate_scalar(x, arg, call = call)

  if (is.numeric(x)) {
    if (!is.finite(x) || x %% 1 != 0 || x < 1900 || x > 3000) {
      cli::cli_abort(
        c(
          "{.arg {arg}} must be a whole calendar year.",
          "i" = "Pass a four-digit end-year such as {.val {2025}}."
        ),
        call = call
      )
    }

    # Numeric input is interpreted as end-year:
    # 2025 -> "2024/25"
    y_end <- as.integer(x)
    return(sprintf("%d/%02d", y_end - 1L, y_end %% 100L))
  }

  x <- as.character(x)

  if (!grepl("^\\d{4}/\\d{2}$", x)) {
    cli::cli_abort(
      c(
        "{.arg {arg}} is not a valid financial year.",
        "i" = "Use {.val YYYY/YY} format (e.g. {.val 2019/20}) or a numeric \\
               end-year (e.g. {.val {2025}})."
      ),
      call = call
    )
  }

  x
}

.build_index_levels <- function(rates) {
  years <- names(rates)

  # Rates are interpreted as changes into each named year.
  # First available year is treated as the base (level = 1).
  levels <- c(1, 1 + unname(rates[-1]) / 100) |>
    cumprod()

  stats::setNames(levels, years)
}

#' NHS Cost Inflation Index factor between two financial years
#'
#' Returns the inflation adjustment as a multiplicative factor by default.
#' For example, a value of `1.125` means a 12.5% increase.
#'
#' @param from_year Financial year in `"YYYY/YY"` format (e.g. `"2019/20"`) or
#'   numeric end-year (e.g. `2020`, interpreted as `"2019/20"`).
#' @param to_year Financial year in `"YYYY/YY"` format (e.g. `"2023/24"`) or
#'   numeric end-year (e.g. `2024`, interpreted as `"2023/24"`).
#' @param index Character scalar. One of `"pay_and_prices"` (default), `"pay"`,
#'   or `"prices"`.
#' @param output_type Character scalar. `"factor"` (default) for multiplicative
#'   factor, or `"percent"` for percentage change.
#'
#' @return A numeric scalar:
#' - if `output_type = "factor"` (default): multiplicative factor
#' - if `output_type = "percent"`: percentage change
#'
#' @details
#' Data source: Jones KC et al. (2026). Unit Costs of Health and Social Care
#' 2025 Manual. PSSRU (University of Kent) & Centre for Health Economics
#' (University of York). \doi{10.22024/UniKent/01.02.115569}.
#' Licensed under CC BY-NC-SA 4.0.
#'
#' The most recent year's figures (currently 2024/25) are provisional and may
#' be revised in the next PSSRU release as additional data become available.
#'
#' @examples
#' nhscii("2019/20", "2024/25")
#' nhscii(2020, 2025) # same as "2019/20" -> "2024/25"
#' nhscii("2021/22", "2024/25", index = "pay", output_type = "percent")
#'
#' @export
nhscii <- function(
  from_year,
  to_year,
  index = "pay_and_prices",
  output_type = c("factor", "percent")
) {
  .validate_scalar(index, "index")

  output_type <- match.arg(output_type, c("factor", "percent"))
  index <- match.arg(index, names(.nhscii_rates))

  from_year <- .normalize_fin_year(from_year, "from_year")
  to_year <- .normalize_fin_year(to_year, "to_year")

  rates <- .nhscii_rates[[index]]
  valid_years <- names(rates)

  if (!from_year %in% valid_years) {
    cli::cli_abort(c(
      "{.arg from_year} ({.val {from_year}}) is not a known financial year.",
      "i" = "Use one of {.val {valid_years}}."
    ))
  }

  if (!to_year %in% valid_years) {
    cli::cli_abort(c(
      "{.arg to_year} ({.val {to_year}}) is not a known financial year.",
      "i" = "Use one of {.val {valid_years}}."
    ))
  }

  levels <- .build_index_levels(rates)
  factor <- unname(levels[[to_year]] / levels[[from_year]])

  if (identical(output_type, "percent")) {
    (factor - 1) * 100
  } else {
    factor
  }
}

#' Inflate or deflate a cost using NHS CII
#'
#' Adjusts a cost value from one financial year to another using [nhscii()].
#'
#' @param cost Numeric vector of finite costs.
#' @param from_year Financial year in `"YYYY/YY"` format or numeric end-year.
#' @param to_year Financial year in `"YYYY/YY"` format or numeric end-year.
#' @param index Character scalar. One of `"pay_and_prices"` (default), `"pay"`,
#'   or `"prices"`.
#'
#' @return Numeric vector of costs adjusted to `to_year`.
#'
#' @examples
#' inflate_nhscii(100, "2019/20", "2023/24")
#' inflate_nhscii(c(100, 250), from_year = 2020, to_year = 2024, index = "prices")
#'
#' @export
inflate_nhscii <- function(
  cost,
  from_year,
  to_year,
  index = "pay_and_prices"
) {
  if (!is.numeric(cost) || any(!is.finite(cost))) {
    cli::cli_abort("{.arg cost} must be a numeric vector of finite values.")
  }

  factor <- nhscii(
    from_year = from_year,
    to_year = to_year,
    index = index,
    output_type = "factor"
  )

  cost * factor
}
