library(quantmod)
library(shiny)
library(xts)
library(chron)

shinyServer(
  function(input, output, session) {
    datasetInput <- reactive({
      #invalidateLater(1000, session)
      getSymbols(input$symb, src = "google", 
      from = input$dates[1],
      to = input$dates[2],
      auto.assign = FALSE)
    })

    datasetInput2 <- reactive({
      invalidateLater(5000, session)
      aa <- read.csv("/root/shiny/rtQuote/data/daily.csv", sep="|", header=T)
      today <-aa[grepl(Sys.Date(), aa$tradetime) & trimws(aa$symbol) == trimws(input$symb), ]
      today$tradetime <- as.POSIXct(today$tradetime)
      today <-as.xts(today[,-1], order.by=today[,2])
    })

    output$newHist <- renderPlot({
      #invalidateLater(5000, session)
      candleChart(datasetInput(), 
                  theme=chartTheme('white',up.col='blue',dn.col='red'),TA=c(addBBands()))
      addMACD() 
    })
    observe({
      output$daily <- renderPlot({
        invalidateLater(5000, session)
	#bb <- read.csv("/root/shiny/rtQuote/data/daily2.csv", sep=",", header=T)
        #bb <-bb[grepl(Sys.Date(), bb$tradetime) & trimws(bb$symbol) == trimws(tick), ]
        #bb$tradetime <-chron(times=substr(bb$tradetime,12, 20))
        #barplot(bb$volume, col = "green", ylab="Daily Volume", xlab="Trade Time")
        ##candleChart(datasetInput2(), theme=chartTheme('white',up.col='green',dn.col='orange'),TA=c(addBBands()))
        ##addMACD()
	google <-  as.xts(read.zoo("SPY.csv",sep=",", quote="\"", header=T))
	#barChart(google,  theme=chartTheme('black',up.col='green',dn.col='red'))
	candleChart(google,  theme=chartTheme('white',up.col='green',dn.col='red'))
      })
    })
    # Generate a summary of the dataset
    output$summary <- renderPrint({
      dataset <- datasetInput()
      summary(dataset)
    }) 
    # Show the first "n" observations
    output$view <- renderTable({
      head(datasetInput(), n = 10)
    })
})
