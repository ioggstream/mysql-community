#!/bin/bash
IP=$(ifconfig eth0 | awk '/inet / {print $2;}')

case "$1" in
	create)
		mysqlsh --uri root:$MYSQL_ROOT_PASSWORD@$IP  --classic --js -f /code/initialize-first-node.js
		;;
	add)
		: ${2?Missing target ip}
		mysqlsh --uri root:$MYSQL_ROOT_PASSWORD@$IP --classic --js <<< "
		c=dba.getCluster('ioggstream');
		c.addInstance('root:$MYSQL_ROOT_PASSWORD@$2');
		"
		;;
	*)
		echo "Allowed params:
			initialize
			add IP_ADDRESS
			"
		;;	
esac


