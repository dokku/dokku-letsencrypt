DOKKU_VERSION ?= latest
LETEST_HOST_DIR ?= $(CURDIR)/tmp/letest-host

COMPOSE := DOKKU_VERSION=$(DOKKU_VERSION) LETEST_HOST_DIR=$(LETEST_HOST_DIR) docker compose -f tests/docker-compose.yml
COMPOSE_EXEC_DOKKU := $(COMPOSE) exec -T dokku

PLUGIN_BASH_FILES := command-functions commands config cron-entries cron-job help-functions install internal-functions \
	post-app-clone-setup post-app-rename-setup post-delete post-domains-update report uninstall \
	$(wildcard subcommands/*) \
	tests/setup.sh tests/test_helper.bash tests/lego/challtestsrv-dns.sh tests/pebble/init-cert.sh

.PHONY: setup build-lego build-stack wait-stack install-plugin test lint unit-tests clean logs

setup: build-lego build-stack wait-stack install-plugin

build-lego:
	docker build -t letest-lego:latest tests/lego

build-stack:
	mkdir -p $(LETEST_HOST_DIR)
	$(COMPOSE) build
	$(COMPOSE) up -d

wait-stack:
	$(COMPOSE) up -d --wait

install-plugin:
	$(COMPOSE_EXEC_DOKKU) bash /plugin-src/tests/setup.sh

lint:
	$(COMPOSE_EXEC_DOKKU) shellcheck $(addprefix /plugin-src/, $(PLUGIN_BASH_FILES))

unit-tests:
	$(COMPOSE_EXEC_DOKKU) bats /plugin-src/tests

test: lint unit-tests

logs:
	$(COMPOSE) logs --no-color --tail=200

clean:
	$(COMPOSE) down -v --remove-orphans
	rm -rf $(LETEST_HOST_DIR)
