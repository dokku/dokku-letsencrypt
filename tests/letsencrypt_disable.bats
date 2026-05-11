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

@test "letsencrypt:disable removes cert files and the letsencrypt directory" {
  dokku letsencrypt:enable "$APP"
  $SUDO test -d "/home/dokku/${APP}/letsencrypt"
  $SUDO test -f "/home/dokku/${APP}/tls/server.letsencrypt.crt"

  run dokku letsencrypt:disable "$APP"
  [ "$status" -eq 0 ]

  $SUDO test ! -d "/home/dokku/${APP}/letsencrypt"
  $SUDO test ! -d "/home/dokku/${APP}/tls"

  run dokku letsencrypt:active "$APP"
  [ "$output" = "false" ]
}

@test "letsencrypt:disable leaves the app intact" {
  dokku letsencrypt:enable "$APP"
  dokku letsencrypt:disable "$APP"

  run dokku apps:exists "$APP"
  [ "$status" -eq 0 ]
}
