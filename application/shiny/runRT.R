if (!require(devtools))
  install.packages("devtools")
if (!require(quantmod))
  install.packages("quantmod", dep=TRUE, repo="https://cran.cnr.berkeley.edu")
shiny::runApp("/root/shiny/rtQuote",  host="0.0.0.0", port=5930 )
