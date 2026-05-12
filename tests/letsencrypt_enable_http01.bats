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

@test "letsencrypt:enable is a no-op when a valid cert already exists" {
  # Pebble issues 24h certs; shrink the grace period so the freshly issued
  # cert is comfortably outside it.
  dokku letsencrypt:set "$APP" graceperiod 60
  dokku letsencrypt:enable "$APP"
  before="$(current_config_dir "$APP")"

  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "still valid"
  ! echo "$output" | grep -qi "Certificate retrieved successfully"

  after="$(current_config_dir "$APP")"
  [ "$before" = "$after" ]
}

@test "letsencrypt:enable --force reissues even when a valid cert exists" {
  dokku letsencrypt:set "$APP" graceperiod 60
  dokku letsencrypt:enable "$APP"
  before_dir="$(current_config_dir "$APP")"

  run dokku letsencrypt:enable "$APP" --force
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "Certificate retrieved successfully"
  ! echo "$output" | grep -qi "still valid"

  after_dir="$(current_config_dir "$APP")"
  # no config changed, so the same hash dir should still be in use
  [ "$before_dir" = "$after_dir" ]
}

@test "letsencrypt:enable skips the '_' default-vhost domain when other domains are present" {
  add_domain "$APP" "_"

  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]

  assert_cert_exists "$APP"
  assert_cert_san_contains "$APP" "$DOMAIN"

  crt="$(cert_path_for "$APP")"
  ! cert_san "$crt" | grep -qE '(^| )_($|,)'
}

@test "letsencrypt:enable fails when '_' is the only domain" {
  dokku domains:clear "$APP"
  set_domain "$APP" "_"

  run dokku letsencrypt:enable "$APP"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no domains"
}

@test "letsencrypt:enable normalizes the per-app webroot perms to 0755" {
  webroot="/var/lib/dokku/data/letsencrypt/$APP"
  # Pre-stage the dir with the broken mode the bug describes, owned by the
  # dokku user so the plugin (which runs as dokku via the dokku wrapper)
  # can chmod it.
  $SUDO install -d -o dokku -g dokku -m 0700 "$webroot"

  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]

  perm="$($SUDO stat -c '%a' "$webroot")"
  [ "$perm" = "755" ]
}

@test "letsencrypt:enable auto-injects http:80 when only a non-80 http mapping exists" {
  dokku ports:set "$APP" http:8080:8080

  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "Adding http:80:8080 port mapping"

  assert_cert_exists "$APP"
  assert_cert_issued_by_pebble "$APP"

  run dokku ports:report "$APP" --ports-map
  [ "$status" -eq 0 ]
  echo "$output" | grep -qF "http:80:8080"
  echo "$output" | grep -qF "http:8080:8080"
}

@test "letsencrypt:enable leaves the port map untouched when http:80 is already mapped" {
  dokku ports:set "$APP" http:80:5000

  before="$(dokku ports:report "$APP" --ports-map)"

  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -qi "Adding http:80"

  after="$(dokku ports:report "$APP" --ports-map)"
  [ "$before" = "$after" ]
}

@test "letsencrypt:enable fails with a helpful error when no http or https mapping exists" {
  dokku ports:set "$APP" tcp:2222:2222

  run dokku letsencrypt:enable "$APP"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no http or https proxy port mapping"
  echo "$output" | grep -qi "dokku ports:add"
}

@test "letsencrypt:enable reissues when a new domain is added" {
  dokku letsencrypt:set "$APP" graceperiod 60
  dokku letsencrypt:enable "$APP"
  assert_cert_san_contains "$APP" "$DOMAIN"

  EXTRA_DOMAIN="extra.${APP}.${TEST_DOMAIN_BASE}"
  register_a_record "$EXTRA_DOMAIN"
  add_domain "$APP" "$EXTRA_DOMAIN"

  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "Certificate retrieved successfully"

  assert_cert_san_contains "$APP" "$DOMAIN"
  assert_cert_san_contains "$APP" "$EXTRA_DOMAIN"

  clear_a_record "$EXTRA_DOMAIN"
}
