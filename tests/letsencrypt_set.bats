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

@test "letsencrypt:set writes app-level property" {
  run dokku letsencrypt:set "$APP" email "app@dokku.test"
  [ "$status" -eq 0 ]

  run dokku letsencrypt:report "$APP" --letsencrypt-email
  [ "$status" -eq 0 ]
  [ "$output" = "app@dokku.test" ]
}

@test "letsencrypt:set --global writes global property" {
  run dokku letsencrypt:set --global graceperiod 12345
  [ "$status" -eq 0 ]

  run dokku letsencrypt:report "$APP" --letsencrypt-global-graceperiod
  [ "$status" -eq 0 ]
  [ "$output" = "12345" ]
}

@test "app-level property overrides global in computed value" {
  dokku letsencrypt:set --global graceperiod 100
  dokku letsencrypt:set "$APP" graceperiod 200

  run dokku letsencrypt:report "$APP" --letsencrypt-computed-graceperiod
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
}

@test "unsetting an app property falls back to global" {
  dokku letsencrypt:set --global graceperiod 100
  dokku letsencrypt:set "$APP" graceperiod 200
  dokku letsencrypt:set "$APP" graceperiod ""

  run dokku letsencrypt:report "$APP" --letsencrypt-computed-graceperiod
  [ "$status" -eq 0 ]
  [ "$output" = "100" ]
}

@test "letsencrypt:set rejects unknown keys" {
  run dokku letsencrypt:set "$APP" notakey value
  [ "$status" -ne 0 ]
}

@test "dns-provider-* keys are accepted" {
  run dokku letsencrypt:set "$APP" dns-provider-EXEC_PATH /usr/local/bin/foo.sh
  [ "$status" -eq 0 ]
}

@test "letsencrypt:report shows expected fields when nothing is set" {
  run dokku letsencrypt:report "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Letsencrypt active"
  echo "$output" | grep -q "Letsencrypt computed email"
  echo "$output" | grep -q "Letsencrypt computed server"
  echo "$output" | grep -q "Letsencrypt computed graceperiod"
}
