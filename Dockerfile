FROM alpine:edge

ARG WORK=~

RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

RUN apk --no-cache add python \
    py-pip \
    py-m2crypto \
    libsodium \
    git

RUN pip install cymysql

RUN mkdir -p $WORK && \
    git clone -b manyuser https://gitlab.com/ManSora/Scientific-Internetsocks.git $WORK/shadowsocks

RUN cp $WORK/shadowsocks/Config.simple.py $WORK/shadowsocks/Config.py && \
    sed -ri "s@^(MYSQL_HOST = ).*@\1'$MYSQL_HOST'@" $WORK/shadowsocks/Config.py && \
    sed -ri "s@^(MYSQL_PORT = ).*@\1$MYSQL_PORT@" $WORK/shadowsocks/Config.py && \
    sed -ri "s@^(MYSQL_USER = ).*@\1'$MYSQL_USER'@" $WORK/shadowsocks/Config.py && \
    sed -ri "s@^(MYSQL_PASS = ).*@\1'$MYSQL_PASSWORD'@" $WORK/shadowsocks/Config.py && \
    sed -ri "s@^(MYSQL_DB = ).*@\1'$MYSQL_DBNAME'@" $WORK/shadowsocks/Config.py

RUN cp $WORK/shadowsocks/config.json $WORK/shadowsocks/user-config.json && \
    sed -ri "s@^(.*\"node_name\": ).*@\1\"$NODE_NAME\",@" $WORK/shadowsocks/user-config.json

WORKDIR $WORK/shadowsocks

CMD python server.py
