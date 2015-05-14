#
# Files required for this image
# V74342-01.zip
# V74910-01.zip
# V74923-01.zip
# V74938-01.zip
# V74958-01.zip
# V75293-01.zip
#
FROM ubuntu:14.04
MAINTAINER roberto.polli@par-tec.it
RUN apt-get update

RUN apt-get install -y gdebi-core \
    libaio1 \
    tree \
    unzip \
    wget    

# basic repo stuff: EPEL and Oracle MySQL GA
ADD *.zip /

# RUN wget https://dev.mysql.com/get/mysql-apt-config_0.3.3-2ubuntu14.04_all.deb

# Uncompress and install all .deb packages
#  included in .zip files
RUN for zipfile in V*.zip; do unzip "$zipfile" -d "${zipfile%%.zip}"; done
RUN find /V* -name \*.deb -exec  gdebi -n  "{}" \;

RUN find /V* -name \*.tar.gz -exec tar xf "{}" \; 

RUN echo > /etc/profile.d/Z99-mysql.sh "export PATH+=:/opt/mysql/server-5.6/bin:/opt/mysql/server-5.6/scripts" 
RUN chmod +x /etc/profile.d/Z99-mysql.sh


RUN rm /var/lib/mysql/* -fr

VOLUME /var/lib/mysql
VOLUME /backup

# Add a mysql user which is unable 
#  to login 
RUN useradd mysql -d /var/lib/mysql -s /usr/sbin/nologin
RUN useradd mysqlbackup -d /mysqlbackup -g mysql -s  /usr/sbin/nologin
RUN chown -R mysql:mysql /var/lib/mysql
RUN chown -R mysqlbackup:mysql /backup

#
## Add MySQLMonitor stuff
#VOLUME /opt/mysql/enterprise/
#RUN chmod +x /entrypoint-monitor.sh
#RUN chown -R mysql:mysql /opt/mysql/enterprise/
#
## default entrypoint!
#ENTRYPOINT [ "/entrypoint.sh" ]
#
#COPY ./Dockerfile /Dockerfile
