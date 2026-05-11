ARG DOKKU_VERSION=latest
FROM dokku/dokku:${DOKKU_VERSION}

RUN apt-get update \
 && apt-get install -y --no-install-recommends bats curl jq shellcheck \
 && rm -rf /var/lib/apt/lists/*
