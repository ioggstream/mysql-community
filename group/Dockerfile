#
# MySQL Group Replication image.
#
FROM centos:7
MAINTAINER roberto.polli@par-tec.it

RUN yum -y install epel-release 

RUN yum -y install https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm 

# Install server
RUN rpmkeys --import http://repo.mysql.com/RPM-GPG-KEY-mysql \
  && yum install -y mysql-server \
  && yum install -y libpwquality \
  && rm -rf /var/cache/yum/*
RUN mkdir /docker-entrypoint-initdb.d

VOLUME /var/lib/mysql


# Download labs
RUN mkdir /tmp/downloads && \
	 curl https://downloads.mysql.com/snapshots/pb/mysql-innodb-cluster-5.7.17-preview-2/mysql-innodb-cluster-labs201612-2-linux-glibc2.12-x86_64.tar.gz | tar xzf - -C /tmp/downloads && \
	 tar xf /tmp/downloads/mysql-router-2.1.1-labs-linux-glibc2.12-x86-64bit.tar.gz -C /opt && \
	 tar xf /tmp/downloads/mysql-shell-1.0.7-labs-linux-glibc2.12-x86-64bit.tar.gz  -C /opt && \
	rm /tmp/downloads -fr

RUN mv /opt/mysql-router-* /opt/mysql-router
RUN mv /opt/mysql-shell-* /opt/mysql-shell

ENV PATH $PATH:/opt/mysql-router/bin:/opt/mysql-shell/bin


# MysqlRouter
VOLUME /var/lib/mysqlrouter
