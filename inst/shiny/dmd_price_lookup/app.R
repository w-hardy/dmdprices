library(shiny)
library(dmdprices)
library(DT)

# ── condition capture → Bootstrap callouts ───────────────────────────────────
# Run `expr`, capturing cli/base warnings and errors so they can be surfaced in
# the UI. Returns list(value, messages); messages is a list of list(type, text).
capture_conditions <- function(expr) {
  msgs <- list()
  add <- function(type, text) {
    msgs[[length(msgs) + 1L]] <<- list(type = type, text = text)
  }
  value <- withCallingHandlers(
    tryCatch(
      expr,
      error = function(e) {
        add("danger", conditionMessage(e))
        NULL
      }
    ),
    warning = function(w) {
      add("warning", conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, messages = msgs)
}

# Render captured conditions as Bootstrap alert callout boxes.
render_callouts <- function(messages) {
  if (length(messages) == 0) {
    return(NULL)
  }
  lapply(messages, function(m) {
    label <- if (m$type == "danger") "⛔ Error" else "⚠️ Warning"
    tags$div(
      class = paste0("alert alert-", m$type, " mt-2"),
      role = "alert",
      tags$strong(paste0(label, ": ")),
      tags$span(style = "white-space: pre-wrap;", m$text)
    )
  })
}

ui <- fluidPage(
  theme = bslib::bs_theme(version = 5),
  titlePanel("dm+d Medicine Price Lookup"),
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
      width = 3,
      textInput(
        "query",
        "Medicine name",
        placeholder = "e.g. metformin 500mg"
      ),
      radioButtons(
        "method",
        "Match method",
        choices = c(
          "Partial" = "partial",
          "Exact" = "exact",
          "Fuzzy" = "fuzzy"
        ),
        selected = "partial"
      ),
      checkboxInput("active_only", "Active medicines only", value = TRUE),
      actionButton("search", "Search", class = "btn-primary w-100"),
      hr(),
      helpText(
        tags$b("Data:"),
        "NHS dm+d Week 15 2026 (06 April 2026).",
        "Prices are NHS Indicative or Drug Tariff Basic Prices (pence).",
        tags$br(),
        "© Crown copyright. NHS Business Services Authority (NHSBSA).",
        tags$a(
          "Open Government Licence v3.0.",
          href = "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/",
          target = "_blank"
        ),
        tags$br(),
        tags$a(
          "Report issues on GitHub.",
          href = "https://github.com/w-hardy/dmdprices/issues",
          target = "_blank"
        )
      )
    ),
    mainPanel(
      width = 9,
      uiOutput("messages"),
      uiOutput("result_header"),
      DTOutput("results_table")
    )
  )
)

server <- function(input, output, session) {
  search <- eventReactive(input$search, {
    req(nchar(trimws(input$query)) > 0)

    capture_conditions(
      dmd_price_lookup(
        query = trimws(input$query),
        method = input$method,
        active_only = input$active_only
      )
    )
  })

  results <- reactive(search()$value)

  output$messages <- renderUI({
    render_callouts(search()$messages)
  })

  output$result_header <- renderUI({
    res <- results()
    if (is.null(res)) {
      NULL
    } else if (nrow(res) == 0) {
      tags$p(
        class = "text-muted mt-2",
        "No medicines found. Try a different search term or match method."
      )
    } else {
      tags$p(
        class = "text-muted mt-2",
        sprintf("%d result%s", nrow(res), if (nrow(res) == 1) "" else "s")
      )
    }
  })

  output$results_table <- renderDT({
    res <- results()
    req(!is.null(res), nrow(res) > 0)

    res |>
      dplyr::select(
        Medicine = medicine,
        "Pack size" = pack_size,
        Unit = unit,
        Category = drug_tariff_category,
        "Basic price" = basic_price,
        "NHS ind. price" = nhs_indicative_price,
        "Price basis" = price_basis,
        "Price date" = price_date
      ) |>
      datatable(
        rownames = FALSE,
        filter = "top",
        extensions = "Buttons",
        options = list(
          dom = "Bfrtip",
          buttons = list("csv", "excel"),
          pageLength = 15,
          scrollX = TRUE
        )
      )
  })
}

shinyApp(ui, server)
