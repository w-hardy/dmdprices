# Launch the NHS CII cost adjuster Shiny app

Opens an interactive browser-based interface for inflating or deflating
costs between financial years using
[`inflate_nhscii()`](https://w-hardy.github.io/dmdprices/reference/inflate_nhscii.md)
and
[`nhscii()`](https://w-hardy.github.io/dmdprices/reference/nhscii.md).

## Usage

``` r
run_inflate_nhscii()
```

## Value

Starts the Shiny app (does not return a value).

## Examples

``` r
if (interactive()) {
  run_inflate_nhscii()
}
```
