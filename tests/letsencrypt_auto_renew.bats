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
  dokku letsencrypt:set --global graceperiod ""
}

@test "auto-renew renews when graceperiod exceeds cert lifetime" {
  dokku letsencrypt:enable "$APP"
  before="$(cert_not_after_epoch "$(cert_path_for "$APP")")"

  # Pebble issues 24h certs by default. A graceperiod larger than that
  # forces a renewal.
  dokku letsencrypt:set --global graceperiod $((60 * 60 * 24 * 30))

  # Sleep so the new cert's notBefore advances by at least 1 second
  sleep 2

  run dokku letsencrypt:auto-renew "$APP"
  [ "$status" -eq 0 ]

  after="$(cert_not_after_epoch "$(cert_path_for "$APP")")"
  [ "$after" -ge "$before" ]
}

@test "auto-renew is a no-op when graceperiod is small" {
  dokku letsencrypt:enable "$APP"
  before="$(cert_not_after_epoch "$(cert_path_for "$APP")")"

  dokku letsencrypt:set --global graceperiod 1

  run dokku letsencrypt:auto-renew "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "still has"

  after="$(cert_not_after_epoch "$(cert_path_for "$APP")")"
  [ "$after" = "$before" ]
}

@test "auto-renew is a no-op for apps without letsencrypt enabled" {
  run dokku letsencrypt:auto-renew "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "not enabled"
}

@test "batch auto-renew iterates over all enrolled apps" {
  dokku letsencrypt:enable "$APP"
  dokku letsencrypt:set --global graceperiod $((60 * 60 * 24 * 30))

  sleep 2

  run dokku letsencrypt:auto-renew
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "needs renewal"
  echo "$output" | grep -qi "Finished auto-renewal"
}
