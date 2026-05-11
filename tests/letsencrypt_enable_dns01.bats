#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  DOMAIN="${APP}.${TEST_DOMAIN_BASE}"
  create_app "$APP"
  set_domain "$APP" "$DOMAIN"

  dokku letsencrypt:set --global dns-provider exec
  dokku letsencrypt:set --global dns-provider-EXEC_PATH /usr/local/bin/challtestsrv-dns.sh
}

teardown() {
  cleanup_app "$APP"
  dokku letsencrypt:set --global dns-provider ""
  dokku letsencrypt:set --global dns-provider-EXEC_PATH ""
}

@test "letsencrypt:enable issues a Pebble cert via DNS-01" {
  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]

  assert_cert_exists "$APP"
  assert_cert_issued_by_pebble "$APP"
  assert_cert_san_contains "$APP" "$DOMAIN"
}

@test "dns-provider-* properties are written into docker.env" {
  dokku letsencrypt:enable "$APP"

  current="$(current_config_dir "$APP")"
  $SUDO test -f "$current/docker.env"
  $SUDO grep -q '^EXEC_PATH=/usr/local/bin/challtestsrv-dns.sh$' "$current/docker.env"
}
