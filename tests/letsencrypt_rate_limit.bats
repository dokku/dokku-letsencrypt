#!/usr/bin/env bats

load 'test_helper'

# Unit tests for fn-letsencrypt-detect-rate-limit.
#
# The function is the seam the integration code uses to decide whether to
# surface the dedicated "Let's Encrypt rate-limited this request" warning
# after a failed lego run. Pebble does not simulate ACME rate-limit
# responses, so the integration test stack cannot exercise the real
# detection path end-to-end. Instead we extract the function from
# internal-functions and feed it canonical lego/ACME error fixtures.

INTERNAL_FUNCTIONS_PATH="/var/lib/dokku/plugins/enabled/letsencrypt/internal-functions"

setup() {
  if [ ! -f "$INTERNAL_FUNCTIONS_PATH" ]; then
    skip "letsencrypt plugin not installed at $INTERNAL_FUNCTIONS_PATH"
  fi

  LOG_FIXTURE="$(mktemp)"

  # Source only the detector function so we don't need the rest of the
  # plugin's runtime context (PLUGIN_CORE_AVAILABLE_PATH, etc.).
  # shellcheck source=/dev/null
  source <($SUDO awk '/^fn-letsencrypt-detect-rate-limit\(\)/,/^}/' "$INTERNAL_FUNCTIONS_PATH")
}

teardown() {
  rm -f "$LOG_FIXTURE"
}

@test "fn-letsencrypt-detect-rate-limit matches the rateLimited URN" {
  cat >"$LOG_FIXTURE" <<'EOF'
2025/05/12 12:00:00 [INFO] [example.com] acme: Obtaining bundled SAN certificate
acme: error: 429 :: POST :: https://acme-v02.api.letsencrypt.org/acme/new-order :: urn:ietf:params:acme:error:rateLimited :: Error creating new order
EOF

  run fn-letsencrypt-detect-rate-limit "$LOG_FIXTURE"
  [ "$status" -eq 0 ]
}

@test "fn-letsencrypt-detect-rate-limit matches '429 Too Many Requests'" {
  cat >"$LOG_FIXTURE" <<'EOF'
2025/05/12 12:00:00 [INFO] acme: Registering account
HTTP 429 Too Many Requests returned by the ACME server
EOF

  run fn-letsencrypt-detect-rate-limit "$LOG_FIXTURE"
  [ "$status" -eq 0 ]
}

@test "fn-letsencrypt-detect-rate-limit matches 'too many certificates already issued'" {
  cat >"$LOG_FIXTURE" <<'EOF'
too many certificates already issued for "example.com": see https://letsencrypt.org/docs/rate-limits/
EOF

  run fn-letsencrypt-detect-rate-limit "$LOG_FIXTURE"
  [ "$status" -eq 0 ]
}

@test "fn-letsencrypt-detect-rate-limit matches 'too many failed authorizations'" {
  cat >"$LOG_FIXTURE" <<'EOF'
acme: error: 429 :: too many failed authorizations recently
EOF

  run fn-letsencrypt-detect-rate-limit "$LOG_FIXTURE"
  [ "$status" -eq 0 ]
}

@test "fn-letsencrypt-detect-rate-limit ignores ordinary errors" {
  cat >"$LOG_FIXTURE" <<'EOF'
2025/05/12 12:00:00 [INFO] [example.com] acme: Trying to solve HTTP-01
2025/05/12 12:00:05 [ERROR] [example.com] acme: error presenting token: connection refused
EOF

  run fn-letsencrypt-detect-rate-limit "$LOG_FIXTURE"
  [ "$status" -ne 0 ]
}

@test "fn-letsencrypt-detect-rate-limit returns non-zero when the log path is missing" {
  run fn-letsencrypt-detect-rate-limit "/tmp/does-not-exist-$$"
  [ "$status" -ne 0 ]
}
