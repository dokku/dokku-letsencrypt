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

@test "letsencrypt:active reports false before enable" {
  run dokku letsencrypt:active "$APP"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "letsencrypt:active reports true after enable" {
  dokku letsencrypt:enable "$APP"
  run dokku letsencrypt:active "$APP"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "letsencrypt:active reports false after the cert is removed" {
  dokku letsencrypt:enable "$APP"
  dokku certs:remove "$APP"

  run dokku letsencrypt:active "$APP"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}
