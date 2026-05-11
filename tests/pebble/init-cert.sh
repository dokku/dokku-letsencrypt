#!/bin/sh
# Generate a per-run Pebble HTTPS cert for the directory endpoint.
# The cert must include IP:172.17.0.1 in its SAN so lego (which connects
# from the host docker default bridge to the bridge gateway) accepts it.
#
# Inputs (env or defaults):
#   PEBBLE_CERT_IP   IP SAN to include (default 172.17.0.1)
#   PEBBLE_CERT_DIR  Output directory (default /certs)
#   MINICA_CERT      Path to the minica root cert (default /minica/pebble.minica.pem)
#   MINICA_KEY       Path to the minica root key  (default /minica/pebble.minica.key.pem)

set -eu

PEBBLE_CERT_IP="${PEBBLE_CERT_IP:-172.17.0.1}"
PEBBLE_CERT_DIR="${PEBBLE_CERT_DIR:-/certs}"
MINICA_CERT="${MINICA_CERT:-/minica/pebble.minica.pem}"
MINICA_KEY="${MINICA_KEY:-/minica/pebble.minica.key.pem}"

mkdir -p "$PEBBLE_CERT_DIR"

if [ -f "$PEBBLE_CERT_DIR/pebble.cert.pem" ] && [ -f "$PEBBLE_CERT_DIR/pebble.key.pem" ]; then
  if openssl x509 -in "$PEBBLE_CERT_DIR/pebble.cert.pem" -noout -text 2>/dev/null \
      | grep -q "IP Address:${PEBBLE_CERT_IP}"; then
    echo "init-cert: existing cert already has SAN IP:${PEBBLE_CERT_IP}; reusing"
    exit 0
  fi
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat >"$WORK/openssl.cnf" <<EOF
[req]
distinguished_name = dn
req_extensions     = v3_req
prompt             = no

[dn]
CN = pebble

[v3_req]
basicConstraints     = CA:FALSE
keyUsage             = digitalSignature, keyEncipherment
extendedKeyUsage     = serverAuth
subjectAltName       = @alt_names

[alt_names]
DNS.1 = pebble
DNS.2 = localhost
IP.1  = ${PEBBLE_CERT_IP}
IP.2  = 127.0.0.1
EOF

openssl genrsa -out "$WORK/pebble.key.pem" 2048 2>/dev/null

openssl req -new \
  -key "$WORK/pebble.key.pem" \
  -out "$WORK/pebble.csr.pem" \
  -config "$WORK/openssl.cnf"

openssl x509 -req \
  -in "$WORK/pebble.csr.pem" \
  -CA "$MINICA_CERT" \
  -CAkey "$MINICA_KEY" \
  -CAcreateserial \
  -CAserial "$WORK/minica.srl" \
  -out "$WORK/pebble.cert.pem" \
  -days 30 \
  -extensions v3_req \
  -extfile "$WORK/openssl.cnf"

mv "$WORK/pebble.cert.pem" "$PEBBLE_CERT_DIR/pebble.cert.pem"
mv "$WORK/pebble.key.pem"  "$PEBBLE_CERT_DIR/pebble.key.pem"

echo "init-cert: minted ${PEBBLE_CERT_DIR}/pebble.cert.pem (SAN IP:${PEBBLE_CERT_IP})"
