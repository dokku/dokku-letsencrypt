#!/usr/bin/env bash
# Run inside the dokku container. Installs the plugin from the bind-mounted
# /plugin-src tree, points it at the local Pebble ACME server, and tells it
# to use the test lego image (which trusts the Pebble minica root).
set -euo pipefail

PLUGIN_SRC="${PLUGIN_SRC:-/plugin-src}"
PEBBLE_DIRECTORY="${PEBBLE_DIRECTORY:-https://172.17.0.1:14000/dir}"
LETSENCRYPT_TEST_EMAIL="${LETSENCRYPT_TEST_EMAIL:-test@dokku.test}"

log() { echo "-----> $*"; }

log "Writing letsencrypt env override to /home/dokku/.dokkurc"
mkdir -p /home/dokku/.dokkurc
cat >/home/dokku/.dokkurc/letsencrypt-test <<'EOF'
export LETSENCRYPT_IMAGE=letest-lego
export LETSENCRYPT_IMAGE_VERSION=latest
export LETSENCRYPT_DISABLE_PULL=true
EOF
chown dokku:dokku /home/dokku/.dokkurc/letsencrypt-test

if dokku plugin:installed letsencrypt; then
  log "letsencrypt plugin already installed; uninstalling first"
  dokku plugin:uninstall letsencrypt
fi

# `dokku plugin:install` derives the destination directory name from the
# basename of the source URL, so stage the bind-mounted source at a path
# whose basename is `letsencrypt` before installing.
log "Staging plugin source at /tmp/letsencrypt"
rm -rf /tmp/letsencrypt
cp -r "${PLUGIN_SRC}" /tmp/letsencrypt

log "Installing letsencrypt plugin from /tmp/letsencrypt"
dokku plugin:install "file:///tmp/letsencrypt"

log "Configuring letsencrypt for Pebble"
dokku letsencrypt:set --global server "${PEBBLE_DIRECTORY}"
dokku letsencrypt:set --global email "${LETSENCRYPT_TEST_EMAIL}"
# Point lego at challtestsrv for recursive lookups (the runner's default
# resolver has no view of the .test TLD), and skip the TXT-record
# propagation check: pebble-challtestsrv answers the TXT lookups pebble
# itself does, but it does not implement SOA queries, so lego's
# zone-discovery step fails. `--dns.propagation-wait` replaces the SOA
# walk with a fixed wait, which is plenty since challtestsrv applies
# `/set-txt` writes immediately.
dokku letsencrypt:set --global lego-docker-args "--dns.resolvers=172.17.0.1:8053 --dns.propagation-wait=1s"

# The first few `apps:create` invocations on a freshly-started dokku container
# can exit non-zero while nginx is still settling. Loop here until one
# succeeds so the real test suite never sees those early failures.
log "Warming up apps:create / nginx reload"
warmup_attempts=0
until dokku apps:create letest-warmup >/dev/null 2>&1; do
  warmup_attempts=$((warmup_attempts + 1))
  if [ "$warmup_attempts" -ge 15 ]; then
    log "WARN: warmup apps:create did not succeed after 15 attempts; continuing"
    break
  fi
  sleep 2
done
dokku --force apps:destroy letest-warmup >/dev/null 2>&1 || true

log "Setup complete"
