#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
  dokku letsencrypt:set --global graceperiod "" || true
  dokku letsencrypt:set --global dns-provider-OVH_APPLICATION_KEY "" || true
  dokku letsencrypt:set --global dns-provider-OVH_APPLICATION_SECRET "" || true
  dokku letsencrypt:set --global dns-provider-NAMECHEAP_API_KEY "" || true
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

@test "letsencrypt:report includes an app-level dns-provider-* key in stdout" {
  dokku letsencrypt:set "$APP" dns-provider-OVH_APPLICATION_KEY app-secret

  run dokku letsencrypt:report "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Letsencrypt dns provider OVH_APPLICATION_KEY"
  echo "$output" | grep -q "app-secret"
  ! echo "$output" | grep -q "Letsencrypt global dns provider OVH_APPLICATION_KEY"
}

@test "letsencrypt:report includes a global dns-provider-* key in stdout for an app" {
  dokku letsencrypt:set --global dns-provider-NAMECHEAP_API_KEY global-secret

  run dokku letsencrypt:report "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Letsencrypt global dns provider NAMECHEAP_API_KEY"
  echo "$output" | grep -q "Letsencrypt computed dns provider NAMECHEAP_API_KEY"
  echo "$output" | grep -q "global-secret"
  ! echo "$output" | grep -qE "^[[:space:]]+Letsencrypt dns provider NAMECHEAP_API_KEY"
}

@test "letsencrypt:report --format json exposes dns-provider-* keys" {
  dokku letsencrypt:set "$APP" dns-provider-OVH_APPLICATION_KEY app-secret

  run dokku letsencrypt:report "$APP" --format json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null

  value="$(echo "$output" | jq -r '."dns-provider-OVH_APPLICATION_KEY"')"
  [ "$value" = "app-secret" ]

  computed="$(echo "$output" | jq -r '."computed-dns-provider-OVH_APPLICATION_KEY"')"
  [ "$computed" = "app-secret" ]

  has_global="$(echo "$output" | jq -r 'has("global-dns-provider-OVH_APPLICATION_KEY")')"
  [ "$has_global" = "false" ]
}

@test "letsencrypt:report info flag returns a dns-provider-* value" {
  dokku letsencrypt:set "$APP" dns-provider-OVH_APPLICATION_KEY app-secret

  run dokku letsencrypt:report "$APP" --letsencrypt-dns-provider-OVH_APPLICATION_KEY
  [ "$status" -eq 0 ]
  [ "$output" = "app-secret" ]
}

@test "letsencrypt:report computed dns-provider-* takes app value over global" {
  dokku letsencrypt:set --global dns-provider-OVH_APPLICATION_KEY global-secret
  dokku letsencrypt:set "$APP" dns-provider-OVH_APPLICATION_KEY app-secret

  run dokku letsencrypt:report "$APP" --letsencrypt-computed-dns-provider-OVH_APPLICATION_KEY
  [ "$status" -eq 0 ]
  [ "$output" = "app-secret" ]

  run dokku letsencrypt:report "$APP" --letsencrypt-global-dns-provider-OVH_APPLICATION_KEY
  [ "$status" -eq 0 ]
  [ "$output" = "global-secret" ]
}

@test "letsencrypt:report --global includes global dns-provider-* keys" {
  dokku letsencrypt:set --global dns-provider-NAMECHEAP_API_KEY global-secret

  run dokku letsencrypt:report --global
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Letsencrypt global dns provider NAMECHEAP_API_KEY"
  echo "$output" | grep -q "global-secret"
}

@test "letsencrypt:report --global --format json includes global-dns-provider-* and excludes non-global" {
  dokku letsencrypt:set --global dns-provider-NAMECHEAP_API_KEY global-secret

  run dokku letsencrypt:report --global --format json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null

  value="$(echo "$output" | jq -r '."global-dns-provider-NAMECHEAP_API_KEY"')"
  [ "$value" = "global-secret" ]

  non_global="$(echo "$output" | jq -r 'keys[]' | grep -v '^global-' || true)"
  [ -z "$non_global" ]
}

@test "dokku report redacts dns-provider-* credential values to ****" {
  dokku letsencrypt:set "$APP" email "report@dokku.test"
  dokku letsencrypt:set "$APP" dns-provider-OVH_APPLICATION_KEY app-secret

  run dokku report "$APP"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Letsencrypt dns provider OVH_APPLICATION_KEY"
  echo "$output" | grep -q '\*\*\*\*'
  ! echo "$output" | grep -q "app-secret"
  echo "$output" | grep -q "report@dokku.test"
}

@test "dokku letsencrypt:report keeps dns-provider-* values raw after a dokku report run" {
  dokku letsencrypt:set "$APP" dns-provider-OVH_APPLICATION_KEY app-secret

  run dokku report "$APP"
  [ "$status" -eq 0 ]

  run dokku letsencrypt:report "$APP" --letsencrypt-dns-provider-OVH_APPLICATION_KEY
  [ "$status" -eq 0 ]
  [ "$output" = "app-secret" ]
}

@test "dokku report leaves non-dns-provider-* fields unredacted" {
  dokku letsencrypt:set "$APP" email "report@dokku.test"
  dokku letsencrypt:set "$APP" dns-provider exec
  dokku letsencrypt:set "$APP" dns-provider-OVH_APPLICATION_KEY app-secret

  run dokku report "$APP"
  [ "$status" -eq 0 ]
  letsencrypt_section="$(echo "$output" | awk '/letsencrypt information/{flag=1} flag')"
  echo "$letsencrypt_section" | grep -q "report@dokku.test"
  echo "$letsencrypt_section" | grep -qE "Letsencrypt dns provider:[[:space:]]+exec"
  echo "$letsencrypt_section" | grep -qE "Letsencrypt computed dns provider:[[:space:]]+exec"
  echo "$letsencrypt_section" | grep -q "Letsencrypt dns provider OVH_APPLICATION_KEY"
  echo "$letsencrypt_section" | grep -q '\*\*\*\*'
  ! echo "$letsencrypt_section" | grep -q "app-secret"
}
