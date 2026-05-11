DOKKU_VERSION ?= latest
LETEST_HOST_DIR ?= $(CURDIR)/tmp/letest-host

# Optional path or filename relative to /plugin-src/tests passed to bats, e.g.
# `make unit-tests UNIT_TESTS=letsencrypt_enable_http01.bats`. Defaults to the
# whole tests directory.
UNIT_TESTS ?= .
# Optional regex passed to bats --filter to scope down to a single test name.
UNIT_TESTS_FILTER ?=
BATS_FLAGS := --timing --print-output-on-failure
ifneq ($(UNIT_TESTS_FILTER),)
BATS_FLAGS += --filter '$(UNIT_TESTS_FILTER)'
endif

COMPOSE := DOKKU_VERSION=$(DOKKU_VERSION) LETEST_HOST_DIR=$(LETEST_HOST_DIR) docker compose -f tests/docker-compose.yml
COMPOSE_COMPOSE_MODE := $(COMPOSE) --profile compose-mode
COMPOSE_EXEC_DOKKU := $(COMPOSE) exec -T dokku

PLUGIN_BASH_FILES := command-functions commands config cron-entries cron-job help-functions install internal-functions \
	post-app-clone-setup post-app-rename-setup post-delete post-domains-update report uninstall \
	$(wildcard subcommands/*) \
	tests/setup.sh tests/setup-native.sh tests/test_helper.bash tests/lego/challtestsrv-dns.sh tests/pebble/init-cert.sh

.PHONY: setup build-lego build-stack wait-stack install-plugin test lint unit-tests clean logs \
	setup-native bring-up-services install-plugin-native unit-tests-native clean-native

setup: build-lego build-stack wait-stack install-plugin

build-lego:
	docker build -t letest-lego:latest tests/lego

build-stack:
	mkdir -p $(LETEST_HOST_DIR)
	$(COMPOSE_COMPOSE_MODE) build
	$(COMPOSE_COMPOSE_MODE) up -d

wait-stack:
	$(COMPOSE_COMPOSE_MODE) up -d --wait

install-plugin:
	$(COMPOSE_EXEC_DOKKU) bash /plugin-src/tests/setup.sh

lint:
	$(COMPOSE_EXEC_DOKKU) shellcheck $(addprefix /plugin-src/, $(PLUGIN_BASH_FILES))

unit-tests:
	$(COMPOSE_EXEC_DOKKU) bats $(BATS_FLAGS) /plugin-src/tests/$(UNIT_TESTS)

test: lint unit-tests

logs:
	$(COMPOSE) logs --no-color --tail=200

clean:
	$(COMPOSE_COMPOSE_MODE) down -v --remove-orphans
	# The host-side state dir contains files owned by root inside the
	# dokku container, which the host user cannot rm without elevation.
	rm -rf $(LETEST_HOST_DIR) 2>/dev/null || sudo rm -rf $(LETEST_HOST_DIR)

# --- Native mode: dokku installed on the host, supporting services in compose ---

setup-native: build-lego bring-up-services install-plugin-native

bring-up-services:
	$(COMPOSE) up -d --wait

install-plugin-native:
	bash tests/setup-native.sh

unit-tests-native:
	SUDO=sudo bats $(BATS_FLAGS) tests/$(UNIT_TESTS)

clean-native:
	$(COMPOSE_COMPOSE_MODE) down -v --remove-orphans
