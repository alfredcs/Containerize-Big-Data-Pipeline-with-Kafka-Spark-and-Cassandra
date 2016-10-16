#!/usr/bin/python
from cassandra.cluster import Cluster
import sys

rows=[]
ticker=sys.argv[1] if len(sys.argv) > 1 else "AMZN"
query = "SELECT * FROM realtime_quotes WHERE symbol=%s"
cluster = Cluster(["172.20.13.163", "172.20.13.164", "172.20.13.165"], port=9042)
session = cluster.connect('stocks')
f_handle=open('/tmp/test.csv', 'w')
rows = session.execute_async(query, [ticker])
#rows = session.execute_async("SELECT * FROM realtime_quotes WHERE symbol='AMZN'")
try:
  for row in rows.result():
    f_handle.write( ','.join(row)+"\n")
except Exception as e:
  print str(e)
f_handle.close()
