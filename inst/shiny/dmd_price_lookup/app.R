library(shiny)
library(dmdprices)
library(DT)

ui <- fluidPage(
  theme = bslib::bs_theme(version = 5),
  titlePanel("dm+d Medicine Price Lookup"),
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
        tags$b("Data:"), "NHS dm+d Week 34 2025 (14 August 2025).",
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
      uiOutput("result_header"),
      DTOutput("results_table")
    )
  )
)

server <- function(input, output, session) {
  results <- eventReactive(input$search, {
    req(nchar(trimws(input$query)) > 0)

    tryCatch(
      dmd_price_lookup(
        query = trimws(input$query),
        method = input$method,
        active_only = input$active_only
      ),
      error = function(e) NULL
    )
  })

  output$result_header <- renderUI({
    res <- results()
    if (is.null(res)) {
      tags$p(
        class = "text-danger mt-2",
        "Search returned an error. Check your query."
      )
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
