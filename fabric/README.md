# Files for Fabric POC

This directory contains tools to setup a fabric POC

    - fabric.yml: docker-compose file to setup 3+ mysql nodes
    - fabric-poc.py: script to configure fabric nodes
    - fabric.cfg.t: fabric template used by fabric-poc.py
    - my-gtid.cnf: fabric requires GTID configuration

IMPORTANT: if you can't resolve containers' hostnames you should take care
            of setting IPs instead of hostnames
            
        #docker inspect -f '{{.Name}} {{.NetworkSettings.IPAddress}}' $(docker ps -q)


## The POC

Create 4 database hosts:

    #export COMPOSE_FILE=fabric.yml
    #docker-compose scale master=1 slave=2 fabric=1
    #docker exec fabric python /code/fabric-poc.py m.docker s-1.docker s-2.docker
    #docker exec -ti fabric /bin/bash


    mysqlfabric manage setup --param=storage.user=fabric
    mysqlfabric manage ping

Create the "ha" group and add a master and a slave.

    mysqlfabric group create ha
    mysqlfabric group add ha m.docker:3306
    mysqlfabric group add ha s-1.docker:3306


## Checks

    #mysqlfabric group lookup_servers ha
    mysqlfabric group health ha

## Add a new node

Let's add a new node simulating that not enough binlogs are present

    #mysql -uroot -proot -h m.docker -e 'purge logs;'

Now provision a new node via docker-compose:

    #docker-compose scale slave=3

And clone the master databases on the new node.

    #mysqlfabric server clone ha s-4.docker 
    #mysqlfabric group add ha s-4.docker:3306 

