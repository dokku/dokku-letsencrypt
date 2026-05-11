FROM goacme/lego:v4.35.2

RUN apk add --no-cache curl bash

COPY pebble.minica.pem /etc/letest/pebble.minica.pem
COPY challtestsrv-dns.sh /usr/local/bin/challtestsrv-dns.sh

ENV LEGO_CA_CERTIFICATES=/etc/letest/pebble.minica.pem
ENV LEGO_DNS_RESOLVERS=172.17.0.1:8053
