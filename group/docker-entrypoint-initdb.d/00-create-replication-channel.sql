-- Create replication user.
SET SQL_LOG_BIN=0;


-- Create a replication user for initial synchronization.
CREATE USER 'rpl_user'@'%';
GRANT REPLICATION SLAVE ON *.* TO 'rpl_user'@'%' IDENTIFIED BY 'rpl_pass';
CHANGE MASTER TO MASTER_USER='rpl_user', MASTER_PASSWORD='rpl_pass' FOR CHANNEL 'group_replication_recovery';



SET SQL_LOG_BIN=1;

