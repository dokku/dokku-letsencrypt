#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP1="$(new_app_name)-a"
  APP2="$(new_app_name)-b"
  DOMAIN1="${APP1}.${TEST_DOMAIN_BASE}"
  DOMAIN2="${APP2}.${TEST_DOMAIN_BASE}"
  create_app "$APP1"
  create_app "$APP2"
  set_domain "$APP1" "$DOMAIN1"
  set_domain "$APP2" "$DOMAIN2"
  register_a_record "$DOMAIN1"
  register_a_record "$DOMAIN2"
  SERVER="$(dokku letsencrypt:report "$APP1" --letsencrypt-computed-server)"
  EMAIL="$(dokku letsencrypt:report "$APP1" --letsencrypt-computed-email)"
  ACCOUNT_DIR="$(shared_account_dir_for "$SERVER" "$EMAIL")"
}

teardown() {
  clear_a_record "$DOMAIN1"
  clear_a_record "$DOMAIN2"
  cleanup_app "$APP1"
  cleanup_app "$APP2"
}

@test "two apps share a single ACME account via the shared accounts dir" {
  run dokku letsencrypt:enable "$APP1"
  [ "$status" -eq 0 ]

  $SUDO test -f "$ACCOUNT_DIR/account.json" || {
    echo "expected account.json at $ACCOUNT_DIR" >&2
    $SUDO ls -laR "$(shared_accounts_dir)" >&2 || true
    return 1
  }
  $SUDO test -d "$ACCOUNT_DIR/keys"

  # capture the bytes of account.json and the entire keys/ tree
  account_before="$($SUDO cat "$ACCOUNT_DIR/account.json")"
  keys_before="$($SUDO tar -cf - -C "$ACCOUNT_DIR" keys | sha256sum | awk '{print $1}')"

  run dokku letsencrypt:enable "$APP2"
  [ "$status" -eq 0 ]

  account_after="$($SUDO cat "$ACCOUNT_DIR/account.json")"
  keys_after="$($SUDO tar -cf - -C "$ACCOUNT_DIR" keys | sha256sum | awk '{print $1}')"

  # second enable must reuse the same account material, not register again
  [ "$account_before" = "$account_after" ]
  [ "$keys_before" = "$keys_after" ]

  # exactly one email directory under the server segment
  server_seg="$(shared_account_server_segment "$SERVER")"
  count="$($SUDO find "$(shared_accounts_dir)/${server_seg}" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  [ "$count" = "1" ]
}

@test "shared accounts directory is created with 0700 mode" {
  dokku letsencrypt:enable "$APP1"

  mode="$($SUDO stat -c '%a' "$(shared_accounts_dir)" 2>/dev/null || $SUDO stat -f '%Lp' "$(shared_accounts_dir)")"
  [ "$mode" = "700" ]
}
