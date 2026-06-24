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
    function(i) sprintf("%g \u00d7 %s", comb$count[i], comb$ampp_name[i]),
    character(1)
  )
  paste(lines, collapse = "<br>")
}

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
      checkboxGroupInput(
        "objective", "Objectives",
        choices  = c(
          "Cheapest"       = "cheapest",
          "Min items"      = "min_items",
          "Most expensive" = "most_expensive"
        ),
        selected = c("cheapest", "min_items")
      ),
      checkboxInput("can_split", "Allow pack splitting (hospital)", value = TRUE),
      checkboxInput("can_split_vials", "Allow vial sharing (concentration preps)", value = FALSE),
      textInput(
        "preparation", "Filter by preparation (optional)",
        placeholder = "e.g. tablet|modified-release|oral"
      ),

      hr(),

      actionButton("go", "Optimise", class = "btn-primary w-100"),

      hr(),

      helpText(
        tags$b("Data:"), " NHS dm+d Week 15 2026 (06 April 2026).",
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

      uiOutput("messages"),

      uiOutput("result_header"),

      DTOutput("results_table"),

      uiOutput("rounding_note"),

      # Detail panel — shown only when a row is selected
      uiOutput("combination_panel")
    )
  )
)

# ── Server ───────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  optimised <- eventReactive(input$go, {
    req(
      nchar(trimws(input$query)) > 0,
      !is.na(input$dose),
      input$dose > 0
    )

    objs <- input$objective
    if (is.null(objs) || length(objs) == 0L) {
      objs <- "cheapest"
    }

    prep_filter <- if (nzchar(trimws(input$preparation))) trimws(input$preparation) else NULL

    capture_conditions(
      dmd_dose_optimise(
        query          = trimws(input$query),
        dose           = input$dose,
        dose_unit      = input$dose_unit,
        method         = input$method,
        active_only    = input$active_only,
        price          = input$price,
        objective      = objs,
        preparation    = prep_filter,
        can_split      = input$can_split,
        can_split_vials = input$can_split_vials
      )
    )
  })

  results <- reactive(optimised()$value)

  output$messages <- renderUI({
    render_callouts(optimised()$messages)
  })

  # ── Header ─────────────────────────────────────────────────────────────────
  output$result_header <- renderUI({
    res <- results()
    if (is.null(res)) return(NULL)

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

  output$rounding_note <- renderUI({
    res <- results()
    if (is.null(res) || !is.data.frame(res) || nrow(res) == 0) return(NULL)
    tags$p(
      class = "text-muted mt-1 small",
      tags$em(
        "Note: 'Dose delivered', 'Over-delivery' and 'Cost (pence)' are rounded for display ",
        "(2 d.p., 2 d.p., and 1 d.p. respectively). Full-precision values are preserved in ",
        "CSV/Excel exports and in the underlying R object returned by ",
        tags$code("dmd_dose_optimise()"), "."
      )
    )
  })

  # ── Combination detail panel (selected row) ────────────────────────────────────────────
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
        DTOutput("combination_table")
      )
    )
  })

  output$combination_table <- renderDT({
    res <- results()
    req(is.data.frame(res), nrow(res) > 0)

    sel <- input$results_table_rows_selected
    req(length(sel) > 0)

    comb <- res$combination[[sel]]
    req(!is.null(comb), nrow(comb) > 0)

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
  })
}

shinyApp(ui, server)
