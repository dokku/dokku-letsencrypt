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

@test "letsencrypt:cleanup removes stale config hash directories" {
  dokku letsencrypt:enable "$APP"
  baseline_hash="$(basename "$(current_config_dir "$APP")")"

  # change config to force a new hash, then enable again
  dokku letsencrypt:set "$APP" lego-docker-args "--cert.timeout=45"
  dokku letsencrypt:enable "$APP"
  new_hash="$(basename "$(current_config_dir "$APP")")"
  [ "$baseline_hash" != "$new_hash" ]

  # both hash dirs exist before cleanup
  [ -d "/home/dokku/${APP}/letsencrypt/certs/${baseline_hash}" ]
  [ -d "/home/dokku/${APP}/letsencrypt/certs/${new_hash}" ]

  run dokku letsencrypt:cleanup "$APP"
  [ "$status" -eq 0 ]

  [ ! -d "/home/dokku/${APP}/letsencrypt/certs/${baseline_hash}" ]
  [ -d "/home/dokku/${APP}/letsencrypt/certs/${new_hash}" ]
  [ "$(basename "$(current_config_dir "$APP")")" = "$new_hash" ]
}
