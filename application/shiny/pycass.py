from cassandra.cluster import Cluster
import sys,datetime,time

def q_cass():
  rows=[]
  lines=""
  jj=1
  ticker=sys.argv[1] if len(sys.argv) > 1 else ""
  today = datetime.datetime.now().strftime("%Y-%m-%d 00:00:00")
  if len(ticker) > 1:
	query = "SELECT * FROM realtime_quotes WHERE symbol='"+ticker+"' AND tradetime >= '"+today+"'"
  	f_handle=open("/root/shiny/rtQuote/"+ticker+".csv", 'w')
  else:
	query = "SELECT * FROM realtime_quotes WHERE tradetime >= '"+today+"' ALLOW FILTERING"
  	f_handle=open("/root/shiny/rtQuote/ALL.csv", 'w')
  cluster = Cluster(["172.20.13.168", "172.20.13.167", "172.20.13.166"], port=9042)
  session = cluster.connect('stocks')
  #import pdb;pdb.set_trace()
  f_handle.write("\"Symbol\",\"Index\",\"Open\",\"High\",\"Low\",\"Close\",\"Volume\"\n")
  rows = session.execute_async(query)
  for row in rows.result():
    lines+=row[0]+","+(datetime.datetime.now()+datetime.timedelta(days=jj)).strftime('%Y-%m-%d')+","+','.join(row[2:])+"\n"
    jj+=1
  f_handle.write(lines)
  f_handle.close()
  cluster.shutdown()

def main():
  try:
    q_cass()
  except Exception as e:
    str(e)
if __name__ == "__main__":
  while True:
    main()
    time.sleep(60)
