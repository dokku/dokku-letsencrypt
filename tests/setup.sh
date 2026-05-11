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

# The first few `apps:create` invocations on a freshly-started dokku container
# can exit non-zero while nginx is still settling. Run a throwaway create/destroy
# now so the test suite doesn't see those early failures.
log "Warming up apps:create / nginx reload"
dokku apps:create letest-warmup >/dev/null
dokku --force apps:destroy letest-warmup >/dev/null

log "Setup complete"
