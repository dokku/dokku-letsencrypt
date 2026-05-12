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
  dokku letsencrypt:set --global dns-provider "" || true
  dokku letsencrypt:set --global dns-provider-EXEC_PATH "" || true
}

@test "lego-docker-options is persisted to the per-hash docker_options file" {
  dokku letsencrypt:set "$APP" lego-docker-options "-v /tmp/sentinel:/sentinel:ro"
  # Configuration directory is created before the ACME network round-trip,
  # so the plumbing assertion holds regardless of whether issuance succeeds.
  dokku letsencrypt:enable "$APP" || true

  local found=0
  for dir in $(config_hash_dirs "$APP"); do
    if $SUDO grep -qF -- "-v /tmp/sentinel:/sentinel:ro" "$dir/docker_options" 2>/dev/null; then
      found=1
      break
    fi
  done
  [ "$found" -eq 1 ]
}

@test "changing lego-docker-options creates a new config hash directory" {
  dokku letsencrypt:enable "$APP" || true
  local baseline_count
  baseline_count="$(config_hash_dirs "$APP" | wc -l | tr -d ' ')"

  dokku letsencrypt:set "$APP" lego-docker-options "-v /tmp/sentinel:/sentinel:ro"
  dokku letsencrypt:enable "$APP" || true
  local new_count
  new_count="$(config_hash_dirs "$APP" | wc -l | tr -d ' ')"

  [ "$new_count" -gt "$baseline_count" ]
}

@test "lego exec DNS provider issues a cert with a script mounted via lego-docker-options" {
  # Drop the exec script onto a path that's visible to both the dokku
  # container (where this test runs) and the host docker daemon (which
  # actually launches the lego container). DOKKU_HOST_ROOT is set by the
  # compose stack so that $DOKKU_HOST_ROOT/<app>/... resolves on the host
  # to the same file we write under /home/dokku/<app>/... here.
  local script_in_container="/home/dokku/${APP}/letsencrypt/exec-dns.sh"
  local script_on_host="${DOKKU_HOST_ROOT:-/home/dokku}/${APP}/letsencrypt/exec-dns.sh"
  $SUDO mkdir -p "$(dirname "$script_in_container")"
  $SUDO cp "${BATS_TEST_DIRNAME}/lego/challtestsrv-dns.sh" "$script_in_container"
  $SUDO chmod 0755 "$script_in_container"

  dokku letsencrypt:set --global dns-provider exec
  dokku letsencrypt:set --global dns-provider-EXEC_PATH /scripts/dns.sh
  dokku letsencrypt:set "$APP" lego-docker-options "-v ${script_on_host}:/scripts/dns.sh:ro"

  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]

  assert_cert_exists "$APP"
  assert_cert_issued_by_pebble "$APP"
  assert_cert_san_contains "$APP" "$DOMAIN"
}
