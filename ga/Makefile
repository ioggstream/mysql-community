# 
# To provide an http_proxy, set --build-arg=http_proxy=http://172.17.0.1:3128
#
#BUILD_ARGS="--build-arg=http_proxy=http://172.17.0.1:3128"

build:
	docker build  $(BUILD_ARGS) --tag=mysql-community:latest .
setup:
	sudo yum -y install python-pip \
		python-tox 	\
		git		\
	
	sudo pip install docker-compose
