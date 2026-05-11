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

@test "letsencrypt:list lists enrolled apps with expiry columns" {
  dokku letsencrypt:enable "$APP"

  run dokku letsencrypt:list
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "App name"
  echo "$output" | grep -q "Certificate Expiry"
  echo "$output" | grep -q "Time before expiry"
  echo "$output" | grep -q "Time before renewal"
  echo "$output" | grep -q "$APP"
}

@test "letsencrypt:list omits apps without an active cert" {
  run dokku letsencrypt:list
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q "$APP"
}
