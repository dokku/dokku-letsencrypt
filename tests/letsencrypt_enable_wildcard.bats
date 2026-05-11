#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  WILD_DOMAIN="*.${APP}.${TEST_DOMAIN_BASE}"
  FILESAFE_DOMAIN="_.${APP}.${TEST_DOMAIN_BASE}"
  create_app "$APP"
  set_domain "$APP" "$WILD_DOMAIN"

  dokku letsencrypt:set --global dns-provider exec
  dokku letsencrypt:set --global dns-provider-EXEC_PATH /usr/local/bin/challtestsrv-dns.sh
  dokku letsencrypt:set --global dns-provider-EXEC_MODE RAW
}

teardown() {
  cleanup_app "$APP"
  dokku letsencrypt:set --global dns-provider ""
  dokku letsencrypt:set --global dns-provider-EXEC_PATH ""
  dokku letsencrypt:set --global dns-provider-EXEC_MODE ""
}

@test "letsencrypt:enable issues a wildcard Pebble cert via DNS-01" {
  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]

  current="$(current_config_dir "$APP")"
  [ -f "$current/certificates/${FILESAFE_DOMAIN}.crt" ]
  [ -f "$current/certificates/${FILESAFE_DOMAIN}.key" ]

  assert_cert_exists "$APP"
  assert_cert_san_contains "$APP" "*.${APP}.${TEST_DOMAIN_BASE}"
}
