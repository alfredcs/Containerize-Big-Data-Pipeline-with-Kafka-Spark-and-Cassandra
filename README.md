###Reference Architecture For Containerized Big Data PipeLine Services
![alt tag] (https://cloud.githubusercontent.com/assets/3374971/19181427/e003c886-8c21-11e6-9d5f-775def571f8d.png)


We are working on a all containerized reference architecture for big data pipeline ecosystem. The design objectives are to pursue platform simplicity and operability in high volume and mission critical environment. This is a frugal solution based solely on open source software.

##### Data Inhection Gateway
Micro services based for API driven data injections from IoT devices and structured data sources. The gateway has a device bot to crawl edge devices for sensor data.

##### Message queue and distributed data streaming
AMQP based messgae queue cluserter and asynchronos data publish and consume. Apache Kafa cluster is for realtime data streaming. The pipeline also accept structured data in file and other formats.

##### Data messaging and archiving
Data from different sources are merged, aggregated and analyzed before archived in HDFS or Cassandra

##### Data process with deep learning and machine learning 
Develope suppervised or unsuppervised learnings for smartX, predix and AI

##### Service Gateway
WSGI with API to serve customer requests plus proactive IoT monitoring and controlling
