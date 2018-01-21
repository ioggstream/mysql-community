# MySQL 5.7 with replica support

Image based on centos 7 and mysql rpms from oracle community repository. Prepare a testing environment with:

    # make setup


The image uses mysql-utilites to setup replication, thus requiring MySQL 5.7 in 5.6 compatibility mode. The server-id is
set in the entrypoint using the last octect of the first configured ip: check docker-entrypoint.sh for further details.

To run one or more mysql images, specify a scale number:

    # docker-compose scale master=1 slave=3

The provided my.cnf uses:

  - one innodb undo tablespace;
  - 5.6 compatibility mode;
  - explicit defaults for timestamp;
  - disable load data infile outside the secure directory.


# Environment Variables

Enjoy your replicated environment with the following variables:

     MYSQL_ROOT_PASSWORD
     MYSQL_REPLICA_USER: create the given user on the intended master host
     MYSQL_REPLICA_PASS
     MYSQL_BACKUP_USER: backup user
     MYSQL_MASTER_SERVER: change master on this location on the intended slave
     MYSQL_MASTER_PORT: optional, by default 3306
     MYSQL_MASTER_ROOT_PASS: the root password for the master server
     MYSQL_MASTER_WAIT_TIME: seconds to wait for the master to come up, default 3seconds
     MYSQL_SETUP_WAIT_TIME: seconds to wait for the current instance to start after setup (default 60seconds)


# Volumes

The image provides the following volumes:

  - /var/lib/mysql: data directory
  - /var/lib/mysql-files: the [secure file directory](https://dev.mysql.com/doc/refman/5.7/en/server-options.html#option_mysqld_secure-file-priv)
  - /backup: backup directory

 
