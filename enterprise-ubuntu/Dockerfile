FROM ubuntu:14.04
MAINTAINER roberto.polli@par-tec.it
RUN apt-get update

RUN apt-get install -y gdebi-core \
    unzip \
    wget    

# basic repo stuff: EPEL and Oracle MySQL GA
ADD *.zip /

RUN wget https://dev.mysql.com/get/mysql-apt-config_0.3.3-2ubuntu14.04_all.deb

# Uncompress and install all .deb packages
#  included in .zip files
RUN for zipfile in V*.zip; do unzip "$zipfile" -d "${zipfile%%.zip}"; done
RUN find V* -name \*.deb | xargs gdebi -n 

RUN find V* -name \*.tar.gz -exec tar xf "{}" \; 


RUN rm /var/lib/mysql/* -fr

VOLUME /var/lib/mysql
VOLUME /backup

RUN useradd backup -d /backup -g mysql
RUN chown -R mysql:mysql /var/lib/mysql
RUN chown -R backup:mysql /backup


# Add MySQLMonitor stuff
VOLUME /opt/mysql/enterprise/
RUN chmod +x /entrypoint-monitor.sh
RUN chown -R mysql:mysql /opt/mysql/enterprise/

# default entrypoint!
ENTRYPOINT [ "/entrypoint.sh" ]

COPY ./Dockerfile /Dockerfile
