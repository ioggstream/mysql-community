#!/bin/bash
set -e

IP=$(ifconfig eth0 | awk '/inet / {print $2;}')

DATADIR=/var/lib/mysqlrouter

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqlrouter "$@" 
fi

chown -R mysql:mysql "$DATADIR"
mysqlrouter --bootstrap root:$MYSQL_ROOT_PASSWORD@$2 -d $DATADIR 

echo "$@"
mysqlrouter -c $DATADIR/mysqlrouter.conf

