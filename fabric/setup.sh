    PREFIX=$(basename $PWD)
    export COMPOSE_FILE=fabric.yml
    docker-compose scale fabric=1 mysql=3
    sleep 10
    
    docker exec fabric python /code/fabric-poc.py setup localhost ${PREFIX}_mysql_{1..3}
    #docker exec -ti fabric /bin/bash


    mysqlfabric manage setup --param=storage.user=fabric
    mysqlfabric manage start --daemonize

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

