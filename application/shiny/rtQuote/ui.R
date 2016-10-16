shinyUI(fluidPage(
  headerPanel("'big'Data Pipeline Streaming Demo"),
  sidebarPanel(
    textInput("symb", "Choose Stock Symbol", "GOOG"),
    dateRangeInput("dates", 
                   "Date range",
                   start = "2014-03-27", 
                   end = as.character(Sys.Date())),
    
    helpText("Note: Enter a stock symbol in the box below,
             choose the time period to display and 
             then press Update View botton. 
             Some stock symbols to get started TWTR, AAPL,WFM,SBUX"),
    submitButton('Update View')),
  mainPanel(
    h4("Historical Data"),
    plotOutput('newHist'),
    h4("Daily Streaming"),
    plotOutput('daily'),
    h4("Summary"),
    verbatimTextOutput("summary"),

    h4("Observations"),
    tableOutput("view")
  )
))
