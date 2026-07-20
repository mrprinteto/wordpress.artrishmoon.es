#!/bin/sh
set -e

CRED_FILE=/tmp/cloudflare.ini
printf 'dns_cloudflare_api_token = %s\n' "$CF_API_TOKEN" > "$CRED_FILE"
chmod 600 "$CRED_FILE"

if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
  certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials "$CRED_FILE" \
    --dns-cloudflare-propagation-seconds 30 \
    -d "$DOMAIN" -d "www.$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive
fi

trap exit TERM
while true; do
  certbot renew \
    --dns-cloudflare \
    --dns-cloudflare-credentials "$CRED_FILE" \
    --quiet
  sleep 12h &
  wait $!
done