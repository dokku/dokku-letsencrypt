#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  DOMAIN_A="a.${APP}.${TEST_DOMAIN_BASE}"
  DOMAIN_B="b.${APP}.${TEST_DOMAIN_BASE}"
  create_app "$APP"
  set_domain "$APP" "$DOMAIN_A"
  add_domain "$APP" "$DOMAIN_B"
  register_a_record "$DOMAIN_A"
  register_a_record "$DOMAIN_B"
}

teardown() {
  clear_a_record "$DOMAIN_A"
  clear_a_record "$DOMAIN_B"
  cleanup_app "$APP"
}

@test "letsencrypt:enable issues a SAN cert covering both domains" {
  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]

  assert_cert_exists "$APP"
  assert_cert_san_contains "$APP" "$DOMAIN_A"
  assert_cert_san_contains "$APP" "$DOMAIN_B"
}
