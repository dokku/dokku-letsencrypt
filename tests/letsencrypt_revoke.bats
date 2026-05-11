#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  DOMAIN="${APP}.${TEST_DOMAIN_BASE}"
  create_app "$APP"
  set_domain "$APP" "$DOMAIN"
  register_a_record "$DOMAIN"
}

teardown() {
  clear_a_record "$DOMAIN"
  cleanup_app "$APP"
}

@test "letsencrypt:revoke removes the certificate" {
  dokku letsencrypt:enable "$APP"
  [ -f "$(cert_path_for "$APP")" ]

  run dokku letsencrypt:revoke "$APP"
  [ "$status" -eq 0 ]

  run dokku letsencrypt:active "$APP"
  [ "$output" = "false" ]
}
