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

function special_case_docroot {

  # When serving static content for location / , it is better to use "docroot"
  if [ -z "$_PREFIX" ]; then
    export _BACKEND="ROOT"
    export _DOCROOT="root"    
  # If the location is not /, on the other hand, better to use "alias"
  else
    export _BACKEND="$_PREFIX"
    export _DOCROOT="alias"    
  fi

}

function proxy_with_static {

  # Proxy URL with static content as fallback
  special_case_docroot
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

function just_static_location {

  # Just add a location for static content
  special_case_docroot
  cat >> /etc/nginx/proxy.conf <<EOF

location /$_PREFIX {
    $_DOCROOT $_PATH;
    try_files \$uri \$uri/ /;
}
EOF

}

# The ASCII code for "=" is lower than the ASCI code for a ... z A ... Z,
# so sorting in descending order grants that PROXY_LOCATION_ANYTHING=
# always goes before PROXY_LOCATION_= (the root location).
# Beware that 0-9 go before "=" in the ASCII table, so if you have both a
# root location and a location starting with a digit, then the former
# will appear in the configuration file before the later. I am not sure
# that it would work as expected.
for i in `env | grep PROXY_LOCATION_ | sort -r`; do

    # Get environment variables names and values
    export _NAM=`echo "${i}" | cut -d '=' -f 1`
    export _VAL=`echo "${i}" | cut -d '=' -f 2`

    # xargs to trim whitespaces
    # tr to translate uppercase to lowercase
    export _PREFIX=`echo ${_NAM} | sed 's/PROXY_LOCATION_//' | tr '[:upper:]' '[:lower:]' | sed 's/_/\//g' | xargs`
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
        if [ -z "$_URL" ]; then
            just_static_location
        else
            proxy_with_static
        fi
    fi

done

# If PROXY_DOCROOT specified, change root dir
if [ ! -z "$PROXY_DOCROOT" ]; then
    export ESC_DOCROOT=`echo "${PROXY_DOCROOT}" | sed -e 's/\\//\\\\\//g'`
    sed -i "s/root.*opt.www;/root ${ESC_DOCROOT};/" \
        /etc/nginx/conf.d/default.conf
fi

exec /usr/sbin/nginx -g "daemon off;"
