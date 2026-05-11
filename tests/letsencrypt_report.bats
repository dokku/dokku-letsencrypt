#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
  dokku letsencrypt:set --global graceperiod "" || true
}

@test "letsencrypt:report renders a stdout report by default" {
  run dokku letsencrypt:report "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "${APP} letsencrypt information"
  echo "$output" | grep -q "Letsencrypt active"
  echo "$output" | grep -q "Letsencrypt computed email"
}

@test "letsencrypt:report --format json returns valid JSON for an app" {
  dokku letsencrypt:set "$APP" email "app@dokku.test"

  run dokku letsencrypt:report "$APP" --format json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  email="$(echo "$output" | jq -r '.email')"
  [ "$email" = "app@dokku.test" ]
  computed="$(echo "$output" | jq -r '."computed-email"')"
  [ "$computed" = "app@dokku.test" ]
}

@test "letsencrypt:report --format json without an app emits one object per app" {
  run /bin/bash -c "dokku letsencrypt:report --format json | jq -e ."
  [ "$status" -eq 0 ]
}

@test "letsencrypt:report --global prints a global header" {
  run dokku letsencrypt:report --global
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "global letsencrypt information"
  echo "$output" | grep -q "Letsencrypt global email"
}

@test "letsencrypt:report --global --format json returns only global keys" {
  dokku letsencrypt:set --global graceperiod 11111

  run dokku letsencrypt:report --global --format json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  non_global="$(echo "$output" | jq -r 'keys[]' | grep -v '^global-' || true)"
  [ -z "$non_global" ]
  value="$(echo "$output" | jq -r '."global-graceperiod"')"
  [ "$value" = "11111" ]
}

@test "letsencrypt:report --format json combined with an info flag is rejected" {
  run dokku letsencrypt:report "$APP" --format json --letsencrypt-email
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "format flag cannot be specified when specifying an info flag"
}

@test "letsencrypt:report info flag still returns just that value" {
  dokku letsencrypt:set "$APP" graceperiod 4242
  run dokku letsencrypt:report "$APP" --letsencrypt-graceperiod
  [ "$status" -eq 0 ]
  [ "$output" = "4242" ]
}
