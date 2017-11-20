#!/bin/bash
if [ "$COUCHDB_SYNC_ADMINS_NODE" ];then
COUCHDB_HASHED_PASSWORD=`/usr/src/wait-for-it.sh $COUCHDB_SYNC_ADMINS_NODE:$COUCHDB_ADMINPORT -t 3000 -- curl -X GET -u $COUCHDB_USER:$COUCHDB_PASSWORD http://$COUCHDB_SYNC_ADMINS_NODE:$COUCHDB_ADMINPORT/_node/couchdb@$COUCHDB_SYNC_ADMINS_NODENAME/_config/admins/$COUCHDB_USER | sed "s/^\([\"]\)\(.*\)\1\$/\2/g"`
fi

if [ ! -z "$NODENAME" ] && ! grep "couchdb@" /opt/couchdb/etc/vm.args;then
# Cookie is needed so that the nodes can connect to each other using Erlang clustering
if [ -z "$COUCHDB_COOKIE" ];then
echo "-sname couchdb@$NODENAME" >> /opt/couchdb/etc/vm.args
else
echo "-sname couchdb@$NODENAME -setcookie '$COUCHDB_COOKIE'" >> /opt/couchdb/etc/vm.args
fi
else
if ! grep "couchdb@" /opt/couchdb/etc/vm.args;then
if [ -z "$COUCHDB_COOKIE" ];then
echo "-name couchdb@$IPADDRESS" >> /opt/couchdb/etc/vm.args
else
echo "-name couchdb@$IPADDRESS -setcookie '$COUCHDB_COOKIE'" >> /opt/couchdb/etc/vm.args
fi
fi
fi

if [ "$COUCHDB_USER" ] && [ "$COUCHDB_PASSWORD" ] && [ -z "$COUCHDB_SYNC_ADMINS_NODE" ];then
# Create admin
printf "[admins]\n%s = %s\n" "$COUCHDB_USER" "$COUCHDB_PASSWORD"  > /opt/couchdb/etc/local.d/docker.ini
chown couchdb:couchdb /opt/couchdb/etc/local.d/docker.ini
fi

if [ "$COUCHDB_SECRET" ];then
# Set secret
printf "[couch_httpd_auth]\nsecret = %s\n" "$COUCHDB_SECRET" >> /opt/couchdb/etc/local.d/docker.ini
fi

if [ "$COUCHDB_USER" ] && [ "$COUCHDB_PASSWORD" ] && [ ! -z "$COUCHDB_SYNC_ADMINS_NODE" ];then
# Create admin
printf "[admins]\n%s = %s\n" "$COUCHDB_USER" "$COUCHDB_PASSWORD"  > /opt/couchdb/etc/local.d/docker.ini
chown couchdb:couchdb /opt/couchdb/etc/local.d/docker.ini
fi

if [ "$COUCHDB_USER" ] && [ "$COUCHDB_HASHED_PASSWORD" ];then
printf "[admins]\n%s = %s\n" "$COUCHDB_USER" "$COUCHDB_HASHED_PASSWORD" >> /opt/couchdb/etc/local.d/docker.ini
chown couchdb:couchdb /opt/couchdb/etc/local.d/docker.ini
fi

if [ "$COUCHDB_CERT_FILE" ] && [ "$COUCHDB_KEY_FILE" ] && [ "$COUCHDB_CACERT_FILE" ];then
# Enable SSL
printf "[daemons]\nhttpsd = {chttpd, start_link, [https]}\n\n" >> /home/couchdb/couchdb/etc/local.d/docker.ini
printf "[ssl]\ncert_file = %s\nkey_file = %s\ncacert_file = %s\n" "$COUCHDB_CERT_FILE" "$COUCHDB_KEY_FILE" "$COUCHDB_CACERT_FILE" >> /home/couchdb/couchdb/etc/local.d/docker.ini
# As per https://groups.google.com/forum/#!topic/couchdb-user-archive/cBrZ25DHHVA, due to bug
# https://issues.apache.org/jira/browse/COUCHDB-3162, we need the following lines. TODO: remove
# this in a later version of CouchDB 2.
printf "ciphers = undefined\ntls_versions = undefined\nsecure_renegotiate = undefined\n" >> /home/couchdb/couchdb/etc/local.d/cert.ini
chown couchdb:couchdb /opt/couchdb/etc/local.d/cert.ini
fi
cd /opt/couchdb/bin

nohup ./couchdb < /dev/null &

TIMELIMIT=60

SECONDS=0

STATUS_PORT=`netstat -vatn|grep LISTEN|grep 5984|wc -l`

while [ $STATUS_PORT -eq "0" ] && [ $SECONDS -lt $TIMELIMIT ]
do
sleep 10
STATUS_PORT=`netstat -vatn|grep LISTEN|grep 5984|wc -l`
SECONDS=$(($SECONDS+1))
done

cd /opt/couchdb
sh ./schema.sh
while [ $STATUS_PORT -ne "0" ]
do
sleep 10
STATUS_PORT=`netstat -vatn|grep LISTEN|grep 5984|wc -l`
SECONDS=$(($SECONDS+1))
done
exec "$@"
