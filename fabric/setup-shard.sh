set -e
create_groups(){
mysqlfabric group create ha-0 #global
mysqlfabric group create ha-1
mysqlfabric group create ha-2
mysqlfabric group create ha-3
}

populate_groups(){
for i in {1..8}; do
	mysqlfabric group add ha-$((i % 4)) s-${i}.docker
done
}

activate_groups(){
for i in {0..4}; do
	mysqlfabric group promote ha-$i
done
}

# this 
mysqlfabric sharding create_definition RANGE ha-0
DEFINITION_ID=$(mysqlfabric sharding list_definitions | awk '/ha-0/ {print $1;}')
mysqlfabric sharding add_table $DEFINITION_ID sakila.cities city_id
mysqlfabric sharding add_shard $DEFINITION_ID "ha-1/1, ha-2/200, ha-3/500" --state=ENABLED

