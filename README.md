# dokku-letsencrypt

dokku-letsencrypt is the official plugin for [dokku][dokku] that gives the ability to automatically retrieve and install TLS certificates from [letsencrypt.org](https://letsencrypt.org). During ACME validation, your app will stay available at any time.

> By running this plugin, you agree to the Let's Encrypt Subscriber Agreement automatically (because prompting you whether you agree might break running the plugin as part of a cronjob).
>
> If you like Let's Encrypt, please consider [donating to Let's Encrypt](https://letsencrypt.org/donate).

## Installation

```sh
sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
```

### Upgrading from previous versions

```sh
sudo dokku plugin:update letsencrypt
```

## Commands

```
$ dokku letsencrypt:help
    letsencrypt:auto-renew                  Auto-renew all apps secured by letsencrypt if renewal is necessary
    letsencrypt:auto-renew <app>            Auto-renew app if renewal is necessary
    letsencrypt:cleanup <app>               Cleanup stale certificates and configurations
    letsencrypt:cron-job <--add|--remove>   Add or remove an auto-renewal cronjob
    letsencrypt:disable <app>               Disable letsencrypt for an app
    letsencrypt:enable <app>                Enable or renew letsencrypt for an app
    letsencrypt:list                        List letsencrypt-secured apps with certificate expiry
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
$ dokku config:set --no-restart myapp DOKKU_LETSENCRYPT_EMAIL=your@email.tld
-----> Setting config vars
       DOKKU_LETSENCRYPT_EMAIL: your@email.tld
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
```
dokku config:set --global DOKKU_LETSENCRYPT_EMAIL=your@email.tld
```

## Automatic certificate renewal

To enable the automatic renewal of certificates, a cronjob needs to be defined for
the `dokku` user which will run daily and renew any certificates that are due to
be renewed.

This can be done using the following command:

```
dokku letsencrypt:cron-job --add
```

## Configuration
`dokku-letsencrypt` uses the [Dokku environment variable manager](http://dokku.viewdocs.io/dokku/configuration-management/) for all configuration. The important environment variables are:

Variable                        | Default           | Description
--------------------------------|-------------------|-------------------------------------------------------------------------
`DOKKU_LETSENCRYPT_EMAIL`       | (none)            | **REQUIRED:** E-mail address to use for registering with Let's Encrypt.
`DOKKU_LETSENCRYPT_GRACEPERIOD` | 5184000 (30 days) | Time in seconds left on a certificate before it should get renewed
`DOKKU_LETSENCRYPT_SERVER`      | default           | Which ACME server to use. Can be 'default', 'staging' or a URL
`DOKKU_LETSENCRYPT_ARGS`        | (none)            | Extra arguments to pass via `docker run`. See the [lego CLI documentation](https://go-acme.github.io/lego/usage/cli/) for available options.

You can set a setting using `dokku config:set --no-restart <myapp> SETTING_NAME=setting_value`. When looking for a setting, the plugin will first look if it was defined for the current app and fall back to settings defined by `--global`.

## Redirecting from HTTP to HTTPS

Dokku's default nginx template will automatically redirect HTTP requests to HTTPS when a certificate is present.

You can [customize the nginx template](http://dokku.viewdocs.io/dokku/configuration/nginx/) if you want different behaviour.

## Design

`dokku-letsencrypt` gets around having to disable your web server using the following workflow:

  1. Temporarily add a reverse proxy for the `/.well-known/` path of your app to `https://127.0.0.1:$ACMEPORT`
  2. Run [the acme/lego Let's Encrypt client](https://github.com/go-acme/lego) in a [Docker container](https://hub.docker.com/r/goacme/lego/) binding to `$ACMEPORT` to complete the ACME challenge and retrieve the TLS certificates
  3. Install the TLS certificates
  4. Remove the reverse proxy and reload nginx

For a more in-depth explanation, see [this blog post](https://blog.semicolonsoftware.de/securing-dokku-with-lets-encrypt-tls-certificates/)

## Dockerfile Deploys

When securing Dockerfile deploys with dokku-letsencrypt, be aware of the [proxy mechanism for dokku 0.6+](http://dokku.viewdocs.io/dokku/advanced-usage/proxy-management/#proxy-port-mapping).

For Dockerfile deploys, by default, dokku will determine which ports a container exposes and proxies all those exposed ports in the Docker container by listening on the same port numbers on the host. This means that **both the proxies for HTTP port 80 and HTTPS port 443 to the app's container need to be manually configured** using the `dokku proxy:ports-*` commands in order for certificate validation and browsing to the app via HTTPS to work.

A full workflow for creating a new Dockerfile deployment (where the app is listening on port 5555) with dokku-letsencrypt would be:

1. Create a new app `myapp` in dokku and push to the `dokku@myhost.com` remote. This guide assumes that the Docker container will be listening for connections on port 5555 so replace container port numbers accordingly if necessary.
2. On the dokku host, use `dokku proxy:ports-add myapp http:80:5555` to proxy HTTP port 80 to port 5555 on the Docker image
3. On the dokku host, use `dokku letsencrypt:enable myapp` to retrieve HTTPS certificates.
4. On the dokku host, use `dokku proxy:ports-add myapp https:443:5555` to proxy HTTPS port 443 to port 5555 on the Docker image
5. (optional) On the dokku host, use `dokku proxy:ports-remove myapp http:5555:5555` to remove a potential leftover proxy that was automatically configured on first deploy.

After these steps, the output of `dokku proxy:ports myapp` should look like this:

```
-----> Port mappings for myapp
-----> scheme             host port                 container port
http                      80                        5555
https                     443                       5555
```

Replace the container port (`5555` in the above example) with the port your app is listening on.

**Note:** Step 2 and step 4 cannot be joined together since a configured HTTPS proxy will include a `ssl_certificate` line in the app's nginx config that will cause nginx config validation to fail because no valid HTTPS certificate is available until step 3 is completed.

## Dealing with rate limit

Be aware that Let's Encrypt is subject to [rate limiting](https://letsencrypt.org/docs/rate-limits/). The limit about the number of certificates you can add on a domain per week is a concern for dokku because of the default domain added to your new applications, named like `<app>.<dokku-domain>`: using `dokku-letsencrypt` on all your applications would create a certificate for each application subdomain on `<dokku-domain>`.

As a workaround, if you want to encrypt many applications, make sure to add a proper domain for each one and remove their default domain before running `dokku-letsencrypt`. For example, if your dokku domain is `dokku.example.com` and you want to encrypt your `foo` app:

```
dokku domains:add foo foo.com
dokku domains:remove foo foo.dokku.example.com
dokku letsencrypt:enable foo
```

While playing around with this plugin, you might want to switch to the let's encrypt staging server by running `dokku config:set --no-restart myapp DOKKU_LETSENCRYPT_SERVER=staging` to enjoy much higher rate limits and switching back to the real server by running `dokku config:unset --no-restart myapp DOKKU_LETSENCRYPT_SERVER` once you are ready.

## Generating a Cert for multiple domains

Your [default dokku app](http://dokku.viewdocs.io/dokku/configuration/domains/#default-site) is accessible under the root domain too. So if you have an application `00-default` that is running under `00-default.mydomain.com` it is accessible under `mydomain.com` too. Now if you enable letsencrypt for your `00-default` application, it is not accessible anymore on `mydomain.com`. You can add the root domain to your dokku domains by typing:

```
dokku domains:add 00-default mydomain.com
dokku letsencrypt:enable 00-default
```

## License

This plugin is released under the MIT license. See the file [LICENSE](LICENSE).

[dokku]: https://github.com/dokku/dokku
