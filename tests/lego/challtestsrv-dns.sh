#!/bin/sh
# Shim invoked by lego's `exec` DNS provider.
# Default mode invokes:
#   present <fqdn> <txt-value>
#   cleanup <fqdn> <txt-value>
# Translates each call into a challtestsrv REST request.

set -eu

CHALLTESTSRV="${CHALLTESTSRV_URL:-http://172.17.0.1:8055}"

action="$1"
fqdn="$2"
value="${3:-}"

# challtestsrv expects fqdns with trailing dot
case "$fqdn" in
  *.) ;;
  *)  fqdn="${fqdn}." ;;
esac

case "$action" in
  present)
    curl -sf -X POST -H 'Content-Type: application/json' \
      -d "{\"host\":\"${fqdn}\",\"value\":\"${value}\"}" \
      "${CHALLTESTSRV}/set-txt" >/dev/null
    ;;
  cleanup)
    curl -sf -X POST -H 'Content-Type: application/json' \
      -d "{\"host\":\"${fqdn}\"}" \
      "${CHALLTESTSRV}/clear-txt" >/dev/null
    ;;
  *)
    echo "challtestsrv-dns.sh: unknown action '${action}'" >&2
    exit 2
    ;;
esac
