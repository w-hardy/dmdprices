library(shiny)
library(dmdprices)

fin_years <- names(dmdprices:::.nhscii_rates$pay_and_prices)

ui <- fluidPage(
  theme = bslib::bs_theme(version = 5),
  titlePanel("NHS Cost Inflation Index — Cost Adjuster"),
  tags$div(
    class = "alert alert-warning alert-dismissible fade show mt-2",
    role = "alert",
    tags$strong("⚠️ Under development — not validated."),
    " This tool has not been formally validated. Outputs should be",
    " independently verified before use in research or clinical decision-making.",
    " Use at your own risk.",
    tags$button(
      type = "button",
      class = "btn-close",
      `data-bs-dismiss` = "alert",
      `aria-label` = "Close"
    )
  ),
  sidebarLayout(
    sidebarPanel(
      width = 4,
      numericInput(
        "cost",
        "Cost (£)",
        value = 100,
        min = 0,
        step = 1
      ),
      selectInput(
        "from_year",
        "From financial year",
        choices = fin_years,
        selected = fin_years[length(fin_years) - 1]
      ),
      selectInput(
        "to_year",
        "To financial year",
        choices = fin_years,
        selected = fin_years[length(fin_years)]
      ),
      selectInput(
        "index",
        "NHS CII index",
        choices = c(
          "Pay and prices (default)" = "pay_and_prices",
          "Pay only" = "pay",
          "Prices only" = "prices"
        ),
        selected = "pay_and_prices"
      ),
      hr(),
      helpText(
        tags$b("Source:"),
        "Jones et al. (2025).",
        tags$a(
          "Unit Costs of Health and Social Care 2024 Manual.",
          href = "https://doi.org/10.22024/UniKent/01.02.109563",
          target = "_blank"
        ),
        "PSSRU (University of Kent) & Centre for Health Economics (University of York).",
        tags$a(
          "CC BY-NC-SA 4.0.",
          href = "https://creativecommons.org/licenses/by-nc-sa/4.0/",
          target = "_blank"
        ),
        tags$br(),
        "2023/24 figures are provisional.",
        tags$br(),
        tags$a(
          "Report issues on GitHub.",
          href = "https://github.com/w-hardy/dmdprices/issues",
          target = "_blank"
        )
      )
    ),
    mainPanel(
      width = 8,
      uiOutput("result_card"),
      uiOutput("error_msg")
    )
  )
)

server <- function(input, output, session) {
  calc <- reactive({
    req(is.numeric(input$cost), is.finite(input$cost), input$cost >= 0)

    tryCatch(
      list(
        factor = nhscii(input$from_year, input$to_year, input$index, "factor"),
        percent = nhscii(
          input$from_year,
          input$to_year,
          input$index,
          "percent"
        ),
        result = inflate_nhscii(
          input$cost,
          input$from_year,
          input$to_year,
          input$index
        )
      ),
      error = function(e) list(error = conditionMessage(e))
    )
  })

  output$error_msg <- renderUI({
    r <- calc()
    if (!is.null(r$error)) {
      tags$p(class = "text-danger mt-3", r$error)
    }
  })

  output$result_card <- renderUI({
    r <- calc()
    req(is.null(r$error))

    direction <- if (r$percent >= 0) "increase" else "decrease"
    pct_text <- sprintf("%.2f%%", abs(r$percent))

    div(
      class = "card mt-3",
      div(
        class = "card-body",
        tags$h5(class = "card-title", "Result"),
        tags$table(
          class = "table table-sm",
          tags$tbody(
            tags$tr(
              tags$th("Original cost"),
              tags$td(sprintf("£%.4f", input$cost))
            ),
            tags$tr(
              tags$th("Adjusted cost"),
              tags$td(
                class = "fw-bold",
                sprintf("£%.4f", r$result)
              )
            ),
            tags$tr(
              tags$th("Inflation factor"),
              tags$td(sprintf("%.6f", r$factor))
            ),
            tags$tr(
              tags$th("Percentage change"),
              tags$td(
                class = if (r$percent >= 0) "text-danger" else "text-success",
                sprintf("%+.2f%% (%s)", r$percent, direction)
              )
            ),
            tags$tr(
              tags$th("Period"),
              tags$td(sprintf("%s \u2192 %s", input$from_year, input$to_year))
            ),
            tags$tr(
              tags$th("Index"),
              tags$td(input$index)
            )
          )
        )
      )
    )
  })
}

shinyApp(ui, server)
