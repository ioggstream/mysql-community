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
#set -x

## Wait for a remote sql server
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
## Get infos via iproute to set --server-if
get_last_octet_from_ip(){
		local ip=$(ip r l scope link)
		echo ${ip//*./}
}

get_ip(){
		local ip=$(ip r l scope link)
		echo ${ip//*src /}
}
## Export master db with mysqldbexport.
restoredb(){
		MYSQL_SETUP_WAIT_TIME=${MYSQL_SETUP_WAIT_TIME:-60}

	echo 1>&2 "Loading DB from Master"
	# Use mysql-utilities to allocate a new slave
	mysqldbexport --server=root:${MYSQL_MASTER_ROOT_PASS}@${MYSQL_MASTER_SERVER}:${MYSQL_MASTER_PORT} --all --export=both --rpl=master --rpl-user=$MYSQL_REPLICA_USER:$MYSQL_REPLICA_PASS >> "/tmp/data.sql"
	if [ $? != 0 ]; then
		echo 1>&2 "Error importing data $(cat /tmp/data.sql)"
	fi
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

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

if [ "$1" = 'mysqld' ]; then
	# Get config
	DATADIR="$("$@" --verbose --help --log-bin-index=/tmp/tmp.index 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
	echo "${DATADIR}mysql"
	if [ ! -d "${DATADIR}mysql" ]; then
		echo "Datadir non esistente"
		ls -l "$DATADIR"
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
			echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
			exit 1
		fi
		# If the password variable is a filename we use the contents of the file
		if [ -f "$MYSQL_ROOT_PASSWORD" ]; then
			MYSQL_ROOT_PASSWORD="$(cat $MYSQL_ROOT_PASSWORD)"
		fi
		if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			MYSQL_ROOT_PASSWORD="$(pwmake 128)"
			echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
		fi
		mkdir -p "$DATADIR"
		chown -R mysql:mysql "$DATADIR"

		# Using set -e we should always EXIT_SUCCESS even if nothing is grep'd
		echo "Running initialize with options ${DEFAULTS_FILE_ARGS}"
		"$@" --user=mysql --initialize-insecure=on --datadir="$DATADIR"  --server-id=$(get_last_octet_from_ip)
		echo 'Finished initialize'

		"$@" --user=mysql --datadir="$DATADIR" --skip-networking  --server-id=$(get_last_octet_from_ip) &


		pid="$!"

		mysql=( mysql --protocol=socket -uroot )

		for i in {30..0}; do
			if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
				break
			fi
			echo 'MySQL init process in progress...'
			sleep 1
		done
		if [ "$i" = 0 ]; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		mysql_tzinfo_to_sql /usr/share/zoneinfo | "${mysql[@]}" mysql

		"${mysql[@]}" <<-EOSQL
			-- What's done in this file shouldn't be replicated
			--  or products like mysql-fabric won't work
			SET @@SESSION.SQL_LOG_BIN=0;
			DELETE FROM mysql.user ;
			CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
			GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
			DROP DATABASE IF EXISTS test ;
			FLUSH PRIVILEGES;
EOSQL

		if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
			mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
		fi

		if [ "$MYSQL_DATABASE" ]; then
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
			mysql+=( "$MYSQL_DATABASE" )
		fi

		if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
			echo "CREATE USER '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PASSWORD"' ;" | "${mysql[@]}"

			if [ "$MYSQL_DATABASE" ]; then
				echo "GRANT ALL ON \`"$MYSQL_DATABASE"\`.* TO '"$MYSQL_USER"'@'%' ;" | "${mysql[@]}"
			fi

			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi

		#
		# A local-only backup user to be used by
		# backup tools
		# eg. mysqlbackup -u${MYSQL_BACKUP_USER} --backup-dir /backup --with-timestamp backup-and-apply-log
		#
		if [ "$MYSQL_BACKUP_USER" ]; then
			"${mysql[@]}" <<-EOSQL
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
			${mysql[@]} <<-EOSQL
				CREATE USER '$MYSQL_REPLICA_USER'@'%' IDENTIFIED BY '$MYSQL_REPLICA_PASS';
				GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICA_USER'@'%';
				GRANT REPLICATION CLIENT ON *.* TO '$MYSQL_REPLICA_USER'@'%';
				RESET MASTER;					
EOSQL
		fi

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)  echo "$0: running $f"; . "$f" ;;
				*.sql) echo "$0: running $f"; "${mysql[@]}" < "$f" && echo ;;
				*)	 echo "$0: ignoring $f" ;;
			esac
			echo
		done

		if [ ! -z "$MYSQL_ONETIME_PASSWORD" ]; then
			"${mysql[@]}" <<-EOSQL
				ALTER USER 'root'@'%' PASSWORD EXPIRE;
EOSQL
		fi
		if ! kill -s TERM "$pid" || ! wait "$pid"; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi


		#
		# On the slave: point to a master server
		#
		echo "Configuring replication from ${MYSQL_MASTER_SERVER}"
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
				MasterFile=$(mysql  "-u$MYSQL_REPLICA_USER" "-p$MYSQL_REPLICA_PASS" "-h$MYSQL_MASTER_SERVER"   -e "show master status \G"	 | awk '/File/ {print $2}')
				"${mysql[@]}" <<- EOSQL
				CHANGE MASTER TO MASTER_HOST='$MYSQL_MASTER_SERVER',
				MASTER_PORT=$MYSQL_MASTER_PORT,
				MASTER_USER='$MYSQL_REPLICA_USER',
				MASTER_PASSWORD='$MYSQL_REPLICA_PASS',
				MASTER_LOG_FILE='$MasterFile',
				MASTER_LOG_POS=$MasterPosition;
				START SLAVE;
EOSQL

			fi
		fi
	fi

	chown -R mysql:mysql "$DATADIR"
	# initialize slave
	if [ "$MYSQL_MASTER_ROOT_PASS" ]; then
		restoredb &
		disown
	fi
fi

echo "Executing slave"
exec "$@" --user=mysql --server-id=$(get_last_octet_from_ip)

