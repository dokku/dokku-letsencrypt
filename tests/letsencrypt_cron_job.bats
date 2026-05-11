#!/usr/bin/env bats

load 'test_helper'

AUTORENEW_FLAG="/var/lib/dokku/data/letsencrypt/autorenew"

teardown() {
  dokku letsencrypt:cron-job --remove >/dev/null 2>&1 || true
}

@test "cron-job --add creates the autorenew flag" {
  $SUDO rm -f "$AUTORENEW_FLAG"

  run dokku letsencrypt:cron-job --add
  [ "$status" -eq 0 ]
  $SUDO test -f "$AUTORENEW_FLAG"
}

@test "cron-job --remove deletes the autorenew flag" {
  dokku letsencrypt:cron-job --add
  $SUDO test -f "$AUTORENEW_FLAG"

  run dokku letsencrypt:cron-job --remove
  [ "$status" -eq 0 ]
  $SUDO test ! -f "$AUTORENEW_FLAG"
}

@test "cron-entries trigger emits an entry only when autorenew is enabled" {
  dokku letsencrypt:cron-job --remove >/dev/null 2>&1 || true
  run $SUDO dokku plugin:trigger cron-entries
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q "letsencrypt:auto-renew"

  dokku letsencrypt:cron-job --add
  run $SUDO dokku plugin:trigger cron-entries
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "letsencrypt:auto-renew"
}
