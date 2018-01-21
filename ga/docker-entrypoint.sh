#!/bin/bash
#
# Supported environment variables for this entrypoint:
#  - MYSQL_ROOT_PASSWORD
#  - MYSQL_REPLICA_USER: create the given user on the intended master host
#  - MYSQL_REPLICA_PASS
#  - MYSQL_BACKUP_USER: backup user
#  - MYSQL_MASTER_SERVER: change master on this location on the intended slave
#  - MYSQL_MASTER_PORT: optional, by default 3306
#  - MYSQL_MASTER_ROOT_PASS: the root password for the master server
#  - MYSQL_MASTER_WAIT_TIME: seconds to wait for the master to come up, default 3seconds
#  - MYSQL_SETUP_WAIT_TIME: seconds to wait for the current instance to start after setup (default 60seconds)
set -e
set -m
# Wait for a remote sql server
waitserver(){
	local i
	local timeout=$1; shift
	for i in $(seq $((timeout+1))); do
		mysqladmin ping $@  | grep -q alive && break
		echo >&2 -n "."
		sleep 1
	done
        if [ "$i" -gt "$timeout" ]; then
                echo >&2 "Host is not reachable is not reachable"
                return 1
        fi
	return 0
}
get_last_octet_from_ip(){
        local ip=$(ip r l scope link)
        echo ${ip//*./}
}

get_ip(){
        local ip=$(ip r l scope link)
        echo ${ip//*src /}
}


# TODO read this from the MySQL config?
DATADIR='/var/lib/mysql'

if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

if [ ! -d "$DATADIR/mysql" -a "${1%_safe}" = 'mysqld' ]; then
	if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
		echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
		echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
		exit 1
	fi
	
	echo 'Running initialize ...'
	mysqld --defaults-file=/etc/my.cnf --user=mysql --initialize 
	echo 'Finished initialize'
	
	# These statements _must_ be on individual lines, and _must_ end with
	# semicolons (no line breaks or comments are permitted).
	# TODO proper SQL escaping on ALL the things D:
	
	tempSqlFile='/tmp/mysql-first-time.sql'
	cat > "$tempSqlFile" <<-EOSQL
		DELETE FROM mysql.user ;
		CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
		GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
		DROP DATABASE IF EXISTS test ;
	EOSQL
	
	if [ "$MYSQL_DATABASE" ]; then
		echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" >> "$tempSqlFile"
	fi
	
	if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
		echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"
		
		if [ "$MYSQL_DATABASE" ]; then
			echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" >> "$tempSqlFile"
		fi
	fi

	# 
	# A local-only backup user to be used by
	# backup tools 
	# eg. mysqlbackup -u${MYSQL_BACKUP_USER} --backup-dir /backup --with-timestamp backup-and-apply-log
	# 
	if [ "$MYSQL_BACKUP_USER" ]; then
		cat >> "$tempSqlFile" <<-EOSQL
			GRANT RELOAD ON *.* TO '${MYSQL_BACKUP_USER}'@'localhost';
			GRANT CREATE, INSERT, DROP, UPDATE ON mysql.backup_progress TO '${MYSQL_BACKUP_USER}'@'localhost';
			GRANT CREATE, INSERT, SELECT, DROP, UPDATE ON mysql.backup_history TO '${MYSQL_BACKUP_USER}'@'localhost';
			GRANT REPLICATION CLIENT ON *.* TO '${MYSQL_BACKUP_USER}'@'localhost';
			GRANT SUPER ON *.* TO '${MYSQL_BACKUP_USER}'@'localhost';
			FLUSH PRIVILEGES; 
		EOSQL
	fi

	#
	# A replication user (actually created on both master and slaves)
	#
        if [ "$MYSQL_REPLICA_USER" ]; then
                if [ -z "$MYSQL_REPLICA_PASS" ]; then
                        echo >&2 'error: MYSQL_REPLICA_USER set, but MYSQL_REPLICA_PASS not set'
                        exit 1
                fi
                # REPLICATION CLIENT privileges are required to get master position
		cat >> "$tempSqlFile" <<-EOSQL
                	CREATE USER '$MYSQL_REPLICA_USER'@'%' IDENTIFIED BY '$MYSQL_REPLICA_PASS'; 
                	GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICA_USER'@'%';
                	GRANT REPLICATION CLIENT ON *.* TO '$MYSQL_REPLICA_USER'@'%'; 
		EOSQL
        fi

	#
	# On the slave: point to a master server
	#
        if [ "$MYSQL_MASTER_SERVER" ]; then
                MYSQL_MASTER_PORT=${MYSQL_MASTER_PORT:-3306}
		MYSQL_MASTER_WAIT_TIME=${MYSQL_MASTER_WAIT_TIME:-3}

                if [ -z "$MYSQL_REPLICA_USER" ]; then
                        echo >&2 'error: MYSQL_REPLICA_USER not set'
                        exit 1
                fi
                if [ -z "$MYSQL_REPLICA_PASS" ]; then
                        echo >&2 'error: MYSQL_REPLICA_PASS not set'
                        exit 1
                fi

		# Wait for eg. 10 seconds for the master to come up
		# do at least one iteration
		echo >&2 "Waiting for $MYSQL_REPLICA_USER@$MYSQL_MASTER_SERVER"
		if ! waitserver $MYSQL_MASTER_WAIT_TIME "-u$MYSQL_REPLICA_USER" "-p$MYSQL_REPLICA_PASS" "-h$MYSQL_MASTER_SERVER"; then
			echo 1>&2 "Master server is unreachable"
			exit 1
		fi

		if [ -z "$MYSQL_MASTER_ROOT_PASS" ]; then
			# Get master position and set it on the slave. NB: MASTER_PORT and MASTER_LOG_POS must not be quoted
        	        MasterPosition=$(mysql "-u$MYSQL_REPLICA_USER" "-p$MYSQL_REPLICA_PASS" "-h$MYSQL_MASTER_SERVER" -e "show master status \G" | awk '/Position/ {print $2}')
                	MasterFile=$(mysql  "-u$MYSQL_REPLICA_USER" "-p$MYSQL_REPLICA_PASS" "-h$MYSQL_MASTER_SERVER"   -e "show master status \G"     | awk '/File/ {print $2}')
	                echo "CHANGE MASTER TO MASTER_HOST='$MYSQL_MASTER_SERVER', MASTER_PORT=$MYSQL_MASTER_PORT, MASTER_USER='$MYSQL_REPLICA_USER', MASTER_PASSWORD='$MYSQL_REPLICA_PASS', MASTER_LOG_FILE='$MasterFile', MASTER_LOG_POS=$MasterPosition;"  >> "$tempSqlFile"
			echo "START SLAVE;"  >> "$tempSqlFile"
		fi

        fi

	
	echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"
	
	set -- "$@"  --init-file="$tempSqlFile"
fi


restoredb(){
        MYSQL_SETUP_WAIT_TIME=${MYSQL_SETUP_WAIT_TIME:-60}

	echo 1>&2 "Loading DB from Master"
	# Use mysql-utilities to allocate a new slave
	mysqldbexport --server=root:${MYSQL_MASTER_ROOT_PASS}@${MYSQL_MASTER_SERVER}:${MYSQL_MASTER_PORT} --all --export=both --rpl=master --rpl-user=$MYSQL_REPLICA_USER:$MYSQL_REPLICA_PASS >> "/tmp/data.sql"
	echo 1>&2 "Waiting for the Slave to come up"
	if  !  waitserver "$MYSQL_SETUP_WAIT_TIME"  -uroot "-p${MYSQL_ROOT_PASSWORD}" -hlocalhost ; then
		echo >&2 "Local mysql instance is taking too long to start"
		exit 1
	fi
	# Reset Master before importing GTID dump
	mysql -uroot -p${MYSQL_ROOT_PASSWORD} -hlocalhost -e 'RESET MASTER;'
	echo 1>&2 "Importing DB"
	mysqldbimport --server=root:${MYSQL_ROOT_PASSWORD}@localhost  /tmp/data.sql
	echo 1>&2 "Done"
}
chown -R mysql:mysql "$DATADIR"
# initialize slave
if [ "$MYSQL_MASTER_ROOT_PASS" ]; then
	restoredb &
	disown
fi

exec "$@" --user=mysql  --server-id=$(get_last_octet_from_ip) 

