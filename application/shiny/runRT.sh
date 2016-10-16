#!/bin/bash
export https_proxy=http://3.39.86.231:8080
export http_proxy=http://3.39.86.231:8080
#/usr/bin/Rscript -e 'install.packages("quantmod", dep=TRUE, repo="https://cran.cnr.berkeley.edu")'
/usr/bin/Rscript /root/shiny/runRT.R
