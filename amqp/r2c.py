import pika,sys,threading,logging
from cassandra import ConsistencyLevel
from cassandra.cluster import Cluster
from cassandra.query import SimpleStatement
from datetime import datetime


class rabbit2cass(object):
    """
	  Configure Log
    """
    log = logging.getLogger()
    log.setLevel('INFO')
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s"))
    log.addHandler(handler)


    def __init__(self,routing_table):
        """
        """
	self.log = logging.getLogger()
    	self.log.setLevel('INFO')
	self.s_list=[]
    	self.handler = logging.StreamHandler()
    	self.handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s"))
    	self.log.addHandler(self.handler)
        super(rabbit2cass,self).__init__()
	# Write to a temp csv file
	self.f_handle=open('/tmp/stock_daily.csv', 'w+')
	self.f_handle.write("symbol,tradetime,open,high,low,close,volume"+'\n')
        # Set up the Rabbit connection
        self.username="guest"
        self.password="guest"
        self.amqp_host="172.20.13.162"
        self.port='5672'
	self.symbols = ['AAPL', 'GOOG', 'MSFT','TSLA', 'CRM', 'AMZN']
	self.credentials = pika.PlainCredentials(self.username, self.password)
        self.connection = pika.BlockingConnection(pika.ConnectionParameters(host=self.amqp_host, credentials=self.credentials))
        self.channel = self.connection.channel()
        self.channel.basic_qos(prefetch_count=1)

	# Connect to Cassandra
	self.cassandra_connect('stocks', 'realtime_quotes')
	#self.batch = BatchStatement()
        # Declare this process's queue
	self.channel.exchange_declare(exchange='realtime_stocks', exchange_type="direct", passive=False, durable=True, auto_delete=False)
	try:
          for symbol in self.symbols:
            self.channel.queue_declare(queue=symbol,auto_delete=True)
            self.channel.queue_bind(queue=symbol, exchange='realtime_stocks', routing_key=symbol)
            self.channel.basic_consume(self.callback, queue=symbol, no_ack=True)
          print(' [*] Waiting for messages. To exit press CTRL+C')
          self.channel.start_consuming()
        except Exception as e:
          print str(e)
          print "Consume Failed!"
          self.channel.stop_consuming()
        self.connection.close()
	self.f_handle.close()
        #self.channel.queue_declare("registration")
        #self.channel.basic_consume(self.callback, queue='registration')
        #self.session = None
        #self.cluster = None

    def callback(self,ch,method,props,body):
        """
        """
	#print(" [x] Received  %r" % ( body))
	#self.cassandra_insert('realtime_quotes', body)
	#print("-----")
        try:
        #  self.cassandra_insert(header,msg)
	  self.cassandra_insert('realtime_quotes', body)
	  if body not in self.s_list:
	    self.f_handle.write(body+'\n')
	    self.s_list.append(body)
        except Exception:
          print "Cassandra connection failed. Will retry soon..."
          ch.basic_nack(delivery_tag = method.delivery_tag)
          time.sleep(1)
          self.cassandra_connect()
          return

    def cassandra_insert(self,table,data):
        """
            Insert a list of data into the currently connected Cassandra database.
        """
        try:
            #prepared_statement = self.session.prepare("INSERT INTO node_info" + \
            #    " (node_id, timestamp, config_file)" + \
            #    " VALUES (?, ?, ?)")
            #bound_statement = prepared_statement.bind([header["s_uniqid"],time.time()*1000,data])
            #self.session.execute(bound_statement)
	    #import pdb; pdb.set_trace()
	    self.fields=data.split(',')
            self.query = SimpleStatement("""
                INSERT INTO realtime_quotes (symbol, tradetime, open, high, low, close, volume)
                VALUES (%(symbol)s, %(tradetime)s, %(open)s, %(high)s, %(low)s, %(low)s,%(volume)s)
                """, consistency_level=ConsistencyLevel.ONE)
            #self.log.info("inserting into %s" % table)
            self.session.execute(self.query, dict(symbol=self.fields[0], tradetime=self.fields[1], open=self.fields[2],high=self.fields[3],low=self.fields[4],close=self.fields[5],volume=self.fields[6]))

        except Exception as e:
            raise


    def cassandra_connect(self, keyspaceName, tableName):
        """
            Try to establish a new connection to Cassandra.
        """
        try:
            self.cluster.shutdown()
        except:
            pass
        #self.cluster = Cluster(contact_points=[CASSANDRA_IP])
	self.cluster = Cluster(['172.20.13.163', '172.20.13.164', '172.20.13.165'], port=9042)

        try: # Might not immediately connect. That's fine. It'll try again if/when it needs to.
            self.session = self.cluster.connect(keyspaceName)
        except:
            print "WARNING: Cassandra connection to " + "CASSANDRA_IP" + " failed."
            print "The process will attempt to re-connect at a later time."

	self.rows = self.session.execute("SELECT keyspace_name FROM system_schema.keyspaces")
	if keyspaceName not in [row[0] for row in self.rows]:
          self.log.info("creating keyspace...")
          self.session.execute("""
                CREATE KEYSPACE %s
                WITH replication = { 'class': 'SimpleStrategy', 'replication_factor': '2' }
                """ % keyspaceName)
        self.rows =  self.session.execute("SELECT table_name FROM system_schema.tables")
        if tableName not in [row[0] for row in self.rows]:
          self.log.info("creating keyspace...")
          self.session.execute("""
                CREATE table %s (
                symbol text,
                tradetime  text,
                open text,
                high text,
                low text,
                close text,
                volume text,
                PRIMARY KEY (symbol, tradetime)
                )
                """ % tableName)
	else:
	  print("Table "+tableName+" has already existed!")


def main(args_str=None):
    rabbit2cass(args_str)

if __name__ == "__main__":
    main()
