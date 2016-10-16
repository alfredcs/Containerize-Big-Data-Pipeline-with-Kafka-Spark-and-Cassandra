import pandas as pd
import pandas_datareader.data as web
import sys, requests, multiprocessing,time 
from cassandra import ConsistencyLevel
from cassandra.query import SimpleStatement
from cassandra.cluster import Cluster
from joblib import Parallel, delayed
from datetime import datetime
#from kombu import Connection, Producer, Exchange, Queue
import pika
#from multiprocessing import Pool 



def get_intraday_data(symbol, interval_seconds=121, num_days=1):
    # Specify URL string based on function inputs.
    url_string = 'http://www.google.com/finance/getprices?q={0}'.format(symbol.upper())
    url_string += "&i={0}&p={1}d&f=d,o,h,l,c,v".format(interval_seconds,num_days)

    # Request the text, and split by each line
    r = requests.get(url_string).text.split()

    # Split each line by a comma, starting at the 8th line
    r = [line.split(',') for line in r[7:]]

    # Save data in Pandas DataFrame
    df = pd.DataFrame(r, columns=['Datetime','Open','High','Low','Close','Volume'])

    # Convert UNIX to Datetime format
    df['Datetime'] = df['Datetime'].apply(lambda x: datetime.fromtimestamp(int(x[1:])))

    return df

def insert_tabke(table_name, value_string):
    query = SimpleStatement("INSERT INTO %s VALUES(%s)", table_name, value_string, consistency_level=ConsistencyLevel.QUORUM)   
    query.execute(query, ("%s" % value_string))


def stock_history (start, end, symbols):
	for symbol in symbols:
  	  symbol_from_google = web.DataReader("%s" % symbol, 'google', start, end)
  	  symbol_from_yahoo = web.DataReader("%s" % symbol, 'yahoo', start, end)
  	  symbol_from_google.to_csv('/tmp/%s_from_google.csv' % symbol)
  	  symbol_from_yahoo.to_csv('/tmp/%s_from_yahoo.csv' % symbol)
  
  	  symbol_intradata = get_intraday_data(symbol, interval_seconds=301, num_days=10)
  	  symbol_from_google.to_csv('/tmp/%s_intraday_google.csv' % symbol)

def pull_stocks():
	username="guest"
	password="guest"
	amqp_host="172.20.13.162"
	port='5672'
	routing_key='streaming'
	exchange_name='stocks'
	start_date = datetime(2000, 1, 1)
	end_date = datetime.today()
	num_cores = multiprocessing.cpu_count()
	symbols =  ['AAPL', 'GOOG', 'MSFT','TSLA', 'CRM', 'AMZN']
	#media_exchange = Exchange('stocks', type='direct')
	#conn = "amqp://"+username+":"+password+"@"+hostname+":"+port+"//"
	## Using pika
	credentials = pika.PlainCredentials(username, password)
	connection = pika.BlockingConnection(pika.ConnectionParameters(host=amqp_host, credentials=credentials))
	channel = connection.channel()
	properties = pika.BasicProperties(user_id=username)
	channel.exchange_declare(exchange='realtime_stocks', exchange_type="direct", passive=False, durable=True, auto_delete=False)
	#qqueue = channel.queue_declare(exclusive=True)
	
	#import pdb;pdb.set_trace()
	#stock_history (start_date, end_date, symbols)


	#cluster = Cluster(['172.20.13.164', '172.20.13.165'])
	#session = cluster.connect("stocks")
	#query = SimpleStatement(
	#	"INSERT INTO history (name, age) VALUES (%s, %s)",
	#	 consistency_level=ConsistencyLevel.QUORUM)
	#session.execute(query,('aa',123))	
	#print "%s: %s" % (symbol, get_intraday_data(symbol)) 
	  #print Parallel(n_jobs=num_cores)(delayed(get_intraday_data)(symbol) for symbol in symbols)
	  #Parallel(n_jobs=num_cores)(delayed(publish_amqp)(conn, "stocks", symbol, "streaming") for symbol in symbols)
	try:
	  for symbol in symbols:
	#	#publish_amqp(conn, media_exchange, symbol)
	#	#channel.queue_bind(exchange=exchange_name, queue=symbol, routing_key=routing_key)
		channel.queue_declare(queue=symbol,auto_delete=True)
		channel.queue_bind(queue=symbol, exchange='realtime_stocks', routing_key=symbol)
		for result in get_intraday_data(symbol).values.tolist():
		  channel.basic_publish(exchange='realtime_stocks', routing_key=symbol, body=symbol+","+(",".join(str(x) for x in result)), properties=pika.BasicProperties(content_type='plain/text'))
	#	#Parallel(n_jobs=num_cores)(delayed(channel.basic_publish(exchange='', routing_key=symbol, body=",".join(str(x) for x in result)) for result in get_intraday_data(symbol).values.tolist()))
	  #connection.close()
	except Exception as e:
	  print str(e)
	  print "Publish Failed!"
	connection.close()

if __name__ == '__main__':
	while True:
	  pull_stocks()
	  time.sleep (30)
