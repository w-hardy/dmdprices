#' NHS Cost Inflation Index (NHS CII) annual rates
#'
#' Internal annual percentage rates used by [nhscii()] and [inflate_nhscii()].
#' Values currently cover financial years 2015/16 to 2023/24.
#'
#' @details
#' Source: Jones KC et al. (2025). Unit Costs of Health and Social Care 2024
#' Manual. PSSRU (University of Kent) & Centre for Health Economics (University
#' of York). (\doi{10.22024/UniKent/01.02.109563}).
#' Licensed under CC BY-NC-SA 4.0.
#'
#' Per the PSSRU manual, the 2023/24 values are provisional. This is standard
#' for each annual publication, and later manuals may revise values when
#' additional data become available.
#'
#' @keywords internal
.nhscii_rates <- list(
  pay_and_prices = stats::setNames(
    c(0.40, 2.09, 1.24, 1.60, 2.14, 2.49, 2.58, 7.32, 4.31),
    c(
      "2015/16",
      "2016/17",
      "2017/18",
      "2018/19",
      "2019/20",
      "2020/21",
      "2021/22",
      "2022/23",
      "2023/24"
    )
  ),
  prices = stats::setNames(
    c(0.56, 2.06, 1.30, 1.59, 1.30, 0.84, 1.72, 7.15, 3.45),
    c(
      "2015/16",
      "2016/17",
      "2017/18",
      "2018/19",
      "2019/20",
      "2020/21",
      "2021/22",
      "2022/23",
      "2023/24"
    )
  ),
  pay = stats::setNames(
    c(0.30, 2.10, 1.21, 1.60, 2.58, 3.41, 3.07, 7.41, 4.79),
    c(
      "2015/16",
      "2016/17",
      "2017/18",
      "2018/19",
      "2019/20",
      "2020/21",
      "2021/22",
      "2022/23",
      "2023/24"
    )
  )
)

validate_scalar <- function(x, arg) {
  if (length(x) != 1L || is.na(x)) {
    stop(arg, " must be a single non-missing value.", call. = FALSE)
  }
}

normalize_fin_year <- function(x, arg = "year") {
  validate_scalar(x, arg)

  if (is.numeric(x)) {
    if (!is.finite(x) || x %% 1 != 0 || x < 1900 || x > 3000) {
      stop(arg, " numeric input must be a whole year like 2025.", call. = FALSE)
    }

    # Numeric input is interpreted as end-year:
    # 2025 -> "2024/25"
    y_end <- as.integer(x)
    return(sprintf("%d/%02d", y_end - 1L, y_end %% 100L))
  }

  x <- as.character(x)

  if (!grepl("^\\d{4}/\\d{2}$", x)) {
    stop(
      arg,
      " must be in 'YYYY/YY' format or a numeric end-year (e.g. 2025).",
      call. = FALSE
    )
  }

  x
}

build_index_levels <- function(rates) {
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
#' Data source: Jones KC et al. (2025). Unit Costs of Health and Social Care
#' 2024 Manual. PSSRU (University of Kent) & Centre for Health Economics
#' (University of York). (\doi{10.22024/UniKent/01.02.109563}).
#' Licensed under CC BY-NC-SA 4.0.
#'
#' The 2023/24 figures are provisional and may be revised in later PSSRU
#' releases as additional data become available.
#'
#' @examples
#' nhscii("2019/20", "2023/24")
#' nhscii(2020, 2024) # same as "2019/20" -> "2023/24"
#' nhscii("2021/22", "2023/24", index = "pay", output_type = "percent")
#'
#' @export
nhscii <- function(
  from_year,
  to_year,
  index = "pay_and_prices",
  output_type = c("factor", "percent")
) {
  validate_scalar(index, "index")

  output_type <- match.arg(output_type, c("factor", "percent"))
  index <- match.arg(index, names(.nhscii_rates))

  from_year <- normalize_fin_year(from_year, "from_year")
  to_year <- normalize_fin_year(to_year, "to_year")

  rates <- .nhscii_rates[[index]]
  valid_years <- names(rates)

  if (!from_year %in% valid_years) {
    stop(
      "from_year must be one of: ",
      paste(valid_years, collapse = ", "),
      call. = FALSE
    )
  }

  if (!to_year %in% valid_years) {
    stop(
      "to_year must be one of: ",
      paste(valid_years, collapse = ", "),
      call. = FALSE
    )
  }

  levels <- build_index_levels(rates)
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
    stop("cost must be a numeric vector of finite values.", call. = FALSE)
  }

  factor <- nhscii(
    from_year = from_year,
    to_year = to_year,
    index = index,
    output_type = "factor"
  )

  cost * factor
}
