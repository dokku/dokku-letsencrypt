#!/usr/bin/env bats

load 'test_helper'

@test "plugin:update heals pre-existing per-app webroots with restrictive mode" {
  local bad_app parent webroot
  bad_app="letest-perm-$(date +%s)-${RANDOM}"
  parent="/var/lib/dokku/data/letsencrypt"
  webroot="${parent}/${bad_app}"

  $SUDO mkdir -p "$webroot"
  $SUDO chmod 0700 "$webroot"
  $SUDO chmod 0700 "$parent"

  run $SUDO dokku plugin:update letsencrypt
  [ "$status" -eq 0 ]

  [ "$($SUDO stat -c '%a' "$parent")" = "755" ]
  [ "$($SUDO stat -c '%a' "$webroot")" = "755" ]
  [ "$($SUDO stat -c '%a' "${parent}/accounts")" = "700" ]

  $SUDO rm -rf "$webroot"
}
