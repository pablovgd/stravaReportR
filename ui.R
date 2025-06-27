library(shiny)
library(shinythemes)
library(shinyjs)
library(shinycssloaders)

strava_orange <- "#FC4C02"

shinyUI(fluidPage(
  theme = shinytheme("flatly"),
  useShinyjs(),
  
  tags$head(
    tags$style(HTML(sprintf("
      body.light-mode {
        background-color: #f9f9f9;
        color: #333;
      }
      body.dark-mode {
        background-color: #1c1c1c;
        color: #f2f2f2;
      }
      .dark-mode .well {
        background-color: #2a2a2a;
        border-left: 5px solid %s;
        box-shadow: none;
      }
      .dark-mode .btn-primary {
        background-color: %s;
        border-color: %s;
      }
      .btn-primary:hover {
        background-color: #e04302;
        border-color: #e04302;
      }
      h1, h2, h3 {
        color: %s;
      }
      .logo {
        max-width: 100px;
        margin-bottom: 10px;
      }
      .centered {
        text-align: center;
      }
    ", strava_orange, strava_orange, strava_orange, strava_orange)))
  ),
  
  tags$script(HTML("
    Shiny.addCustomMessageHandler('toggle-dark-mode', function(isDark) {
      document.body.classList.remove('light-mode', 'dark-mode');
      document.body.classList.add(isDark ? 'dark-mode' : 'light-mode');
    });
  ")),
  
  div(class = "centered",
      img(src = "stravalogo.png", class = "logo"),
      h1("stravaReportR"),
      h4("Generate personalized Strava analytics in one click"),
      h4(HTML("To export a .csv with your Strava data, use <a href='https://entorb.net/strava-streamlit/' target='_blank'>Torben's App</a>.")),
      h4("Some known current limitations are:"),
      tags$ul(
        tags$li("Only 12 distinct colors implemented for categorical data"),
        tags$li("Only plots maps of Belgium and Europe right now"))
  ),
  
  fluidRow(
    column(12, div(style = "text-align: right; padding: 0 15px;",
                   checkboxInput("darkmode", "🌙 Dark Mode", value = FALSE)))
  ),
  
  sidebarLayout(
    sidebarPanel(
      h3("Upload Your Activities .csv"),
      fileInput("file", "Choose a Strava CSV File", accept = c(".csv")),
      tags$hr(),
      downloadButton("downloadReport", "Download HTML Report", class = "btn-primary"),
      width = 4
    ),
    
    mainPanel(
      h3("Preview of Uploaded Data"),
      withSpinner(tableOutput("contents"), type = 4, color = strava_orange)
    )
  ),
  tags$hr(),
  tags$footer(
    HTML(
      "Made by Pablo Vangeenderhuysen. View the source on 
     <a href='https://github.com/pablovgd/stravaReportR' target='_blank'>GitHub</a>."
    ),
    style = "
    text-align: center;
    padding: 10px;
    font-size: 0.9em;
    color: #777;"
  )
)
)
