library(shiny)
library(rmarkdown)
library(shinyjs)
library(tools)

shinyServer(function(input, output, session) {
  
  observe({
    session$sendCustomMessage("toggle-dark-mode", input$darkmode)
  })
  
  observeEvent(input$darkmode, {
    session$sendCustomMessage("toggle-dark-mode", input$darkmode)
  })
  
  # Reactive for uploaded data (hardcoded header = TRUE, stringsAsFactors = FALSE)
  uploaded_data <- reactive({
    req(input$file)
    read.csv(input$file$datapath)
  })
  
  # Show preview with spinner
  output$contents <- renderTable({
    head(uploaded_data(), 10)
  })
  
  # Report generation
  output$downloadReport <- downloadHandler(
    filename = function() {
      paste0("stravaReport_", file_path_sans_ext(input$file$name), ".html")
    },
    content = function(file) {
      tempReport <- file.path(tempdir(), "report.Rmd")
      
      if (!file.exists("strava_analysis.Rmd")) {
        stop("The strava_analysis.Rmd file is missing in the app directory.")
      }
      
      file.copy("strava_analysis.Rmd", tempReport, overwrite = TRUE)
      
      tempCSV <- file.path(tempdir(), "uploaded.csv")
      write.csv(uploaded_data(), tempCSV, row.names = FALSE)
      
      withProgress(message = "Generating report...", value = 0.5, {
        rmarkdown::render(tempReport,
                          output_file = file,
                          params = list(csv_path = tempCSV),
                          envir = new.env(parent = globalenv()))
      })
    }
  )
})
