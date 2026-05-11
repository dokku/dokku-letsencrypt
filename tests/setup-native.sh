#!/usr/bin/env bash
# Run on a Linux host (Ubuntu 24.04). Bootstraps Dokku natively, installs the
# plugin from the working tree, and points it at the Pebble services that the
# compose stack started in the background.
set -euo pipefail

PLUGIN_SRC="${PLUGIN_SRC:-${GITHUB_WORKSPACE:-$(pwd)}}"
PEBBLE_DIRECTORY="${PEBBLE_DIRECTORY:-https://172.17.0.1:14000/dir}"
LETSENCRYPT_TEST_EMAIL="${LETSENCRYPT_TEST_EMAIL:-test@dokku.test}"
DOKKU_TAG="${DOKKU_TAG:-}"

log() { echo "-----> $*"; }

if ! command -v dokku >/dev/null 2>&1; then
  log "Preparing apt/nginx prerequisites for dokku bootstrap"
  sudo mkdir -p /etc/nginx
  sudo curl -fsSL https://raw.githubusercontent.com/dokku/dokku/master/tests/dhparam.pem -o /etc/nginx/dhparam.pem
  echo "dokku dokku/skip_key_file boolean true" | sudo debconf-set-selections
  echo "dokku dokku/hostname string dokku.test" | sudo debconf-set-selections
  echo "dokku dokku/vhost_enable boolean true" | sudo debconf-set-selections
  echo "dokku dokku/web_config boolean false" | sudo debconf-set-selections

  log "Downloading dokku bootstrap.sh"
  curl -fsSL https://raw.githubusercontent.com/dokku/dokku/master/bootstrap.sh -o /tmp/dokku-bootstrap.sh
  if [ -n "$DOKKU_TAG" ]; then
    log "Running bootstrap.sh with DOKKU_TAG=$DOKKU_TAG"
    sudo DOKKU_TAG="$DOKKU_TAG" bash /tmp/dokku-bootstrap.sh
  else
    log "Running bootstrap.sh (latest)"
    sudo bash /tmp/dokku-bootstrap.sh
  fi
else
  log "dokku already installed; skipping bootstrap"
fi

log "Writing letsencrypt env override to /home/dokku/.dokkurc"
sudo mkdir -p /home/dokku/.dokkurc
sudo tee /home/dokku/.dokkurc/letsencrypt-test >/dev/null <<'EOF'
export LETSENCRYPT_IMAGE=letest-lego
export LETSENCRYPT_IMAGE_VERSION=latest
export LETSENCRYPT_DISABLE_PULL=true
EOF
sudo chown dokku:dokku /home/dokku/.dokkurc/letsencrypt-test

if sudo dokku plugin:installed letsencrypt; then
  log "letsencrypt plugin already installed; uninstalling first"
  sudo dokku plugin:uninstall letsencrypt
fi

# `dokku plugin:install` derives the destination directory name from the
# basename of the source URL, so stage the plugin source at a path whose
# basename is `letsencrypt` before installing.
log "Staging plugin source at /tmp/letsencrypt"
sudo rm -rf /tmp/letsencrypt
sudo cp -r "${PLUGIN_SRC}" /tmp/letsencrypt

log "Installing letsencrypt plugin from /tmp/letsencrypt"
sudo dokku plugin:install "file:///tmp/letsencrypt"

log "Configuring letsencrypt for Pebble"
sudo dokku letsencrypt:set --global server "${PEBBLE_DIRECTORY}"
sudo dokku letsencrypt:set --global email "${LETSENCRYPT_TEST_EMAIL}"
# Point lego at challtestsrv for recursive lookups (the runner's default
# resolver has no view of the .test TLD), and skip the TXT-record
# propagation check: pebble-challtestsrv answers the TXT lookups pebble
# itself does, but it does not implement SOA queries, so lego's
# zone-discovery step fails. `--dns.propagation-wait` replaces the SOA
# walk with a fixed wait, which is plenty since challtestsrv applies
# `/set-txt` writes immediately.
sudo dokku letsencrypt:set --global lego-docker-args "--dns.resolvers=172.17.0.1:8053 --dns.propagation-wait=1s"

log "Setup complete"
