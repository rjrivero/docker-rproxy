#!/usr/bin/env bash
# Add proxy lines to /etc/nginx/proxy.conf

# Create proxy config dir
mkdir -p /etc/nginx/proxy

export IFS='
'

function proxy {

# Proxy URL
cat >> /etc/nginx/proxy.conf <<EOF
location /$_PREFIX {
    proxy_http_version         1.1;
    proxy_pass_request_headers on;
    
    # La cabecera HOST no va incluida en el proxy_pass_request_headers,
    # Por lo que he podido comprobar... la meto a mano.
    proxy_set_header Host \$http_host;
    proxy_pass $_URL;
    proxy_redirect off;
    break;
}
EOF

}

function proxy_with_static {

# Special-case the root location
if [ -z "$_PREFIX" ]; then
    export _BACKEND="ROOT"
    export _DOCROOT="root"    
else
    export _BACKEND="$_PREFIX"
    export _DOCROOT="alias"    
fi

# Proxy URL with static content as fallback
cat >> /etc/nginx/proxy.conf <<EOF
location @$_BACKEND {
    proxy_http_version         1.1;
    proxy_pass_request_headers on;

    # La cabecera HOST no va incluida en el proxy_pass_request_headers,
    # Por lo que he podido comprobar... la meto a mano.
    proxy_set_header Host \$http_host;
    proxy_pass $_URL;
    proxy_redirect off;
    break;
}

location /$_PREFIX {
    $_DOCROOT $_PATH;
    try_files \$uri \$uri/ @$_BACKEND;
}
EOF

}

for i in `env | grep PROXY_LOCATION_`; do

    # Get environment variables names and values
    export _NAM=`echo "${i}" | cut -d '=' -f 1`
    export _VAL=`echo "${i}" | cut -d '=' -f 2`

    # xargs to trim whitespaces
    # tr to translate uppercase to lowercase
    export _PREFIX=`echo ${_NAM} | sed 's/PROXY_LOCATION_//' | tr '[:upper:]' '[:lower:]' | xargs`
    export _URL=`echo ${_VAL} | cut -d ";" -f 1 | xargs`
    export _PATH=`echo ${_VAL} | cut -s -d ";" -f 2 | xargs`

    # Show what we are doing...
    echo _PREFIX: $_PREFIX
    echo _URL: $_URL
    echo _PATH: $_PATH

    # Dump proxy config
    if [ -z "$_PATH" ]; then
        proxy
    else
        proxy_with_static
    fi

done

exec /usr/sbin/nginx -g "daemon off;"
