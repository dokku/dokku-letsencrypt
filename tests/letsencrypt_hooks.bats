#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  DOMAIN="${APP}.${TEST_DOMAIN_BASE}"
  RENAMED_APP=""
  CLONED_APP=""
  create_app "$APP"
  set_domain "$APP" "$DOMAIN"
  register_a_record "$DOMAIN"
}

teardown() {
  clear_a_record "$DOMAIN"
  cleanup_app "$APP"
  if [ -n "$RENAMED_APP" ]; then
    cleanup_app "$RENAMED_APP"
    clear_a_record "${RENAMED_APP}.${TEST_DOMAIN_BASE}"
  fi
  if [ -n "$CLONED_APP" ]; then
    cleanup_app "$CLONED_APP"
  fi
}

@test "post-app-rename clears the letsencrypt directory on the renamed app" {
  dokku letsencrypt:enable "$APP"
  [ -d "/home/dokku/${APP}/letsencrypt" ]

  RENAMED_APP="${APP}-renamed"
  register_a_record "${RENAMED_APP}.${TEST_DOMAIN_BASE}"
  dokku apps:rename "$APP" "$RENAMED_APP"

  [ ! -d "/home/dokku/${APP}/letsencrypt" ]
  [ ! -d "/home/dokku/${RENAMED_APP}/letsencrypt" ]
}

@test "post-app-clone clears the letsencrypt directory on the clone" {
  dokku letsencrypt:enable "$APP"
  [ -d "/home/dokku/${APP}/letsencrypt" ]

  CLONED_APP="${APP}-clone"
  dokku apps:clone --skip-deploy "$APP" "$CLONED_APP"

  [ ! -d "/home/dokku/${CLONED_APP}/letsencrypt" ]
}

@test "post-delete clears letsencrypt properties for a destroyed app" {
  dokku letsencrypt:set "$APP" graceperiod 4242

  run dokku letsencrypt:report "$APP" --letsencrypt-graceperiod
  [ "$output" = "4242" ]

  dokku --force apps:destroy "$APP"

  prop_dir="/var/lib/dokku/config/letsencrypt/${APP}"
  [ ! -d "$prop_dir" ]
}
