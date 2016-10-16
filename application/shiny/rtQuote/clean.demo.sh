#!/bin/bash
while true
do
   sed -i '/^2016-/d' ./SPY1.csv
   for line in $(grep 2016- ./GOOG.csv); do echo $line >> ./SPY1.csv; sleep 5; done
done
