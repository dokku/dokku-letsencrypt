FROM alpine:3.20

RUN apk add --no-cache openssl

COPY init-cert.sh /usr/local/bin/init-cert.sh
RUN chmod +x /usr/local/bin/init-cert.sh

ENTRYPOINT ["/usr/local/bin/init-cert.sh"]
