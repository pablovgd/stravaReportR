library(shiny)
library(httr)
library(jsonlite)
library(dplyr)
library(rmarkdown)
library(shinyjs)

shinyServer(function(input, output, session) {
  # make login button change after authentication
  output$login_button <- renderUI({
    
    if (is.null(token())) {
      actionButton(
        "load_data",
        "Login with Strava",
        class = "btn-primary"
      )
    } else {
      actionButton(
        "load_data",
        "Data loaded!",
        class = "btn-success",
        disabled = TRUE
      )
    }
  })
  
  # Disable range and download button before login
  observe({
    shinyjs::disable("year_range")
    shinyjs::disable("downloadReport")
  })
  
  # Dark and light mode
  observe({
    session$sendCustomMessage("toggle-dark-mode", input$darkmode)
  })
  
  observeEvent(input$darkmode, {
    session$sendCustomMessage("toggle-dark-mode", input$darkmode)
  })
  
  # Authentication code
  token <- reactiveVal(NULL)
  
  # Login button -> redirect to Strava
  observeEvent(input$load_data, {
    req(is.null(token())) 
    client_id <- Sys.getenv("STRAVA_CLIENT_ID")
    
    redirect_uri <- paste0(
      session$clientData$url_protocol,
      "//",
      session$clientData$url_hostname,
      session$clientData$url_pathname
    )
    
    auth_url <- paste0(
      "https://www.strava.com/oauth/authorize?",
      "client_id=", client_id,
      "&response_type=code",
      "&redirect_uri=", URLencode(redirect_uri),
      "&approval_prompt=auto",
      "&scope=activity:read_all"
    )
    
    session$sendCustomMessage("redirect", auth_url)
  })
  
  # Capture authorization code and exchange for token
  observe({
    query <- parseQueryString(session$clientData$url_search)
    
    if (!is.null(query$code) && is.null(token())) {
      client_id     <- Sys.getenv("STRAVA_CLIENT_ID")
      client_secret <- Sys.getenv("STRAVA_CLIENT_SECRET")
      
      res <- httr::POST(
        "https://www.strava.com/oauth/token",
        body = list(
          client_id     = client_id,
          client_secret = client_secret,
          code          = query$code,
          grant_type    = "authorization_code"
        ),
        encode = "form"
      )
      
      stop_for_status(res)
      
      token(content(res, as = "parsed", type = "application/json"))
    }
  })
  
  ## Download & process activities

  activities_df <- reactive({
    
    req(token())
    
    stoken <- httr::add_headers(
      Authorization = paste("Bearer", token()$access_token)
    )
    
    df_list <- list()
    i <- 1
    done <- FALSE
    
    while (!done) {
      req_api <- GET(
        url = "https://www.strava.com/api/v3/athlete/activities",
        config = stoken,
        query = list(per_page = 200, page = i)
      )
      stop_for_status(req_api)
      
      df_list[[i]] <- fromJSON(content(req_api, as = "text"), flatten = TRUE)
      
      if (length(content(req_api)) < 200) {
        done <- TRUE
      } else {
        i <- i + 1
      }
    }
    
    df <- rbind_pages(df_list)
    
    gear_ids <- unique(na.omit(df$gear_id))
    
    gear_lookup <- data.frame(
      gear_id = character(),
      gear_name = character(),
      stringsAsFactors = FALSE
    )
    
    for (id in gear_ids) {
      resp <- GET(
        paste0("https://www.strava.com/api/v3/gear/", id),
        config = stoken
      )
      if (status_code(resp) == 200) {
        gear <- content(resp, as = "parsed", type = "application/json")
        gear_lookup <- rbind(
          gear_lookup,
          data.frame(
            gear_id = id,
            gear_name = gear$name,
            stringsAsFactors = FALSE
          )
        )
      }
    }
    
    df <- df %>% left_join(gear_lookup, by = "gear_id")
    
    collapse_latlng <- function(x, digits = 4) {
      if (is.null(x) || length(x) == 0) NA_character_
      else paste(formatC(x, digits = digits, format = "f"), collapse = ",")
    }
    
    df$start_latlng <- vapply(df$start_latlng, collapse_latlng, character(1))
    df$end_latlng   <- vapply(df$end_latlng, collapse_latlng, character(1))
    
    shinyjs::enable("year_range")
    shinyjs::enable("downloadReport")
    
    df
  })
   
  # filter by
  filtered_activities <- reactive({
    req(activities_df())
    
    df <- activities_df()
    df$start_date <- as.Date(df$start_date)
    
    years <- input$year_range
    
    df %>%
      dplyr::filter(
        format(start_date, "%Y") >= years[1],
        format(start_date, "%Y") <= years[2]
      )
  })
  

  ## Preview table

  drop_list_columns <- function(x) {
    x[, !sapply(x, is.list), drop = FALSE]
  }
  
  output$contents <- renderTable({
    req(filtered_activities())
    preview_df <- drop_list_columns(filtered_activities())
    head(preview_df, 10)
  })
  
  ## Report generation
  output$downloadReport <- downloadHandler(
    filename = function() "stravaReport.html",
    content = function(file) {
      req(filtered_activities())
      
      tempReport <- file.path(tempdir(), "report.Rmd")
      if (!file.exists("strava_analysis.rmd")) {
        stop("The strava_analysis.rmd file is missing.")
      }
      file.copy("strava_analysis.rmd", tempReport, overwrite = TRUE)
      
      tempCSV <- file.path(tempdir(), "activities.csv")
      write.csv(filtered_activities(), tempCSV, row.names = FALSE)
      
      withProgress(message = "Generating report...", value = 0.5, {
        rmarkdown::render(
          tempReport,
          output_file = file,
          params = list(csv_path = tempCSV),
          envir = new.env(parent = globalenv())
        )
      })
    }
  )

  
  
})
