# Syntactic sugar for Fabric Training

prepare:
	docker-compose scale fabric=1 mysql=1

ip-list:
	(cd ansible; ansible all -i inventory -a 'ip -4 -o a l eth0 ')

start-fabric:
	 (cd ansible; ansible-playbook -i inventory site.yml )

