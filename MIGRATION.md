# Migrating from dev.artrishmoon.es to artrishmoon.es

Reference checklist for cutting over from the temporary development subdomain to the production domain. Follow the steps in order.

## Before starting

- [ ] Confirm the site content, theme, and plugins are final on `dev.artrishmoon.es`.
- [ ] Take a database backup and a `wordpress_data` volume backup (see README.md, Maintenance section).

## 1. Add DNS records for the production domain

- [ ] In Cloudflare DNS, add an A record for the apex domain (`artrishmoon.es`) pointing to the VPS IP address.
- [ ] Add an A record for `www` pointing to the same IP address.
- [ ] Set both records to Proxied (orange cloud).

## 2. Point the stack at the new domain

- [ ] On the VPS, edit `.env` and change `DOMAIN=dev.artrishmoon.es` to `DOMAIN=artrishmoon.es`.
- [ ] Apply the change:
  ```
  docker compose up -d
  ```
- [ ] Watch certificate issuance for the new domain:
  ```
  docker compose logs -f certbot
  ```
- [ ] Confirm `https://artrishmoon.es` loads once nginx exits its waiting loop.

## 3. Update the WordPress site URL

- [ ] Open phpMyAdmin and select the `wp_options` table.
- [ ] Update the `siteurl` row value to `https://artrishmoon.es`.
- [ ] Update the `home` row value to `https://artrishmoon.es`.

## 4. Replace remaining references to the old domain

- [ ] Install the "Better Search Replace" plugin from wp-admin, or use WP-CLI if available.
- [ ] Run a search and replace across all tables: `dev.artrishmoon.es` -> `artrishmoon.es`.
- [ ] Review the dry-run results before applying, since this changes serialized data.

## 5. Verify the production site

- [ ] Browse the site as a logged-out visitor and check the homepage, a post, and an image load correctly.
- [ ] Confirm internal links point to `artrishmoon.es`, not the old subdomain.
- [ ] Log in to wp-admin and confirm it works normally.

## 6. Clean up the development subdomain

- [ ] In Cloudflare DNS, delete the A record for `dev`.
- [ ] Remove the unused certificate lineage. The `--entrypoint` override is required because the `certbot` service normally runs the renewal loop defined in `docker-compose.yml`, not the plain `certbot` binary:
  ```
  docker compose run --rm --entrypoint certbot certbot delete --cert-name dev.artrishmoon.es
  ```