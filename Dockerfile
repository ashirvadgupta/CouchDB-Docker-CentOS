FROM library/centos
MAINTAINER ASHIRVAD GUPTA
USER root
RUN yum install libicu* js-devel-1.8.5 libicu-devel libtool -y
COPY couchdb.tar.gz /opt/
RUN groupadd -r couchdb && useradd -d /opt/couchdb -g couchdb couchdb
RUN cd /opt/ && \
    tar -zxvf couchdb.tar.gz && \
    rm -rf couchdb.tar.gz
COPY local.ini /opt/couchdb/etc/local.d/
COPY vm.args /opt/couchdb/etc/
COPY cluster.sh /opt/couchdb/
COPY entrypoint.sh /opt/couchdb/
COPY schema.sh /opt/couchdb/
COPY ./wait-for-it.sh /usr/src
COPY Views /opt/couchdb/
RUN chown -R couchdb:couchdb /opt/couchdb/entrypoint.sh /opt/couchdb/ /opt/couchdb/schema.sh /opt/couchdb/etc/local.d/ /opt/couchdb/etc/vm.args /opt/couchdb/cluster.sh  /usr/src/wait-for-it.sh  && \
    find /opt/couchdb/ -type d -exec chmod 755 {} + && \
    find /opt/couchdb/ -type f -exec chmod 755 {} + && \
    chmod 755 /usr/src/wait-for-it.sh
WORKDIR /opt/couchdb
RUN mkdir data && chown -R couchdb:couchdb data/
EXPOSE 5984 5986 4369 9100-9200
VOLUME ["/opt/couchdb/data"]
USER couchdb
ENTRYPOINT ["/opt/couchdb/entrypoint.sh"]
#CMD ["sh","-c","/opt/couchdb/bin/couchdb"]
HEALTHCHECK --timeout=3s CMD curl -f http://127.0.0.1:5984/ || exit 1
