# WordPress + Nginx + Certbot Stack

A self-contained Docker Compose stack for running WordPress behind Nginx, with TLS certificates issued and renewed automatically by Certbot using the Cloudflare DNS-01 challenge. The setup assumes the domain sits behind Cloudflare with the proxy (orange cloud) enabled.

## Services

| Service    | Role                                                              |
|------------|--------------------------------------------------------------------|
| nginx      | Terminates TLS, serves static files, proxies PHP to WordPress      |
| wordpress  | PHP-FPM process running WordPress                                   |
| db         | MariaDB database                                                    |
| phpmyadmin | Database administration UI, reachable at `/phpmyadmin/`             |
| certbot    | Issues and renews the Let's Encrypt certificate via Cloudflare DNS  |

## Prerequisites

- A VPS with Docker Engine and the Docker Compose plugin installed.
- A domain managed in Cloudflare DNS.
- A Cloudflare API token scoped to `Zone:DNS:Edit` for the target zone only.
- Ports 80 and 443 open on the VPS firewall.

## Project structure

```
wordpress-stack/
├── docker-compose.yml
├── .env.example
├── nginx/
│   └── templates/
│       └── default.conf.template
└── certbot/
    └── entrypoint.sh
```

## How to configure

1. Copy the environment template and edit it:
   ```
   cp .env.example .env
   ```
2. Fill in `.env` with real values: `DOMAIN`, `EMAIL`, `CF_API_TOKEN`, and the `MYSQL_*` credentials. Do not commit this file.
3. Create the Cloudflare API token: in the Cloudflare dashboard, go to My Profile > API Tokens > Create Token, use the "Edit zone DNS" template, and restrict it to the specific zone for this domain.
4. In Cloudflare DNS, create A records for the apex domain and `www` pointing to the VPS IP address, with the proxy status set to Proxied (orange cloud).
5. In Cloudflare SSL/TLS settings, set the encryption mode to Full (strict). Visitors may see a brief error until the first certificate is issued in the deployment step below; this resolves itself once Nginx starts.

## How to deploy

1. Copy the project directory to the VPS, or clone the repository, so that `docker-compose.yml` and the completed `.env` file are in the same directory.
2. Start the stack:
   ```
   docker compose up -d
   ```
3. Watch the certificate issuance:
   ```
   docker compose logs -f certbot
   ```
   Nginx stays in a waiting loop and prints `Waiting for SSL certificate...` until the first certificate exists, then starts automatically.
4. Confirm the site loads at `https://DOMAIN` and that WordPress presents its setup screen on first visit.
5. Complete the WordPress installation wizard to create the admin account.

## Maintenance

- **Renewals**: the certbot container renews the certificate automatically in the background. No manual action is required under normal operation.
- **Updating images**:
  ```
  docker compose pull
  docker compose up -d
  ```
- **Database backup**:
  ```
  docker compose exec db mariadb-dump -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" > backup.sql
  ```
- **File backup**: back up the `wordpress_data` volume (uploads, themes, plugins) on a regular schedule, for example with a cron job that runs `docker run --rm -v wordpress-stack_wordpress_data:/data -v $(pwd):/backup alpine tar czf /backup/wordpress_data.tar.gz -C /data .`

## Troubleshooting

### Certbot errors

- **`DNS problem: NXDOMAIN looking up TXT record`**: the domain in `DOMAIN` does not match the zone the API token can edit, or the zone is not active in Cloudflare. Confirm the domain is added to the Cloudflare account and the token targets the correct zone.
- **`403 Forbidden` from the Cloudflare API**: the token lacks `Zone:DNS:Edit` permission, or it is scoped to the wrong zone. Regenerate the token with the correct scope.
- **`too many certificates already issued`**: Let's Encrypt's rate limit for duplicate certificates was reached (five identical certificates per domain set per week). Wait for the limit to reset, or add `--staging` to the `certbot certonly` command in `certbot/entrypoint.sh` while testing, then remove it for the real certificate.
- **Nginx stuck on "Waiting for SSL certificate..."**: check `docker compose logs certbot` for the underlying error. Because the script uses `set -e`, a failed `certonly` call stops the container, and `restart: unless-stopped` restarts it to retry. Nginx remains in its wait loop until issuance succeeds.

### Cloudflare IP ranges change over time

The `default.conf.template` file lists Cloudflare's IP ranges under `set_real_ip_from` so that Nginx logs the visitor's real IP instead of Cloudflare's. Cloudflare updates this list occasionally. If visitor IPs in WordPress (comments, security plugins, rate limiting) all appear to come from the same small set of addresses, the list is outdated. Fetch the current ranges from https://www.cloudflare.com/ips/, update the template, and restart the nginx container.

### 502 Bad Gateway

Usually means the `wordpress` container is not ready or has crashed. Check `docker compose logs wordpress`.

### 525 or 526 errors shown by Cloudflare

These indicate Cloudflare could not validate the origin certificate. This is expected for the short window before the first certificate is issued. If it persists, confirm the certbot container completed successfully and that the certificate files exist under the `certbot_conf` volume.

## Security recommendations

- Change the default database passwords in `.env` before the first `docker compose up`, since WordPress uses them to initialize the database on first run.
- Restrict access to `/phpmyadmin/` in `default.conf.template` using the commented `allow`/`deny` lines, or remove the `phpmyadmin` service entirely if it is not needed after initial setup.
- Keep all images updated periodically to receive security patches.
- Consider adding a Cloudflare WAF rule or rate limit on `wp-login.php` and `xmlrpc.php` to reduce brute-force login attempts.
- Rotate the Cloudflare API token periodically, and keep its scope limited to the single zone used by this stack.