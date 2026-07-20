#!/bin/sh
set -e

# Render the template ourselves. The image's built-in entrypoint only does
# this when the container command is literally "nginx", which does not
# apply here since this script waits for the certificate first.
envsubst '${DOMAIN}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

# nginx must not start with an ssl_certificate directive pointing to a
# file that does not exist yet, so wait for the first certificate.
until [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; do
  echo 'Waiting for SSL certificate...'
  sleep 5
done

exec nginx -g 'daemon off;'