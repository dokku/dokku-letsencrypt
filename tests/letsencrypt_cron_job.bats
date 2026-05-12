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

@test "cron-job without flags reports disabled when autorenew flag is absent" {
  dokku letsencrypt:cron-job --remove >/dev/null 2>&1 || true

  run dokku letsencrypt:cron-job
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Auto-renew cron job is not enabled"
  echo "$output" | grep -q -- "--add"
}

@test "cron-job without flags reports enabled when autorenew flag is present" {
  dokku letsencrypt:cron-job --add

  run dokku letsencrypt:cron-job
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Auto-renew cron job is enabled"
  ! echo "$output" | grep -q "not enabled"
  echo "$output" | grep -q -- "--remove"
}

@test "cron-job rejects an unknown flag" {
  run dokku letsencrypt:cron-job --bogus
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "Invalid flag"
}
