Nginx reverse proxy
===================

Nginx-based, HTTP reverse proxy server intended to aggregate different backend services behind a common domain URL, to avoid problems with cookies, CORS or untrusted certificates.

To build the container:

```
git clone https://github.com/rjrivero/docker-rproxy.git
cd docker-rproxy

docker build -t rproxy .
```

To run:

```
docker run --rm -p 8080:80 --name rproxy rproxy
```

The container exposes **ports 80 and 443**.

Volumes
-------

The embedded nginx server uses:

  - **/opt/www/** as document root.
  - **/etc/nginx/proxy.d/** for advanced configuration files.
  - **/etc/nginx/rewrite.d/** for top-level rewrite rules

Users
-----

The nginx service is run by user nginx, group nginx. The uid and gid are defined in the official [Docker Nginx container](https://hub.docker.com/_/nginx/) and currently are **104** and **107** respectively.

Any file you mount at **/opt/www** must be readable by that user; as well as any particular configuration you mount under **/etc/nginx/proxy.d** or **/etc/nginx/rewrite.d**.

Configuration
-------------

The nginx server can be configured using environment variables to proxy different locations to different backend servers. The container recognizes the following environment variables patterns:

  - PROXY_DOCROOT = *PATH*: The path to the document root folder, */opt/www* by default.
  - PROXY_LOCATION_*xxx* = *URL*: proxies any request under /*xxx* to *URL/xxx*
  - PROXY_LOCATION_*xxx* = *URL;PATH*: tries to serve any request under /*xxx* with static files from *PATH*. If no file is found, proxies the request to *URL/xxx*
  - PROXY_LOCATION_*xxx* = *;PATH*: Serves request with static content under *PATH*

for instance,

  - PROXY_LOCATION_REMOTE="http://other.server:3000" will forward any request under */remote* to *http://other.server:3000/remote*
  - PROXY_LOCATION_CONFIG="http://other.server:3000;/opt/www" will try to serve any request under */config* with static files in */opt/www*, and fallback to *http://other.server:3000/config* if no static file is found.
  - PROXY_LOCATION_AUTH=;/opt/www/auth/test will serve requests to */auth* with static resources under */opt/www/auth/test*

You can also use an empty location (*PROXY_LOCATION_=...*) to proxy requests to the root location (*/*).

Additional config
-----------------

If you need more advanced proxy settings, you can drop a configuration file ending in *.conf* inside **/etc/nginx/proxy.d** or **/etc/nginx/rewrite.d**, and they will be read at startup.

The difference between those locations is that files in **rewrite.d** are read before files in **proxy.d**. This is intended to make sure that rewrite configuration happens before location configuration, so the locations already receive the rewritten URLs.

For instance, this config uses [resolvers](http://nginx.org/en/docs/http/ngx_http_core_module.html#resolver) and variables to dynamically build and resolve the backend server's URL:

```
chromebox:~/rproxy$ cat dispatch.conf 

# Match your parameters in the URI
location ~ ^/dispatch/(?P<tenant>[a-zA-Z0-9\-]+)/(?P<command>.*)$ {

    # Set your DNS resolver - required
    resolver 8.8.8.8;

    # Rewrite your proxy URL
    set $full_url "http://${tenant}.domain.com/${command}${is_args}${args}";

    # Set any proxy parameters you wish
    proxy_http_version          1.1;
    proxy_pass_request_headers  on;
    proxy_redirect              off;
    proxy_connect_timeout       5s;
    proxy_request_buffering     off;

    # Proxy the request to the dynamic server
    proxy_pass                  $full_url;
    break;
}
```

Couple this with a dns resolver with dynamic backends, such as [powerdns](https://www.powerdns.com/), and you can have a poor man's database-backed reverse proxy.

