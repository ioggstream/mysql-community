FROM mysql/mysql-server:5.7
MAINTAINER robipolli@gmail.com
RUN yum -y install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm

# Update
#RUN yum -y distro-sync
RUN yum -y install --nogpgcheck  yum-utils \
	supervisor \
	gzip \
	hostname \
	perl-Data-Dumper \
	sysvinit-tools \
	tar \
	wget \
        python-nose \
        python-pip

# Common for Enterprise and Community
RUN yum -y install --nogpgcheck mysql-utilities

# Community
# RUN yum -y install --nogpgcheck mysql-community-server
# RUN wget http://bit.ly/1CxNuZe -O mysql-utilities-1.6.1.tar.gz
# RUN tar xf mysql-utilities-1.6.1.tar.gz -C /tmp
# RUN (cd /tmp/mysql-utilities-1.6.1; python setup.py install;)
RUN pip install https://github.com/ioggstream/mysql-fabric/archive/docker-provider.zip

RUN rm /var/lib/mysql/* -fr

VOLUME /var/lib/mysql
VOLUME /backup

RUN useradd backup -d /backup -g mysql
RUN chown -R mysql:mysql /var/lib/mysql
RUN chown -R backup:mysql /backup

COPY ./my-gtid.cnf /etc/my.cnf
COPY ./docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY ./Dockerfile /Dockerfile

RUN mkdir /code
COPY ./*.py /code/
COPY ./*.t /code/
RUN chmod +x /code/*.py

ENTRYPOINT [ "/entrypoint.sh" ]

