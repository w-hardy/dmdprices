# input validation fails gracefully

    Code
      nhscii("2020-21", "2021/22")
    Condition
      Error in `nhscii()`:
      ! `from_year` is not a valid financial year.
      i Use "YYYY/YY" format (e.g. "2019/20") or a numeric end-year (e.g. 2025).

---

    Code
      nhscii("2010/11", "2021/22")
    Condition
      Error in `nhscii()`:
      ! `from_year` ("2010/11") is not a known financial year.
      i Use one of "2014/15", "2015/16", "2016/17", "2017/18", "2018/19", "2019/20", "2020/21", "2021/22", "2022/23", "2023/24", and "2024/25".

---

    Code
      nhscii("2020/21", "2021/22", index = "unknown")
    Condition
      Error in `match.arg()`:
      ! 'arg' should be one of "pay_and_prices", "prices", "pay"

---

    Code
      inflate_nhscii(c(100, NA_real_), "2020/21", "2021/22")
    Condition
      Error in `inflate_nhscii()`:
      ! `cost` must be a numeric vector of finite values.

