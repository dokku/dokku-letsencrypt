#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
  dokku letsencrypt:set --global graceperiod "" || true
  dokku letsencrypt:set --global dns-provider "" || true
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

@test "lego-docker-options is accepted" {
  run dokku letsencrypt:set "$APP" lego-docker-options "-v /tmp/foo:/foo:ro"
  [ "$status" -eq 0 ]

  run dokku letsencrypt:report "$APP" --letsencrypt-lego-docker-options
  [ "$status" -eq 0 ]
  [ "$output" = "-v /tmp/foo:/foo:ro" ]
}

@test "app-level dns-provider 'none' overrides a global dns-provider" {
  dokku letsencrypt:set --global dns-provider exec
  dokku letsencrypt:set "$APP" dns-provider none

  run dokku letsencrypt:report "$APP" --letsencrypt-computed-dns-provider
  [ "$status" -ne 0 ]

  run dokku letsencrypt:report "$APP" --letsencrypt-dns-provider
  [ "$status" -eq 0 ]
  [ "$output" = "none" ]

  run dokku letsencrypt:report "$APP" --letsencrypt-global-dns-provider
  [ "$status" -eq 0 ]
  [ "$output" = "exec" ]
}

@test "global dns-provider 'none' is treated as empty in computed value" {
  dokku letsencrypt:set --global dns-provider none

  run dokku letsencrypt:report "$APP" --letsencrypt-computed-dns-provider
  [ "$status" -ne 0 ]
}

@test "app-level dns-provider override still works for a real provider" {
  dokku letsencrypt:set --global dns-provider exec
  dokku letsencrypt:set "$APP" dns-provider route53

  run dokku letsencrypt:report "$APP" --letsencrypt-computed-dns-provider
  [ "$status" -eq 0 ]
  [ "$output" = "route53" ]
}

@test "letsencrypt:report shows expected fields when nothing is set" {
  run dokku letsencrypt:report "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Letsencrypt active"
  echo "$output" | grep -q "Letsencrypt computed email"
  echo "$output" | grep -q "Letsencrypt computed server"
  echo "$output" | grep -q "Letsencrypt computed graceperiod"
}
