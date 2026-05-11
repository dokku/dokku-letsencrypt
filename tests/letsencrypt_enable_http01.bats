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

@test "letsencrypt:enable issues a Pebble cert via HTTP-01" {
  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]

  assert_cert_exists "$APP"
  assert_cert_issued_by_pebble "$APP"
  assert_cert_san_contains "$APP" "$DOMAIN"

  run dokku letsencrypt:active "$APP"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run dokku certs:report "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "ssl"
}

@test "current symlink points at the issuing config dir" {
  dokku letsencrypt:enable "$APP"

  current="$(current_config_dir "$APP")"
  [ -n "$current" ]
  $SUDO test -d "$current"
  $SUDO test -f "$current/certificates/${DOMAIN}.crt"
  $SUDO test -f "$current/certificates/${DOMAIN}.key"
}

@test "letsencrypt:enable fails without an email" {
  email_backup="$(dokku letsencrypt:report "$APP" --letsencrypt-global-email || true)"
  dokku letsencrypt:set --global email ""

  run dokku letsencrypt:enable "$APP"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "e-mail"

  if [ -n "$email_backup" ]; then
    dokku letsencrypt:set --global email "$email_backup"
  fi
}

@test "letsencrypt:enable fails when the app has no domains" {
  dokku domains:clear "$APP"

  run dokku letsencrypt:enable "$APP"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no domains"
}
