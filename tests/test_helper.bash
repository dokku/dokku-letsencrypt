#!/usr/bin/env bash
# Helpers for the dokku-letsencrypt bats suite. Sourced by every *.bats file.
# All commands run inside the dokku container; reach the host via 172.17.0.1.

CHALLTESTSRV_URL="${CHALLTESTSRV_URL:-http://172.17.0.1:8055}"
TEST_DOMAIN_BASE="${TEST_DOMAIN_BASE:-dokku.test}"
DEFAULT_A_TARGET="${DEFAULT_A_TARGET:-172.17.0.1}"

new_app_name() {
  echo "letest-${BATS_TEST_NUMBER:-0}-$(date +%s)-${RANDOM}"
}

create_app() {
  local app="$1"
  dokku apps:create "$app"
}

cleanup_app() {
  local app="$1"
  if dokku apps:exists "$app" >/dev/null 2>&1; then
    dokku --force apps:destroy "$app" >/dev/null 2>&1 || true
  fi
}

set_domain() {
  local app="$1" domain="$2"
  dokku domains:set "$app" "$domain"
}

add_domain() {
  local app="$1" domain="$2"
  dokku domains:add "$app" "$domain"
}

register_a_record() {
  local host="$1" target="${2:-$DEFAULT_A_TARGET}"
  case "$host" in
    *.) ;;
    *) host="${host}." ;;
  esac
  curl -sf -X POST -H 'Content-Type: application/json' \
    -d "{\"host\":\"${host}\",\"addresses\":[\"${target}\"]}" \
    "${CHALLTESTSRV_URL}/add-a" >/dev/null
}

clear_a_record() {
  local host="$1"
  case "$host" in
    *.) ;;
    *) host="${host}." ;;
  esac
  curl -sf -X POST -H 'Content-Type: application/json' \
    -d "{\"host\":\"${host}\"}" \
    "${CHALLTESTSRV_URL}/clear-a" >/dev/null || true
}

cert_path_for() {
  local app="$1"
  echo "/home/dokku/${app}/tls/server.letsencrypt.crt"
}

active_cert_path() {
  local app="$1"
  echo "/home/dokku/${app}/letsencrypt/certs/current/fullchain.pem"
}

assert_cert_exists() {
  local app="$1"
  local crt
  crt="$(cert_path_for "$app")"
  [ -f "$crt" ] || {
    echo "expected cert at $crt" >&2
    return 1
  }
}

cert_subject() {
  openssl x509 -in "$1" -noout -subject
}

cert_issuer() {
  openssl x509 -in "$1" -noout -issuer
}

cert_san() {
  openssl x509 -in "$1" -noout -text | awk '/X509v3 Subject Alternative Name/{getline; print}'
}

cert_not_after_epoch() {
  local crt="$1"
  date -u -d "$(openssl x509 -in "$crt" -noout -enddate | sed 's/^notAfter=//')" +%s
}

assert_cert_issued_by_pebble() {
  local app="$1"
  local crt
  crt="$(cert_path_for "$app")"
  cert_issuer "$crt" | grep -qi pebble || {
    echo "expected Pebble issuer; got: $(cert_issuer "$crt")" >&2
    return 1
  }
}

assert_cert_san_contains() {
  local app="$1" needle="$2"
  local crt
  crt="$(cert_path_for "$app")"
  cert_san "$crt" | grep -qF "$needle" || {
    echo "expected SAN to contain '$needle'; got: $(cert_san "$crt")" >&2
    return 1
  }
}

current_config_dir() {
  local app="$1"
  readlink -f "/home/dokku/${app}/letsencrypt/certs/current"
}

config_hash_dirs() {
  local app="$1"
  local base="/home/dokku/${app}/letsencrypt/certs"
  [ -d "$base" ] || return 0
  find "$base" -mindepth 1 -maxdepth 1 -type d -print
}
