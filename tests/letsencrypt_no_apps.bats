#!/usr/bin/env bats

load 'test_helper'

# A host that has not deployed anything yet is the state a provisioning tool
# sees right after `letsencrypt:set --global`, and the state the auto-renew
# cron job runs against every day. Neither should treat it as an error.

setup() {
  destroy_all_apps
}

teardown() {
  dokku letsencrypt:set --global graceperiod "" || true
}

@test "letsencrypt:report --global renders a report when the host has no apps" {
  run dokku letsencrypt:report --global
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "global letsencrypt information"
  echo "$output" | grep -q "Letsencrypt global email"
}

@test "letsencrypt:report --global --format json returns global keys when the host has no apps" {
  dokku letsencrypt:set --global graceperiod 22222

  run dokku letsencrypt:report --global --format json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  value="$(echo "$output" | jq -r '."global-graceperiod"')"
  [ "$value" = "22222" ]
}

@test "letsencrypt:report --global info flag returns a value when the host has no apps" {
  dokku letsencrypt:set --global graceperiod 33333

  run dokku letsencrypt:report --global --letsencrypt-global-graceperiod
  [ "$status" -eq 0 ]
  [ "$output" = "33333" ]
}

@test "letsencrypt:report without an app warns instead of failing when the host has no apps" {
  run dokku letsencrypt:report
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "You haven't deployed any applications yet"
}

@test "letsencrypt:report --format json emits nothing on stdout when the host has no apps" {
  run /bin/bash -c "dokku letsencrypt:report --format json 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "letsencrypt:auto-renew stays quiet about missing apps when the host has no apps" {
  run dokku letsencrypt:auto-renew
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Finished auto-renewal"
  ! echo "$output" | grep -q "You haven't deployed any applications yet"
}

@test "letsencrypt:list still reports that the host has no apps" {
  run dokku letsencrypt:list
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "You haven't deployed any applications yet"
}
