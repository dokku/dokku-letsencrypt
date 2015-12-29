# dokku-letsencrypt

dokku-letsencrypt is a plugin for [dokku][dokku] that gives the ability to automatically retrieve and install TLS certificates from [letsencrypt.org](https://letsencrypt.org). Contrary to other methods, no temporary disabling of the webserver is required during the ACME challenge procedure (see the 'Design' section for how this is done)!

**Note:** `dokku-letsencrypt` will not auto-renew the certificates (but you can run the included certificate renewal procedure in a cronjob).

**Note:** By running this plugin, you agree to the Let's Encrypt Subscriber Agreement automatically (because prompting you whether you agree might break running the plugin as part of a cronjob).

## Installation

```sh
# dokku 0.4+
$ sudo dokku plugin:install https://github.com/sseemayer/dokku-letsencrypt.git
```

## Commands

```
$ dokku help
    letsencrypt <app>                  Enable or renew letsencrypt certificate for app
    letsencrypt:server <app>           Display selected letsencrypt server for app
    letsencrypt:server <app> <server>  Select a letsencrypt server for app. Server can be 'default', 'staging' or a URL
```

## Usage

Obtain a Let's encrypt TLS certificate for app `myapp` (you can also run this command to renew the certificate):

```
$ dokku letsencrypt myapp
-----> Let's Encrypt myapp...
-----> Updating letsencrypt docker image...
latest: Pulling from letsencrypt/letsencrypt
Digest: sha256:b7543399a2347b43c1d0f3b8c2a3deb8a9d3945fb762c0dbd1d595927813e9c4
Status: Image is up to date for quay.io/letsencrypt/letsencrypt:latest
       done
-----> Enabling ACME proxy for myapp...
-----> Getting letsencrypt certificate for myapp...
        - Domain 'myapp.mydomain.com'
IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at
   /etc/letsencrypt/live/myapp.mydomain.com/fullchain.pem.
   Your cert will expire on 2016-03-10. To obtain a new version of the
   certificate in the future, simply run Let's Encrypt again.
 - If you like Let's Encrypt, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le

-----> Configuring SSL for myapp.mydomain.com...
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
  2. Run [letsencrypt as a Docker container](https://letsencrypt.readthedocs.org/en/latest/using.html#running-with-docker) with the 'standalone' authenticator binding to `$ACMEPORT` to complete the ACME challenge and retrieve the TLS certificates
  3. Install the TLS certificates
  4. Remove the reverse proxy

For a more in-depth explanation, see [this blog post](https://blog.semicolonsoftware.de/securing-dokku-with-lets-encrypt-tls-certificates/)


## Dealing with rate limit

Be aware that Let's Encrypt is subject to [rate limiting](https://community.letsencrypt.org/t/rate-limits-for-lets-encrypt/6769). The limit about the number of certificates you can add on a domain per week is a concern for dokku because of the default domain added to your new applications, named like `<app>.<dokku-domain>`: using `dokku-letsencrypt` on all your applications would create a certificate for each application subdomain on `<dokku-domain>`.

As a workaround, if you want to encrypt many applications, make sure to add a proper domain for each one and remove their default domain before running `dokku-letsencrypt`. For example, if your dokku domain is `dokku.example.com` and you want to encrypt your `foo` app:

```
dokku domains:add foo.com
dokku domains:remove foo.dokku.example.com
dokku letsencrypt foo
```

While playing around with this plugin, you might want to switch to the let's encrypt staging server by running `dokku letsencrypt:server myapp staging` to enjoy much higher rate limits and switching back to the real server by running `dokku letsencrypt:server myapp default` once you are ready.

## License

This plugin is released under the MIT license. See the file [LICENSE](LICENSE).

[dokku]: https://github.com/progrium/dokku
