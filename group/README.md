# MySQL 5.7 with group replication

MySQL 5.7 now supports group replication. You can use the following files to
provision an innodb replicated cluster.


The entrypoint sets:

  - a random server_id
  - the report_host using the container ip

The my.cnf uses a reduced footprint image lowering:

  - innodb_log_file_size

## Running


Run at least 3 nodes:

```
docker-compose scale group=3
```

Into the first node (docker-compose exec always runs there by default).

```
docker-compose exec group /code/manage-cluster.sh create
```

Then add further nodes (check their ip before!)


```
docker-compose exec group /code/manage-cluster.sh add 172.17.0.4
docker-compose exec group /code/manage-cluster.sh add 172.17.0.5
```

## Usage

Now you have a running cluster

```
docker-compose exec group mysqlsh --classic --uri root:secret@localhost

mysqlsh> cluster = dba.getCluster();
mysqlsh> cluster.status();

```


