-- Load the group_replication plugin *after* root user have been created. https://bugs.mysql.com/bug.php?id=82687
INSTALL PLUGIN group_replication SONAME 'group_replication.so';

-- Enable replication networks. http://mysqlhighavailability.com/mysql-group-replication-securing-the-perimeter/
SET @@global.group_replication_ip_whitelist="172.17.0.0/16"; --  ,192.168.0.0/16,127.0.0.0/8";
-- SET @@global.group_replication_group_name="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
SET @@global.group_replication_local_address="$IP:33061";

-- Initialize the first replication node.
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
SET GLOBAL group_replication_bootstrap_group=OFF;

EOSQL


