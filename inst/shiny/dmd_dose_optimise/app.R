library(shiny)
library(dmdprices)
library(DT)

# ── helpers ──────────────────────────────────────────────────────────────────

# Format combination list-column into a readable HTML string for display
fmt_combination <- function(comb) {
  if (is.null(comb) || !is.data.frame(comb) || nrow(comb) == 0) {
    return("—")
  }
  lines <- vapply(
    seq_len(nrow(comb)),
    function(i) sprintf("%d \u00d7 %s", comb$count[i], comb$ampp_name[i]),
    character(1)
  )
  paste(lines, collapse = "<br>")
}

warning_banner <- tags$div(
  class = "alert alert-warning alert-dismissible fade show mt-2",
  role  = "alert",
  tags$strong("\u26a0\ufe0f Under development — not validated."),
  " This tool has not been formally validated. Outputs should be independently",
  " verified before use in research or clinical decision-making. Use at your own risk.",
  tags$button(
    type           = "button",
    class          = "btn-close",
    `data-bs-dismiss` = "alert",
    `aria-label`   = "Close"
  )
)

# ── UI ───────────────────────────────────────────────────────────────────────

ui <- fluidPage(
  theme = bslib::bs_theme(version = 5),
  titlePanel("dm+d Dose Optimiser"),
  warning_banner,

  sidebarLayout(
    sidebarPanel(
      width = 3,

      # ── Search ──
      tags$h6("Search", class = "text-uppercase text-muted fw-bold mb-2"),
      textInput("query", "Medicine name", placeholder = "e.g. metformin"),
      radioButtons(
        "method", "Match method",
        choices  = c("Partial" = "partial", "Exact" = "exact", "Fuzzy" = "fuzzy"),
        selected = "partial"
      ),
      checkboxInput("active_only", "Active medicines only", value = TRUE),

      hr(),

      # ── Dose ──
      tags$h6("Dose", class = "text-uppercase text-muted fw-bold mb-2"),
      fluidRow(
        column(7, numericInput("dose", "Amount", value = NA, min = 0)),
        column(5, selectInput(
          "dose_unit", "Unit",
          choices  = c("mg", "microgram", "g", "ml", "unit"),
          selected = "mg"
        ))
      ),

      hr(),

      # ── Options ──
      tags$h6("Options", class = "text-uppercase text-muted fw-bold mb-2"),
      radioButtons(
        "price", "Price column",
        choices  = c("Basic price" = "basic_price", "NHS indicative" = "nhs_indicative_price"),
        selected = "basic_price"
      ),
      radioButtons(
        "objective", "Objective",
        choices  = c(
          "Both"       = "both",
          "Cheapest"   = "cheapest",
          "Min items"  = "min_items"
        ),
        selected = "both"
      ),
      checkboxInput("can_split", "Allow pack splitting (hospital)", value = TRUE),
      textInput(
        "preparation", "Filter by preparation (optional)",
        placeholder = "e.g. tablet|modified-release|oral"
      ),

      hr(),

      actionButton("go", "Optimise", class = "btn-primary w-100"),

      hr(),

      helpText(
        tags$b("Data:"), " NHS dm+d Week 34 2025 (14 August 2025).",
        " Prices are NHS Indicative or Drug Tariff Basic Prices (pence).",
        tags$br(),
        "\u00a9 Crown copyright. NHS Business Services Authority (NHSBSA).",
        tags$a(
          "Open Government Licence v3.0.",
          href   = "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/",
          target = "_blank"
        ),
        tags$br(),
        tags$a(
          "Report issues on GitHub.",
          href   = "https://github.com/w-hardy/dmdprices/issues",
          target = "_blank"
        )
      )
    ),

    mainPanel(
      width = 9,

      uiOutput("result_header"),

      DTOutput("results_table"),

      # Detail panel — shown only when a row is selected
      uiOutput("combination_panel")
    )
  )
)

# ── Server ───────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  results <- eventReactive(input$go, {
    req(
      nchar(trimws(input$query)) > 0,
      !is.na(input$dose),
      input$dose > 0
    )

    prep_filter <- if (nzchar(trimws(input$preparation))) trimws(input$preparation) else NULL

    tryCatch(
      dmd_dose_optimise(
        query       = trimws(input$query),
        dose        = input$dose,
        dose_unit   = input$dose_unit,
        method      = input$method,
        active_only = input$active_only,
        price       = input$price,
        objective   = input$objective,
        preparation = prep_filter,
        can_split   = input$can_split
      ),
      error = function(e) {
        list(error = conditionMessage(e))
      }
    )
  })

  # ── Header ─────────────────────────────────────────────────────────────────
  output$result_header <- renderUI({
    res <- results()
    if (is.null(res)) return(NULL)

    if (is.list(res) && !is.data.frame(res) && !is.null(res$error)) {
      return(tags$p(
        class = "text-danger mt-2",
        tags$b("Error: "), res$error
      ))
    }

    if (nrow(res) == 0) {
      return(tags$p(
        class = "text-muted mt-2",
        "No results. Try a different query, dose unit, or match method."
      ))
    }

    n_groups <- length(unique(res$preparation_group))
    tags$p(
      class = "text-muted mt-2",
      sprintf(
        "%d row%s across %d preparation group%s \u2014 dose: %s %s",
        nrow(res),
        if (nrow(res) == 1) "" else "s",
        n_groups,
        if (n_groups == 1) "" else "s",
        input$dose,
        input$dose_unit
      )
    )
  })

  # ── Table ──────────────────────────────────────────────────────────────────
  output$results_table <- renderDT({
    res <- results()
    req(is.data.frame(res), nrow(res) > 0)

    # Build combination summary column for display
    res$pack_detail <- vapply(
      res$combination,
      fmt_combination,
      character(1)
    )

    display <- res |>
      dplyr::select(
        "Medicine"          = medicine_root,
        "Preparation"       = preparation_label,
        "Objective"         = objective,
        "Dose delivered"    = dose_delivered,
        "Unit"              = dose_delivered_unit,
        "Over-delivery"     = over_delivery,
        "Items"             = total_items,
        "Cost (pence)"      = dose_cost_pence,
        "Price field"       = price_field_used,
        "Notes"             = notes,
        "Combination"       = pack_detail
      )

    datatable(
      display,
      rownames   = FALSE,
      escape     = FALSE,   # allow HTML in Combination column
      selection  = "single",
      extensions = "Buttons",
      options    = list(
        dom        = "Bfrtip",
        buttons    = list("csv", "excel"),
        pageLength = 15,
        scrollX    = TRUE,
        columnDefs = list(
          list(className = "dt-center", targets = c(3, 4, 5, 6, 7))
        )
      )
    ) |>
      formatRound(columns = c("Dose delivered", "Over-delivery"), digits = 2) |>
      formatRound(columns = "Cost (pence)", digits = 1)
  })

  # ── Combination detail panel (selected row) ────────────────────────────────
  output$combination_panel <- renderUI({
    res <- results()
    req(is.data.frame(res), nrow(res) > 0)

    sel <- input$results_table_rows_selected
    req(length(sel) > 0)

    row  <- res[sel, ]
    comb <- row$combination[[1]]

    if (is.null(comb) || nrow(comb) == 0) {
      return(tags$p(class = "text-muted mt-3", "No combination detail available."))
    }

    tags$div(
      class = "card mt-3",
      tags$div(
        class = "card-header",
        tags$b(sprintf(
          "Pack detail: %s \u2014 %s \u2014 %s",
          row$medicine_root,
          row$preparation_label,
          row$objective
        ))
      ),
      tags$div(
        class = "card-body p-0",
        DT::renderDT(
          datatable(
            comb,
            rownames  = FALSE,
            selection = "none",
            options   = list(
              dom        = "t",
              pageLength = 20,
              scrollX    = TRUE
            )
          )
        )
      )
    )
  })
}

shinyApp(ui, server)
