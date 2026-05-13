# dokku-letsencrypt

Official dokku plugin that retrieves and installs free TLS certificates from [Let's Encrypt](https://letsencrypt.org). The app stays online throughout ACME validation, and certificates are renewed automatically once a cron job is enabled.

> Running this plugin counts as accepting the Let's Encrypt Subscriber Agreement on your behalf. The plugin passes `--accept-tos` to `lego` so that unattended cron-based renewal does not block on a prompt.

## Installation

```shell
sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
sudo dokku letsencrypt:cron-job --add
```

The first command installs the plugin and pulls the `dokku/letsencrypt` Docker image used to run the [lego](https://github.com/go-acme/lego) ACME client. The second command schedules daily auto-renewals, so existing certificates renew themselves before they expire.

To upgrade later, run `sudo dokku plugin:update letsencrypt`. The update step also migrates legacy `DOKKU_LETSENCRYPT_*` environment variables (`_EMAIL`, `_GRACEPERIOD`, `_ARGS`, `_SERVER`) and the older `lego-docker-args` property to their current property names, so no manual reconfiguration is needed.

You can influence what the install and update commands do via the following host-level environment variables:

| Variable | Default | Description |
|---|---|---|
| `LETSENCRYPT_IMAGE` | `dokku/letsencrypt` | Docker image used for the lego container. Override this if you maintain a fork or a mirror. |
| `LETSENCRYPT_IMAGE_VERSION` | image tag from this repo's `Dockerfile` | Tag of the lego image to pull and run. |
| `LETSENCRYPT_DISABLE_PULL` | (unset) | Set to `true` to skip `docker pull` during install and update. Useful on air-gapped hosts where the image is already loaded. |

## Usage

Help for any command can be displayed by running `dokku letsencrypt:help`. Plugin help output together with this README is used to generate the public documentation; the per-command subsections below cover each command in depth.

### Commands

```
letsencrypt:active <app>                                       Verify if letsencrypt is active for an app
letsencrypt:auto-renew [<app>]                                 Auto-renew app if renewal is necessary
letsencrypt:cleanup <app>                                      Remove stale certificate directories for app
letsencrypt:cron-job [--add|--remove]                          Add, remove, or display the status of the auto-renewal cron job.
letsencrypt:disable <app>                                      Disable letsencrypt for an app
letsencrypt:enable <app> [--force]                             Enable or renew letsencrypt for an app (skipped when a valid certificate already exists unless --force is set)
letsencrypt:help                                               Display letsencrypt help
letsencrypt:list                                               List letsencrypt-secured apps with certificate expiry times
letsencrypt:report [<app>|--global] [<flag>] [--format json]   Display a letsencrypt report for one or more apps
letsencrypt:revoke <app>                                       Revoke letsencrypt certificate for app
letsencrypt:set <app> <property> (<value>)                     Set or clear a letsencrypt property for an app
```

### Basic usage

The app needs to already be deployed and reachable on the public internet over HTTP before a certificate can be issued. Let's Encrypt fetches a challenge file from your app's domain to prove you control it, so an app that has only been created (no successful deploy yet) cannot be enabled.

Set an email address, then enable the plugin for the app:

```shell
dokku letsencrypt:set myapp email your@email.tld
dokku letsencrypt:enable myapp
```

A successful run looks like this:

```
=====> Let's Encrypt myapp...
-----> Enabling letsencrypt proxy for myapp...
-----> Getting letsencrypt certificate for myapp via HTTP-01
        - Domain 'myapp.mydomain.com'

[ removed various log messages for brevity ]

-----> Certificate retrieved successfully.
-----> Installing let's encrypt certificates
-----> Configuring SSL for myapp.mydomain.com...(using /var/lib/dokku/plugins/available/nginx-vhosts/templates/nginx.ssl.conf.template)
-----> Disabling letsencrypt proxy for myapp...
       Done
```

Once the certificate is installed, the regular `dokku certs:*` commands can read, replace, or remove it. Setting an email once at the `--global` scope spares you from repeating it for every app:

```shell
dokku letsencrypt:set --global email your@email.tld
```

When you add or change an app's domains afterwards, the plugin logs a warning reminding you to run `letsencrypt:enable` again so the certificate covers the new SAN list.

### Verify if letsencrypt is active for an app

```shell
# usage
dokku letsencrypt:active <app>
```

Prints `true` if the certificate currently installed on the app was issued by this plugin, `false` otherwise. Useful in scripts that need to decide whether to call `letsencrypt:enable`.

```shell
dokku letsencrypt:active myapp
```

### Enable letsencrypt for an app

```shell
# usage
dokku letsencrypt:enable <app> [--force]
dokku letsencrypt:enable --all [--force]
```

flags:

- `--force` / `-f`: request a new certificate even if the existing one is still valid. See [Idempotent enable](#idempotent-enable) for what triggers a real ACME call by default.
- `--all`: run the enable flow against every app on the host. Useful after a bulk configuration change such as updating the global `email` or `server`.

Issues a certificate via the configured challenge type (HTTP-01 by default, DNS-01 when `dns-provider` is set), installs it on the app, and reloads nginx. The command is safe to call on every deploy; it only contacts the ACME server when something has actually changed.

Enable a single app:

```shell
dokku letsencrypt:enable myapp
```

Force a fresh certificate request for a single app:

```shell
dokku letsencrypt:enable myapp --force
```

Enable every app on the host:

```shell
dokku letsencrypt:enable --all
```

### Auto-renew certificates if necessary

```shell
# usage
dokku letsencrypt:auto-renew [<app>]
```

Renews any certificate whose remaining lifetime has dropped below the configured `graceperiod`. With no app argument the plugin scans every app on the host, sorted by ascending time-to-renewal so the most urgent renewals run first (this matters when an ACME rate limit is in play). With an app argument it only renews that one app.

The auto-renewal cron job invokes this command, but you can also run it manually:

```shell
dokku letsencrypt:auto-renew
dokku letsencrypt:auto-renew myapp
```

### Manage the auto-renewal cron job

```shell
# usage
dokku letsencrypt:cron-job [--add|--remove]
```

flags:

- `--add`: install the auto-renew cron entry.
- `--remove`: remove the auto-renew cron entry.
- no flag: print whether the cron job is currently installed.

Renewal can only happen if something runs `letsencrypt:auto-renew` on a schedule. This command writes (or removes) that cron entry on your behalf. When the dokku `cron` plugin is installed, the entry is `24 6 * * *` (daily at 06:24) and its output is appended to `/var/log/dokku/letsencrypt.log`. Otherwise the plugin falls back to writing `@daily` directly to the dokku user's crontab.

```shell
dokku letsencrypt:cron-job --add
dokku letsencrypt:cron-job
dokku letsencrypt:cron-job --remove
```

### Disable letsencrypt for an app

```shell
# usage
dokku letsencrypt:disable <app>
```

Removes the certificate and the plugin's per-app state from `$DOKKU_ROOT/<app>/letsencrypt` and `$DOKKU_ROOT/<app>/tls`, then triggers nginx to drop the HTTPS configuration. The app stays running on plain HTTP. Run this when you want to take an app off Let's Encrypt without revoking the certificate at the ACME server.

```shell
dokku letsencrypt:disable myapp
```

### Remove stale certificate directories

```shell
# usage
dokku letsencrypt:cleanup <app>
```

Every certificate request lands in a hash-keyed directory under `$DOKKU_ROOT/<app>/letsencrypt/certs/`, and `current` symlinks to the active one. Old hash directories accumulate when the lego config changes (new domain, different `lego-args`, etc.). `letsencrypt:cleanup` removes everything except the currently-active hash directory.

```shell
dokku letsencrypt:cleanup myapp
```

### List letsencrypt-secured apps

```shell
# usage
dokku letsencrypt:list
```

Prints a table of every app with a Let's Encrypt certificate installed: expiry timestamp, time remaining on the certificate, and time remaining before auto-renewal kicks in. The list is sorted by expiry date so the most urgent entries appear first.

```shell
dokku letsencrypt:list
```

### Display a letsencrypt report

```shell
# usage
dokku letsencrypt:report [<app>|--global] [<flag>] [--format json]
```

flags:

- `--global`: report only global properties.
- `--format json`: emit a JSON object instead of the default stdout layout. Cannot be combined with an info flag.
- `--letsencrypt-<property>` (such as `--letsencrypt-email` or `--letsencrypt-computed-server`): print the value for that single property.

Exposes the plugin's configuration and state for tooling and diagnostics. With no arguments it prints a report for every app; with an app name it scopes to that one app; with `--global` it shows only the global values. See [Reports](#reports) for the redaction behavior in the top-level `dokku report` command.

```shell
dokku letsencrypt:report
dokku letsencrypt:report myapp
dokku letsencrypt:report --global
dokku letsencrypt:report myapp --format json
dokku letsencrypt:report myapp --letsencrypt-email
```

### Revoke letsencrypt certificate for app

```shell
# usage
dokku letsencrypt:revoke <app>
```

Tells the ACME server to revoke the certificate currently installed on the app. The local files remain in place so the next `letsencrypt:enable` can reuse them or replace them. Use this when a private key has leaked or you no longer want the certificate to be considered valid by browsers.

```shell
dokku letsencrypt:revoke myapp
```

### Set or clear a letsencrypt property

```shell
# usage
dokku letsencrypt:set <app>|--global <property> [<value>]
```

Sets the property to the given value, or clears it when no value is provided. The first argument can be an app name (sets the property for that app) or `--global` (sets the default for every app). When the plugin needs a property's value it first checks the app, then falls back to the global setting.

Valid properties are `dns-provider`, `email`, `graceperiod`, `server`, `lego-args`, `lego-docker-options`, and any `dns-provider-*` key (used for DNS-01 credentials, see [DNS-01 challenge](#dns-01-challenge)).

Set a per-app value:

```shell
dokku letsencrypt:set myapp email myapp-admin@example.com
```

Set a global default:

```shell
dokku letsencrypt:set --global email admin@example.com
```

Clear an app-level value (falls back to the global value, if any):

```shell
dokku letsencrypt:set myapp email
```

## Configuration

All non-secret configuration is stored via `letsencrypt:set`. App-level values take precedence over global values, so it is common to set safe defaults at `--global` and only override per app when needed.

| Property | Default | Description |
|---|---|---|
| `dns-provider` | (none) | Name of a [valid lego DNS provider](https://go-acme.github.io/lego/dns/). Setting this switches the app from HTTP-01 to DNS-01, which is what enables wildcard certificates. |
| `email` | (none) | **Required.** Address used to register the ACME account. Let's Encrypt sends expiry reminders here. |
| `graceperiod` | `2592000` (30 days) | Seconds remaining on a certificate before auto-renew tries to replace it. The Let's Encrypt certificate lifetime is 90 days, so 30 days of grace is the common default. |
| `lego-args` | (none) | Extra arguments appended to the `lego` CLI invocation. See the [lego CLI docs](https://go-acme.github.io/lego/usage/cli/). |
| `lego-docker-options` | (none) | Extra flags appended to `docker run` when starting the lego container. Use this for volume mounts, env files, or custom networks. This is distinct from `lego-args`, which goes to the `lego` binary itself. |
| `server` | `default` | ACME directory URL. `default` resolves to `https://acme-v02.api.letsencrypt.org/directory`. `staging` resolves to `https://acme-staging-v02.api.letsencrypt.org/directory`. Any other value is used as a literal URL. |

Set a single property:

```shell
dokku letsencrypt:set myapp email myapp-admin@example.com
dokku letsencrypt:set --global graceperiod 1209600
```

`dns-provider-*` properties (DNS-01 credentials) live in the same property store and follow the same precedence rule. They are covered in [DNS-01 challenge](#dns-01-challenge).

## Automatic renewal

Let's Encrypt certificates expire after 90 days, so any production app needs unattended renewal. The plugin's renewal mechanism is a cron job that runs `letsencrypt:auto-renew`, which iterates over every Let's Encrypt-secured app and re-issues certificates whose remaining lifetime has dropped below `graceperiod` (default: 30 days).

Install the cron job once during initial setup:

```shell
dokku letsencrypt:cron-job --add
```

When the dokku `cron` plugin is installed, the entry is `24 6 * * *` (daily at 06:24) and its output is appended to `/var/log/dokku/letsencrypt.log`. Otherwise the plugin falls back to writing `@daily` to the dokku user's crontab. Running `letsencrypt:cron-job` without a flag reports whether the entry is installed.

## Idempotent enable

`letsencrypt:enable <app>` is safe to call on every deploy. It only contacts the ACME server when one of the following is true:

- the app does not currently have a Let's Encrypt certificate installed,
- the app's domains, email, server, `lego-args`, `lego-docker-options`, or `dns-provider` have changed since the certificate was issued,
- the certificate is within its renewal grace period (see `graceperiod`).

In every other case the command exits successfully without touching nginx, the lego container, or the ACME server. This is what makes the command safe to wire into CI-driven review-app deploys without burning through Let's Encrypt's rate limits.

To force a new certificate request even when the existing certificate is still valid, pass `--force`:

```shell
dokku letsencrypt:enable myapp --force
```

This is useful when copying certificates between servers (the new host has no ACME-account record of the existing cert) or when manually rotating a certificate.

## Reports

`letsencrypt:report` exposes per-app and global plugin properties for tooling and diagnostics. Without arguments it prints a human-readable report for every app, with an app name it reports on that app, and with `--global` it limits output to global properties.

```shell
dokku letsencrypt:report
dokku letsencrypt:report myapp
dokku letsencrypt:report --global
```

Pass `--format json` to emit a JSON object instead of the default stdout layout. The flag works with app, global, and "all apps" invocations:

```shell
dokku letsencrypt:report myapp --format json
dokku letsencrypt:report --global --format json
```

Specifying a single property flag (such as `--letsencrypt-email`) prints just that value. Combining `--format json` with a single property flag is rejected.

```shell
dokku letsencrypt:report myapp --letsencrypt-email
```

Any `dns-provider-*` properties set globally or for the app appear in the report alongside the fixed fields. For each set property, the report emits the scopes that actually have a value: a `--letsencrypt-dns-provider-<KEY>` row when set on the app, a `--letsencrypt-global-dns-provider-<KEY>` row when set globally, and a `--letsencrypt-computed-dns-provider-<KEY>` row that resolves to the app value (falling back to the global value).

The top-level `dokku report <app>` command aggregates output from every plugin and is commonly used in support contexts. When the letsencrypt section is rendered through that aggregate command, every `dns-provider-*` credential value is redacted to `****` to avoid leaking API keys or token paths into shared output. The provider name and every other property remain unredacted. `dokku letsencrypt:report` is unaffected and continues to show raw values, so operators can verify what they have configured.

## Challenge types

ACME (the Let's Encrypt protocol) supports two challenge types, and this plugin can use either of them:

- **HTTP-01** is the default. Let's Encrypt fetches `http://<your-domain>/.well-known/acme-challenge/<token>` and expects to see a specific response. This requires your app to be reachable on port 80 from the public internet, but needs no special DNS access.
- **DNS-01** proves control of a domain by writing a TXT record at `_acme-challenge.<your-domain>`. The plugin invokes a [lego DNS provider](https://go-acme.github.io/lego/dns/) (Cloudflare, Route53, Namecheap, etc.) to create and remove that record. DNS-01 is the only way to obtain wildcard certificates (`*.example.com`) and is useful when port 80 is firewalled.

Pick HTTP-01 unless you need wildcard certificates or your app cannot accept inbound connections on port 80. To use DNS-01, see [DNS-01 challenge](#dns-01-challenge).

## DNS-01 challenge

> DNS-01 support is sponsored by [Orca Scan Ltd](https://orcascan.com/).

To enable DNS-01, set `dns-provider` to a supported lego provider, then set the per-provider environment variables that lego reads. Provider-specific env vars are stored as letsencrypt properties prefixed with `dns-provider-`, scoped either globally or per app. Before you run `letsencrypt:enable`, make sure every domain you plan to cover (including any wildcard records) actually resolves to your server.

```shell
dokku letsencrypt:set --global dns-provider namecheap
dokku letsencrypt:set --global dns-provider-NAMECHEAP_API_USER user
dokku letsencrypt:set --global dns-provider-NAMECHEAP_API_KEY key
```

If a DNS provider supports `_FILE`-suffixed environment variables for reading secrets from files, mount the secret file into the lego container with `lego-docker-options` and set the corresponding `dns-provider-*_FILE` property to the in-container path:

```shell
dokku letsencrypt:set --global lego-docker-options "-v /etc/dokku-letsencrypt/cloudflare-token:/secrets/cf-token:ro"
dokku letsencrypt:set --global dns-provider-CLOUDFLARE_DNS_API_TOKEN_FILE /secrets/cf-token
```

### Using the exec DNS provider

The lego [`exec` DNS provider](https://go-acme.github.io/lego/dns/exec/) shells out to a user-supplied script for creating and removing TXT records. The script must be reachable from inside the lego container at the path stored in `EXEC_PATH`. Use `lego-docker-options` to mount it from the host:

```shell
sudo install -m 0755 /path/on/host/dns.sh /var/lib/dokku/data/letsencrypt/exec-dns.sh

dokku letsencrypt:set --global dns-provider exec
dokku letsencrypt:set --global lego-docker-options "-v /var/lib/dokku/data/letsencrypt/exec-dns.sh:/scripts/dns.sh:ro"
dokku letsencrypt:set --global dns-provider-EXEC_PATH /scripts/dns.sh
```

Consult the lego documentation for your specific DNS provider for the full set of credentials it needs.

### Disabling DNS-01 for a single app

When a global `dns-provider` is set but a particular app's domain is not managed by that provider, set the app's `dns-provider` to `none` to force HTTP-01 for that app only:

```shell
dokku letsencrypt:set myapp dns-provider none
```

Setting the property to an empty string (`dokku letsencrypt:set myapp dns-provider ""`) deletes the app-level value and falls back to the global setting; `none` is the explicit opt-out. The `none` sentinel is also accepted at `--global` scope, where it behaves identically to leaving the property unset.

## Generating a cert for multiple domains

Your [default dokku app](https://dokku.com/docs/networking/proxies/nginx/?h=default+site#default-site) is also served at the root domain. If your app `00-default` runs at `00-default.mydomain.com`, it is reachable at `mydomain.com` too. Once you enable letsencrypt for the app, the bare-root URL stops working unless that domain is on the certificate. Add it to the app's domains first:

```shell
dokku domains:add 00-default mydomain.com
dokku letsencrypt:enable 00-default
```

The same pattern applies whenever you add or change domains on a Let's Encrypt-secured app: domain changes invalidate the certificate's SAN list, so re-run `letsencrypt:enable`. The plugin emits a warning prompting you to do this whenever `dokku domains:add` or `dokku domains:set` touches the app.

## Default-vhost (`_`) domain

Dokku 0.30.4 added support for the literal `_` domain as an nginx default catch-all vhost. Let's Encrypt rejects `_` as an invalid identifier, so the plugin silently drops it from the certificate's SAN list and requests a certificate for the remaining domains. An app whose only domain is `_` cannot be enabled and falls into the existing "no domains detected" error path.

## Dockerfile and image-based deploys

When securing Dockerfile or image-based deploys, the plugin needs port 80 reachable for the HTTP-01 challenge and port 443 mapped to your app's container port for HTTPS traffic. For Dockerfile deploys, dokku proxies whichever ports the image declares with `EXPOSE` on the same port numbers on the host. Dokku also adds a matching `https:443:<container-port>` mapping for every `http:80:<container-port>` whenever a certificate is installed, so the standard case requires no manual `dokku ports:*` calls.

To keep the HTTP-01 challenge working, `letsencrypt:enable` looks for an `http:80:*` entry in the app's proxy port map. If none exists, the plugin injects one using the container port from the first existing `http:*:*` (or `https:*:*`) mapping, including detected mappings from `EXPOSE`. The new mapping is persisted so subsequent renewals do not need to re-add it. Once the certificate is installed, dokku's `post-certs-update` trigger fills in the matching `https:443` mapping, completing the proxy setup. If the app has no `http` or `https` mapping at all, `letsencrypt:enable` exits with an error pointing at `dokku ports:add` rather than issuing a request that the ACME server would reject. DNS-01 deployments skip the port-80 check entirely because they do not use port 80 for validation.

A full workflow for a Dockerfile or image-based app listening on port 5555:

1. Create the app and push it to dokku.
2. On the dokku host, run `dokku letsencrypt:enable myapp` to retrieve and install the certificate.

After this, `dokku ports:report myapp` should show:

```
=====> myapp ports information
       Ports map:                     http:80:5555 https:443:5555
       Ports map detected:            https:5555:5555
```

Replace `5555` with whatever container port your app actually listens on.

## HTTP to HTTPS redirect

Dokku's default nginx template automatically redirects HTTP requests to HTTPS once a certificate is installed. To change this behavior, [customize the nginx template](https://dokku.com/docs/networking/proxies/nginx/).

## Rate limits

Let's Encrypt enforces [public rate limits](https://letsencrypt.org/docs/rate-limits/). The most relevant one for dokku is the per-week cap on certificates per registered domain: because dokku gives every new app a default subdomain like `<app>.<dokku-domain>`, running this plugin on many apps that all share `<dokku-domain>` will hit that cap quickly.

The workaround is to set a real domain per app and remove the default subdomain before enabling. For example, if your dokku domain is `dokku.example.com` and you want to secure your `foo` app at `foo.com`:

```shell
dokku domains:add foo foo.com
dokku domains:remove foo foo.dokku.example.com
dokku letsencrypt:enable foo
```

While iterating on configuration, point the plugin at Let's Encrypt's staging environment, which has much higher rate limits and issues untrusted certificates:

```shell
dokku letsencrypt:set myapp server staging
dokku letsencrypt:enable myapp
```

Once you are ready for a production certificate, clear the override and re-enable:

```shell
dokku letsencrypt:set myapp server
dokku letsencrypt:enable myapp --force
```

When the ACME server returns a rate-limit response, `letsencrypt:enable` exits non-zero and prints a dedicated warning pointing at the Let's Encrypt rate-limits documentation and suggesting the staging server. The full lego output is still printed above the warning, so the specific limit that was hit ("too many certificates already issued", "too many failed authorizations", etc.) remains visible.

## Shared ACME account

Let's Encrypt also limits new accounts per IP to 10 per 3 hours, which would be easy to trip on a busy dokku host. To stay clear of this, the plugin stores a single ACME account in `${DOKKU_LIB_ROOT}/data/letsencrypt/accounts` and mounts it into every lego invocation. Apps sharing the same `email` and `server` reuse one account regardless of how many apps are enabled, matching Let's Encrypt's [recommendation](https://letsencrypt.org/docs/integration-guide/#one-account-or-many) for hosting providers. Apps configured with a distinct `email` or `server` get their own entry under the shared directory, keyed by `(server, email)`.

When upgrading from a previous version of this plugin, the first `letsencrypt:enable` after the upgrade registers exactly one new account in the shared directory. Existing per-app account material under `$DOKKU_ROOT/<app>/letsencrypt/certs/<hash>/accounts/` is left in place so that `letsencrypt:revoke` for certificates issued before the upgrade can still find the original account.

## App cloning and renaming

The plugin clears the destination app's `letsencrypt` directory whenever an app is cloned or renamed. Certificates are bound to specific domains and specific config hashes, so reusing the source app's directory would leave the new app pointing at the wrong cert. After cloning or renaming, run `letsencrypt:enable` on the new app to issue a fresh certificate.

```shell
dokku apps:clone myapp myapp-staging
dokku letsencrypt:enable myapp-staging
```

## Cloudflare

If your domain is proxied through Cloudflare, set Cloudflare's DNS records to "Proxied" mode and configure SSL/TLS to "Full" mode before enabling this plugin. Cloudflare's "Flexible" mode terminates HTTPS at Cloudflare's edge and connects to your origin over plain HTTP, which means Let's Encrypt's renewal request is served back as HTTP rather than reaching your origin's HTTPS listener. Symptoms range from validation failures to Cloudflare reporting the origin as down.

If you are committed to "Flexible" SSL/TLS mode, do not use this plugin. For background, see:

- <https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/>
- <https://community.cloudflare.com/t/lets-encrypt-ssl-cannot-renew-with-cloudflare/257666>

## License

[MIT](LICENSE)
