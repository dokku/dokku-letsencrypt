FROM goacme/lego:v4.35.2

RUN apk add --no-cache curl bash

COPY pebble.minica.pem /etc/letest/pebble.minica.pem
COPY challtestsrv-dns.sh /usr/local/bin/challtestsrv-dns.sh

ENV LEGO_CA_CERTIFICATES=/etc/letest/pebble.minica.pem
