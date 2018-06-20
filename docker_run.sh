#!/bin/sh
PATH=/bin:/sbin:$PATH

set -e

if [ "${1:0:1}" = '-' ]; then
    set -- python "$@"
fi

cp /shadowsocks/Config.simple.py /shadowsocks/Config.py
sed -ri "s@^(MYSQL_HOST = ).*@\1'$MYSQL_HOST'@" /shadowsocks/Config.py
sed -ri "s@^(MYSQL_PORT = ).*@\1$MYSQL_PORT@" /shadowsocks/Config.py
sed -ri "s@^(MYSQL_USER = ).*@\1'$MYSQL_USER'@" /shadowsocks/Config.py
sed -ri "s@^(MYSQL_PASS = ).*@\1'$MYSQL_PASSWORD'@" /shadowsocks/Config.py
sed -ri "s@^(MYSQL_DB = ).*@\1'$MYSQL_DBNAME'@" /shadowsocks/Config.py

cp /shadowsocks/config.json /shadowsocks/user-config.json
sed -ri "s@^(.*\"node_name\": ).*@\1\"$NODE_NAME\",@" /shadowsocks/user-config.json

exec python /shadowsocks/server.py m
