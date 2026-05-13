# dokku-letsencrypt

dokku-letsencrypt is the official plugin for [dokku][dokku] that gives the ability to automatically retrieve and install TLS certificates from [letsencrypt.org](https://letsencrypt.org). During ACME validation, your app will stay available at any time.

> By running this plugin, you agree to the Let's Encrypt Subscriber Agreement automatically (because prompting you whether you agree might break running the plugin as part of a cronjob).
>
> If you like Let's Encrypt, please consider [donating to Let's Encrypt](https://letsencrypt.org/donate).

## Installation

```shell
sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
sudo dokku letsencrypt:cron-job --add # <- To enable auto-renew
```

### Upgrading from previous versions

```shell
sudo dokku plugin:update letsencrypt
```

## Commands

```
$ dokku letsencrypt:help
    letsencrypt:active <app>                Verify if letsencrypt is active for an app
    letsencrypt:auto-renew                  Auto-renew all apps secured by letsencrypt if renewal is necessary
    letsencrypt:auto-renew <app>            Auto-renew app if renewal is necessary
    letsencrypt:cleanup <app>               Cleanup stale certificates and configurations
    letsencrypt:cron-job [--add|--remove]   Add, remove, or display the status of the auto-renewal cronjob
    letsencrypt:disable <app>               Disable letsencrypt for an app
    letsencrypt:enable <app> [--force]      Enable or renew letsencrypt for an app (skipped when a valid certificate already exists unless --force is set)
    letsencrypt:list                        List letsencrypt-secured apps with certificate expiry
    letsencrypt:report [<app>|--global]     Display a letsencrypt report for one or more apps
    letsencrypt:revoke <app>                Revoke letsencrypt certificate for app
```

## Usage

> If using this plugin with Cloudflare:
>
> - The domain dns should be setup in "Proxied" mode
> - SSL/TLS mode must be in "Full" mode
>   - Using letsencrypt in "Flexible" mode will cause Cloudflare to detect your server as down
>   - Using "Full" mode will require disabling SSL/TLS in cloudflare in order to renew the certificate.
>
> If using "Flexible" SSL/TLS mode, avoid using this plugin.
>
> See these two links for more details:
>
>  - https://community.cloudflare.com/t/lets-encrypt-ssl-cannot-renew-with-cloudflare/257666
>  - https://support.cloudflare.com/hc/en-us/articles/214820528-Validating-a-Let-s-Encrypt-Certificate-on-a-Site-Already-Active-on-Cloudflare

The app which is obtaining a letsencrypt certificate must already be deployed and accessible over the internet (i.e. in the browser) in order to add letsencrypt to your app. This plugin will fail to apply for an app that has otherwise only been created.

Obtain a Let's encrypt TLS certificate for app `myapp` (you can also run this command to renew the certificate):

```
$ dokku letsencrypt:set myapp email your@email.tld
-----> Setting email to your@email.tld
$ dokku letsencrypt:enable myapp
=====> Let's Encrypt myapp...
-----> Updating letsencrypt docker image...
latest: Pulling from dokku/letsencrypt

Digest: sha256:20f2a619795c1a3252db6508f77d6d3648ad5b336e67caaf801126367dbdfa22
Status: Image is up to date for dokku/letsencrypt:latest
       done
-----> Enabling letsencrypt proxy for myapp...
-----> Getting letsencrypt certificate for myapp...
        - Domain 'myapp.mydomain.com'

[ removed various log messages for brevity ]

-----> Certificate retrieved successfully.
-----> Symlinking let's encrypt certificates
-----> Configuring SSL for myapp.mydomain.com...(using /var/lib/dokku/plugins/available/nginx-vhosts/templates/nginx.ssl.conf.template)
-----> Creating https nginx.conf
-----> Running nginx-pre-reload
       Reloading nginx
-----> Disabling letsencrypt proxy for myapp...
       done
```

Once the certificate is installed, you can use the `certs:*` built-in commands to edit and query your certificate.

You could also use the following command to set an email address for global. So you don't need to type the email address for different application.

```shell
dokku letsencrypt:set --global email your@email.tld
```

## Automatic certificate renewal

To enable the automatic renewal of certificates, a cronjob needs to be defined for
the `dokku` user which will run daily and renew any certificates that are due to
be renewed.

This can be done using the following command:

```shell
dokku letsencrypt:cron-job --add
```

Running `dokku letsencrypt:cron-job` without a flag reports whether the auto-renewal cron job is currently enabled.

## Configuration

`dokku-letsencrypt` uses the [Dokku environment variable manager](https://dokku.com/docs/configuration/environment-variables/) for all configuration. The important environment variables are:

Variable             | Default           | Description
---------------------|-------------------|-------------------------------------------------------------------------
`dns-provider`       | (none)            | The name of a [valid lego dns-provider](https://go-acme.github.io/lego/dns/)
`email`              | (none)            | **REQUIRED:** E-mail address to use for registering with Let's Encrypt.
`graceperiod`        | 2592000 (30 days) | Time in seconds left on a certificate before it should get renewed
`lego-args`          | (none)            | Extra arguments to pass to the `lego` CLI. See the [lego CLI documentation](https://go-acme.github.io/lego/usage/cli/) for available options. Previously named `lego-docker-args`; existing values are migrated automatically on plugin update.
`lego-docker-options`| (none)            | Extra arguments to pass to `docker run` when starting the `lego` container (for volume mounts, extra env files, custom networks, etc.). Distinct from `lego-args`, which targets the `lego` CLI itself.
`server`             | default           | Which ACME server to use. Can be 'default', 'staging' or a URL

You can set a setting using `dokku letsencrypt:set $APP $SETTING_NAME $SETTING_VALUE`. When looking for a setting, the plugin will first look if it was defined for the current app and fall back to settings defined by `--global`.

> Note: See "DNS-01 Challenge" for more information on configuration a dns-provider for DNS-01 based challenges and wildcard support.

## Reports

The `letsencrypt:report` command exposes app-level and global plugin properties for consumption by external tooling. Without arguments, it prints a human-readable report for every app:

```shell
dokku letsencrypt:report
dokku letsencrypt:report myapp
```

Pass `--global` to limit output to the global properties only:

```shell
dokku letsencrypt:report --global
```

Pass `--format json` to emit a JSON object instead of the default stdout layout. The flag works with app, global, and "all apps" invocations:

```shell
dokku letsencrypt:report myapp --format json
dokku letsencrypt:report --global --format json
dokku letsencrypt:report --format json
```

Specifying a single property flag (such as `--letsencrypt-email`) still prints just that value:

```shell
dokku letsencrypt:report myapp --letsencrypt-email
```

Combining `--format json` with a single property flag is rejected.

Any `dns-provider-*` properties set globally or for the app appear in the report alongside the fixed fields. For each set property, the report emits the scopes that actually have a value: a `--letsencrypt-dns-provider-<KEY>` row when set on the app, a `--letsencrypt-global-dns-provider-<KEY>` row when set globally, and a `--letsencrypt-computed-dns-provider-<KEY>` row that resolves to the app value (falling back to the global value). Querying an unset scope with the info-flag form is rejected as an invalid flag.

The top-level `dokku report <app>` command aggregates output from every plugin and is commonly used in support and diagnostic contexts. When the letsencrypt section is rendered through that aggregate command, every `dns-provider-*` credential value is redacted to `****` to avoid leaking DNS provider API keys, tokens, or `_FILE` paths into shared output. The provider *name* (`dns-provider`, `global-dns-provider`, `computed-dns-provider`) and every other property (`email`, `server`, `graceperiod`, `lego-args`, `lego-docker-options`) remain unredacted. `dokku letsencrypt:report` is unaffected and continues to show raw values, so operators can verify what they have configured.

## Redirecting from HTTP to HTTPS

Dokku's default nginx template will automatically redirect HTTP requests to HTTPS when a certificate is present.

You can [customize the nginx template](https://dokku.com/docs/networking/proxies/nginx/) if you want different behaviour.

## Design

`dokku-letsencrypt` gets around having to disable your web server using the following workflow:

  1. Temporarily add a reverse proxy for the `/.well-known/` path of your app to `https://127.0.0.1:$ACMEPORT`
  2. Run [the acme/lego Let's Encrypt client](https://github.com/go-acme/lego) in a [Docker container](https://hub.docker.com/r/goacme/lego/) binding to `$ACMEPORT` to complete the ACME challenge and retrieve the TLS certificates
  3. Install the TLS certificates
  4. Remove the reverse proxy and reload nginx

For a more in-depth explanation, see [this blog post](https://blog.semicolonsoftware.de/securing-dokku-with-lets-encrypt-tls-certificates/)

## Dockerfile and Image-based Deploys

When securing Dockerfile and Image-based deploys with dokku-letsencrypt, be aware of the [proxy mechanism for dokku 0.6+](https://dokku.com/docs/networking/port-management/#dockerfile).

For Dockerfile deploys - as well as those via `git:from-image` - Dokku will determine which ports a container exposes (using `EXPOSE`) and will proxy them on the same port numbers on the host. If the Dockerfile exposes another port than 443, then HTTPS port 443 **needs to be manually configured** using the `dokku ports:*` commands in order for certificate validation and browsing to the app via HTTPS to work.

The HTTP-01 challenge used by Let's Encrypt also needs the app to be reachable on port 80. When `letsencrypt:enable` runs and the app's proxy port-map has no `http:80:*` entry, the plugin will inject one automatically using the container port from the first existing `http:*:*` (or `https:*:*`) mapping, so the ACME challenge can be served from nginx. The new mapping is persisted so subsequent renewals do not need to re-add it. If no `http` or `https` mapping exists at all, `letsencrypt:enable` exits with an error pointing to `dokku ports:add` instead of issuing a request that would fail at the ACME server. DNS-01 deployments skip this check because they do not depend on a port 80 listener.

A full workflow for creating a new Dockerfile/Image-based deployment (assuming the app is listening/exposed on port 5555) with `dokku-letsencrypt` would be:

1. Create a new app `myapp` in dokku and push to the `dokku@myhost.com` remote.
2. On the dokku host, use `dokku letsencrypt:enable myapp` to retrieve HTTPS certificates.
3. On the dokku host, use `dokku ports:add myapp https:443:5555` to proxy HTTPS port 443 to port 5555 on the Docker image

After these steps, the output of `dokku ports:report myapp` should look like this:

```
=====> myapp ports information
       Ports map:                     http:80:5555 https:443:5555
       Ports map detected:            https:5555:5555
```

Replace the container port (`5555` in the above example) with the port your app is listening on.

## Dealing with rate limit

Be aware that Let's Encrypt is subject to [rate limiting](https://letsencrypt.org/docs/rate-limits/). The limit about the number of certificates you can add on a domain per week is a concern for dokku because of the default domain added to your new applications, named like `<app>.<dokku-domain>`: using `dokku-letsencrypt` on all your applications would create a certificate for each application subdomain on `<dokku-domain>`.

As a workaround, if you want to encrypt many applications, make sure to add a proper domain for each one and remove their default domain before running `dokku-letsencrypt`. For example, if your dokku domain is `dokku.example.com` and you want to encrypt your `foo` app:

```sh
dokku domains:add foo foo.com
dokku domains:remove foo foo.dokku.example.com
dokku letsencrypt:enable foo
```

While playing around with this plugin, you might want to switch to the let's encrypt staging server by running `dokku letsencrypt:set myapp server  staging` to enjoy much higher rate limits and switching back to the real server by running `dokku letsencrypt:set myapp server` once you are ready.

When the ACME server returns a rate-limit response, `letsencrypt:enable` exits non-zero and prints a dedicated warning that points at the [Let's Encrypt rate-limits documentation](https://letsencrypt.org/docs/rate-limits/) and suggests switching to the staging server while iterating. The full lego output is still printed above the warning, so the specific limit that was hit (for example "too many certificates already issued" or "too many failed authorizations") remains visible.

### Shared ACME account

To stay clear of the [new accounts per IP](https://letsencrypt.org/docs/rate-limits/) limit (10 per 3 hours), the plugin stores a single ACME account in `${DOKKU_LIB_ROOT}/data/letsencrypt/accounts` and mounts it into every `lego` invocation. Apps sharing the same `email` and `server` reuse one account regardless of how many apps are enabled, matching Let's Encrypt's [recommendation](https://letsencrypt.org/docs/integration-guide/#one-account-or-many) for hosting providers. Apps configured with a distinct `email` or `server` get their own entry under the shared directory, keyed by `(server, email)`.

When upgrading from a previous version of this plugin, the first `letsencrypt:enable` after the upgrade registers exactly one new account in the shared directory. Existing per-app account material under `$DOKKU_ROOT/<app>/letsencrypt/certs/<hash>/accounts/` is left in place so that `letsencrypt:revoke` for certificates issued before the upgrade can still find the original account.

## Generating a Cert for multiple domains

Your [default dokku app](https://dokku.com/docs/networking/proxies/nginx/?h=default+site#default-site) is accessible under the root domain too. So if you have an application `00-default` that is running under `00-default.mydomain.com` it is accessible under `mydomain.com` too. Now if you enable letsencrypt for your `00-default` application, it is not accessible anymore on `mydomain.com`. You can add the root domain to your dokku domains by typing:

```shell
dokku domains:add 00-default mydomain.com
dokku letsencrypt:enable 00-default
```

## Default-vhost (`_`) domain

Dokku 0.30.4 added support for the literal `_` domain as an Nginx default catch-all vhost. Let's Encrypt rejects `_` as an invalid identifier, so this plugin silently drops it from the certificate's SAN list and requests a certificate for the remaining domains. An app whose only domain is `_` cannot be enabled and falls into the existing "no domains detected" error path.

## DNS-01 Challenge

> Functionality sponsored by [Orca Scan Ltd](https://orcascan.com/).

In order to provide a Letsencrypt certificate for a wildcard domain, a DNS-01 challenge must be used. To configure, the `dns-provider` property must be set to a [supported Lego provider](https://go-acme.github.io/lego/dns/). Additionally, the environment variables used by the DNS provider must be set as letsencrypt properties with the prefix `dns-provider-`. Both global and app-specific properties are supported.

> Warning: Before using a DNS-based challenge, ensure all DNS records - including wildcard records - are pointing at your server.

```shell
# set the provider to namecheap
dokku letsencrypt:set --global dns-provider namecheap

# set the properties necessary for namecheap usage
dokku letsencrypt:set --global dns-provider-NAMECHEAP_API_USER user
dokku letsencrypt:set --global dns-provider-NAMECHEAP_API_KEY key
```

If a DNS provider documents `_FILE`-suffixed environment variables for reading secrets from files, mount the secret file into the `lego` container with `lego-docker-options` and set the corresponding `dns-provider-*_FILE` property to the in-container path. For example:

```shell
dokku letsencrypt:set --global lego-docker-options "-v /etc/dokku-letsencrypt/cloudflare-token:/secrets/cf-token:ro"
dokku letsencrypt:set --global dns-provider-CLOUDFLARE_DNS_API_TOKEN_FILE /secrets/cf-token
```

### Using the `exec` DNS provider

The `lego` [`exec` DNS provider](https://go-acme.github.io/lego/dns/exec/) shells out to a user-supplied script for creating and removing TXT records. The script must be reachable from inside the `lego` container at the path stored in the `EXEC_PATH` environment variable. Use `lego-docker-options` to mount it from the host:

```shell
# write the script on the dokku host, make it executable
sudo install -m 0755 /path/on/host/dns.sh /var/lib/dokku/data/letsencrypt/exec-dns.sh

# mount it into the lego container and point exec at it
dokku letsencrypt:set --global dns-provider exec
dokku letsencrypt:set --global lego-docker-options "-v /var/lib/dokku/data/letsencrypt/exec-dns.sh:/scripts/dns.sh:ro"
dokku letsencrypt:set --global dns-provider-EXEC_PATH /scripts/dns.sh
```

Please see the Lego documentation for your DNS provider for more information on what configuration is necessary to utilize DNS-01 challenges.

### Disabling DNS-01 for a single app

When a global `dns-provider` is set but a particular app's domain is not managed by that provider, set the app's `dns-provider` to `none` to force HTTP-01 for that app only:

```shell
dokku letsencrypt:set <app> dns-provider none
```

Setting the property to an empty string (`dokku letsencrypt:set <app> dns-provider ""`) deletes the app-level value and falls back to the global setting; `none` is the explicit opt-out. The `none` sentinel is also accepted at `--global` scope, where it behaves identically to leaving the property unset.

## Idempotent enable

`dokku letsencrypt:enable <app>` is safe to call on every deploy. It only contacts the ACME server when one of the following is true:

- the app does not currently have a Let's Encrypt certificate installed
- the app's domains, email, server, `lego-args`, `lego-docker-options`, or `dns-provider` have changed since the certificate was issued
- the certificate is within its renewal grace period (see the `graceperiod` configuration variable)

In every other case the command exits successfully without touching nginx, the lego container, or the ACME server. This avoids running into Let's Encrypt rate limits when the same app is redeployed many times in a short window (for example, CI-driven review apps).

To force a new certificate request even when the existing certificate is still valid, pass `--force`:

```shell
dokku letsencrypt:enable <app> --force
```

This is useful when copying certificates between servers (the host did not issue the cert, so the ACME account on the new host has no record of it) or when manually rotating an existing certificate.

## License

This plugin is released under the MIT license. See the file [LICENSE](LICENSE).

[dokku]: https://github.com/dokku/dokku
