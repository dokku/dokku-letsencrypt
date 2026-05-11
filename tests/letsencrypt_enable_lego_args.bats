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

@test "lego-docker-args is appended to the lego command line" {
  dokku letsencrypt:set "$APP" lego-docker-args "--cert.timeout=45"
  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]

  current="$(current_config_dir "$APP")"
  $SUDO test -f "$current/config"
  $SUDO grep -qF -- "--cert.timeout=45" "$current/config"
}

@test "changing lego-docker-args changes the config hash" {
  dokku letsencrypt:enable "$APP"
  baseline_hash="$(basename "$(current_config_dir "$APP")")"

  dokku letsencrypt:set "$APP" lego-docker-args "--cert.timeout=45"
  dokku letsencrypt:enable "$APP"
  new_hash="$(basename "$(current_config_dir "$APP")")"

  [ "$baseline_hash" != "$new_hash" ]
}
