#
# Fabric Training File
#
[DEFAULT]
prefix = 
sysconfdir = /etc
logdir = /var/log

[storage]
address = localhost:3306
user = fabric
password = {{fabric_pass}}
database = fabric
auth_plugin = mysql_native_password
connection_timeout = 6
connection_attempts = 6
connection_delay = 1

[servers]
user = fabric
password = {{fabric_pass}}
unreachable_timeout = 5

[protocol.xmlrpc]
address = {{xmlrpc_endpoint['host']}}:{{xmlrpc_endpoint['port']}}
threads = 5
user = admin
password = {{admin_pass}}
disable_authentication = no
realm = MySQL Fabric
ssl_ca = 
ssl_cert = 
ssl_key = 

[protocol.mysql]
address = localhost:32275
user = admin
password = {{admin_pass}}
disable_authentication = no
ssl_ca = 
ssl_cert = 
ssl_key = 

[executor]
executors = 5

[logging]
level = INFO
url = file:///var/log/fabric.log

[sharding]
mysqldump_program = /usr/bin/mysqldump
mysqlclient_program = /usr/bin/mysql
prune_limit = 10000

[statistics]
prune_time = 3600

[failure_tracking]
notifications = 300
notification_clients = 50
notification_interval = 60
failover_interval = 0
detections = 3
detection_interval = 6
detection_timeout = 1
prune_time = 3600

[connector]
ttl = 1

# mysql client configuration to connect 
# to the various server of the infrastructure
[client]
password = {{fabric_pass}}

