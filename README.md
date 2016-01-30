# dokku-letsencrypt (Beta)

dokku-letsencrypt is the official plugin for [dokku][dokku] that gives the ability to automatically retrieve and install TLS certificates from [letsencrypt.org](https://letsencrypt.org). Contrary to other methods, no temporary disabling of the webserver is required during the ACME challenge procedure (see the 'Design' section for how this is done)!

**Note:** `dokku-letsencrypt` will not auto-renew the certificates (but you can run the included certificate renewal procedure in a cronjob).

**Note:** By running this plugin, you agree to the Let's Encrypt Subscriber Agreement automatically (because prompting you whether you agree might break running the plugin as part of a cronjob).

**Note:** If you like Let's Encrypt, please consider [donating to Let's Encrypt](https://letsencrypt.org/donate).

## Installation

```sh
# dokku 0.4+
$ sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
```

## Commands

```
$ dokku help
    letsencrypt <app>                       Enable or renew letsencrypt certificate for app
    letsencrypt:auto-renew                  Auto-renew all apps secured by letsencrypt if renewal is necessary
    letsencrypt:auto-renew <app>            Auto-renew app if renewal is necessary
    letsencrypt:email <app>                 Get e-mail address used as letsencrypt contact
    letsencrypt:email <app> <e-mail>        Set e-mail address used as letsencrypt contact
    letsencrypt:ls                          List letsencrypt-secured apps with certificate expiry
    letsencrypt:renew-before <app>          Get renewal grace period for app
    letsencrypt:renew-before <app> <time>   Set renewal grace period for app to <time> seconds
    letsencrypt:revoke <app>                Revoke letsencrypt certificate for app
    letsencrypt:server <app>                Display selected letsencrypt server for app
    letsencrypt:server <app> <server>       Select a letsencrypt server for app. Server can be 'default', 'staging' or a URL
```

## Usage

Obtain a Let's encrypt TLS certificate for app `myapp` (you can also run this command to renew the certificate):

```
$ dokku letsencrypt:email myapp your@email.tld
=====> Setting Let's Encrypt e-mail address for myapp to 'your@email.tld'

$ dokku letsencrypt myapp
=====> Let's Encrypt myapp...
-----> Updating letsencrypt docker image...
latest: Pulling from m3adow/letsencrypt-simp_le

Digest: sha256:20f2a619795c1a3252db6508f77d6d3648ad5b336e67caaf801126367dbdfa22
Status: Image is up to date for m3adow/letsencrypt-simp_le:latest
       done
-----> Enabling ACME proxy for myapp...
-----> Getting letsencrypt certificate for myapp...
        - Domain 'myapp.mydomain.com'
        hash of all pertinent configuration settings is a131be342a0d7661817a4c23b1a767f5da5abbf3

[ removed various log messages for brevity ]

-----> Certificate retrieved successfully.
-----> Symlinking let's encrypt certificates
-----> Configuring SSL for myapp.mydomain.com...(using /var/lib/dokku/plugins/available/nginx-vhosts/templates/nginx.ssl.conf.template)
-----> Creating https nginx.conf
-----> Running nginx-pre-reload
       Reloading nginx
-----> Disabling ACME proxy for myapp...
       done
```

Once the certificate is installed, you can use the `certs:*` built-in commands to edit and query your certificate.

## Design

`dokku-letsencrypt` gets around having to disable your web server using the following workflow:

  1. Temporarily add a reverse proxy for the `/.well-known/` path of your app to `https://127.0.0.1:$ACMEPORT`
  2. Run [the simp_le Let's Encrypt client](https://github.com/kuba/simp_le) in a [Docker container](https://hub.docker.com/r/m3adow/letsencrypt-simp_le) binding to `$ACMEPORT` to complete the ACME challenge and retrieve the TLS certificates
  3. Install the TLS certificates
  4. Remove the reverse proxy and reload nginx

For a more in-depth explanation, see [this blog post](https://blog.semicolonsoftware.de/securing-dokku-with-lets-encrypt-tls-certificates/)


## Dealing with rate limit

Be aware that Let's Encrypt is subject to [rate limiting](https://community.letsencrypt.org/t/rate-limits-for-lets-encrypt/6769). The limit about the number of certificates you can add on a domain per week is a concern for dokku because of the default domain added to your new applications, named like `<app>.<dokku-domain>`: using `dokku-letsencrypt` on all your applications would create a certificate for each application subdomain on `<dokku-domain>`.

As a workaround, if you want to encrypt many applications, make sure to add a proper domain for each one and remove their default domain before running `dokku-letsencrypt`. For example, if your dokku domain is `dokku.example.com` and you want to encrypt your `foo` app:

```
dokku domains:add foo foo.com
dokku domains:remove foo foo.dokku.example.com
dokku letsencrypt foo
```

While playing around with this plugin, you might want to switch to the let's encrypt staging server by running `dokku letsencrypt:server myapp staging` to enjoy much higher rate limits and switching back to the real server by running `dokku letsencrypt:server myapp default` once you are ready.

## License

This plugin is released under the MIT license. See the file [LICENSE](LICENSE).

[dokku]: https://github.com/progrium/dokku
