# Test suite

The bats suite exercises the plugin end-to-end inside a docker-compose stack: a derived dokku image, [pebble](https://github.com/letsencrypt/pebble) as the ACME server, and [pebble-challtestsrv](https://github.com/letsencrypt/pebble/tree/main/cmd/pebble-challtestsrv) as a controllable DNS authority. Tests run inside the dokku container so they call `dokku ...` directly. Linux only - pebble and challtestsrv use `network_mode: host` so the lego container (launched by the plugin on docker's default bridge) can reach them via `172.17.0.1`.

## Running the suite locally

From the repo root:

```shell
make test
```

That runs `setup` (build the lego image, bring up the stack, install the plugin) then `lint` and `unit-tests`. Stack containers stay up between runs so subsequent invocations are fast. Use `make clean` to tear everything down and remove the host-side state directory at `tmp/letest-host`.

Useful targets:

| Target | What it does |
|--------|--------------|
| `make setup` | Build the test lego image, bring up the compose stack, install the plugin into the dokku container. |
| `make lint` | Run shellcheck against the plugin's bash files. |
| `make unit-tests` | Run the bats suite. |
| `make test` | `lint` then `unit-tests`. |
| `make logs` | Tail the last 200 lines of compose logs across all services. |
| `make clean` | `docker compose down -v` and remove `tmp/letest-host`. |

## Scoping a run to a single test

Pass `UNIT_TESTS=` to limit to one bats file:

```shell
make unit-tests UNIT_TESTS=letsencrypt_enable_http01.bats
```

Pass `UNIT_TESTS_FILTER=` (a regex matched against test names) to scope further:

```shell
make unit-tests UNIT_TESTS=letsencrypt_enable_http01.bats UNIT_TESTS_FILTER='HTTP-01'
```

`UNIT_TESTS_FILTER` works without `UNIT_TESTS` too - it'll filter across the whole suite.

## Picking a different dokku version

```shell
make test DOKKU_VERSION=0.36.5
```

Defaults to `latest`. Tear the stack down (`make clean`) before switching versions so the dokku container is rebuilt against the new tag.

## What gets printed

`make unit-tests` runs bats with `--timing` and `--print-output-on-failure`, so each line includes the per-test duration and any failing test dumps the captured `$output` automatically. No extra flags needed.

## Native mode

The same suite can also run against a Dokku installed directly on the host - the same path the plugin actually ships through. CI runs both modes in parallel; locally it's an opt-in path because `bootstrap.sh` is destructive (it installs Dokku, configures nginx, and creates a `dokku` system user). **Linux only**, and not safe to run on a workstation you care about - use a throwaway VM or a fresh container.

```shell
make setup-native
make unit-tests-native
make clean-native
```

| Target | What it does |
|--------|--------------|
| `make setup-native` | Build the lego image, bring up the Pebble compose services (no dokku container), bootstrap dokku via the upstream `bootstrap.sh`, install the plugin natively. |
| `make unit-tests-native` | Run the bats suite directly on the host against the native dokku install. Same `UNIT_TESTS` / `UNIT_TESTS_FILTER` knobs as `unit-tests`. |
| `make clean-native` | `docker compose down -v` for the Pebble services. The native dokku install itself is left in place. |

`setup-native` honors `DOKKU_TAG` to install a specific Dokku release instead of master.
