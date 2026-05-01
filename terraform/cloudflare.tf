# ── Cloudflare DNS + Worker proxy ────────────────────────────────────────────
#
# Problem: Cloudflare proxy sends Host: vincentlelaverda.com to Azure Storage,
# but Azure Storage static website only accepts its own hostname as Host header.
# Result: InvalidUri 400.
#
# Solution: a Cloudflare Worker intercepts every request and rewrites the Host
# header to the Azure Storage web endpoint before forwarding.
#
#   Browser → Cloudflare Worker → Azure Storage (Host: stvincentcv.z7.web...)
#
# The Worker runs on Cloudflare's edge — free tier covers 100k requests/day.
#
# This gives us for free:
#   - Universal SSL certificate for your custom domain (auto-renewed)
#   - Global CDN (300+ edge nodes)
#   - HTTP → HTTPS redirect
#   - DDoS protection
#   - Compression (Brotli/gzip)
#
# Prerequisites (done once manually in the Cloudflare dashboard):
#   1. Register a domain (e.g. at Namecheap ~$10/year)
#   2. Add it to Cloudflare (free plan)
#   3. Point your registrar's nameservers to Cloudflare's
#   4. Copy your Zone ID from the Cloudflare dashboard → paste in variables
#

# ── CNAME record — root domain (@) ───────────────────────────────────────────
#
# A CNAME record is an alias: it says "this domain name = that hostname".
# Here: vincentlelaverda.com → stvincentcv.z13.web.core.windows.net
#
# Normally DNS does not allow CNAME on the root/apex domain (@).
# Cloudflare solves this with "CNAME Flattening": it resolves the CNAME
# to an IP address at query time and serves an A record instead.
# The browser never sees the CNAME — it just gets the right IP.
#
# `proxied = true` = the orange cloud in Cloudflare UI.
# Traffic goes through Cloudflare's servers (HTTPS + CDN enabled).
# `proxied = false` = DNS only — Cloudflare just resolves the IP, no proxy.
#
resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@" # root domain: vincentlelaverda.com
  content = azurerm_storage_account.cv.primary_web_host
  type    = "CNAME"
  ttl     = 1       # 1 = "Auto" when proxied = true
  proxied = true    # enables HTTPS + CDN
}

# ── CNAME record — www subdomain ──────────────────────────────────────────────
#
# A second record so www.vincentlelaverda.com also works.
# Points to the same Azure Storage endpoint.
#
resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  content = azurerm_storage_account.cv.primary_web_host
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# ── Zone settings ─────────────────────────────────────────────────────────────
#
# Configure security and performance settings at the Cloudflare zone level.
# These apply to all traffic going through Cloudflare for your domain.
#
resource "cloudflare_zone_settings_override" "cv" {
  zone_id = var.cloudflare_zone_id

  settings {
    # SSL mode: "full" = both legs (browser→CF and CF→Storage) are encrypted.
    # Azure Storage has a valid Microsoft certificate on *.web.core.windows.net
    # so Cloudflare can verify it. Do NOT use "flexible" — it would leave the
    # Cloudflare→Storage leg unencrypted despite showing a padlock to the user.
    ssl = "full"

    # Force all HTTP traffic to HTTPS (Cloudflare-side redirect before
    # the request even reaches Azure Storage)
    always_use_https = "on"

    # Minimum TLS version accepted by Cloudflare from browsers
    min_tls_version = "1.2"

    # Opportunistic Encryption: advertise HTTPS support via DNS even for
    # HTTP requests, nudging browsers to upgrade automatically
    opportunistic_encryption = "on"

    # Compress responses with Brotli (more efficient than gzip for HTML/CSS/JS)
    brotli = "on"

    # Cache level: cache everything (suitable for a fully static site)
    cache_level = "aggressive"

    # Browser cache TTL: browsers keep files cached for 4 hours locally.
    # When you update your CV, purge the Cloudflare cache to push changes.
    browser_cache_ttl = 14400
  }
}

# ── Cloudflare Worker script ──────────────────────────────────────────────────
#
# The Worker is a JavaScript function that runs on Cloudflare's edge servers.
# It intercepts requests to your domain and rewrites the Host header before
# forwarding to Azure Storage — fixing the InvalidUri 400 error.
#
resource "cloudflare_worker_script" "cv" {
  account_id = var.cloudflare_account_id
  name       = "cv-proxy"
  content    = file("${path.module}/worker.js")
}

# ── Worker routes ─────────────────────────────────────────────────────────────
#
# A route tells Cloudflare which URL patterns trigger the Worker.
# We need two routes: one for the root domain and one for www.
# The /* pattern matches all paths (/, /index.html, etc.)
#
resource "cloudflare_worker_route" "root" {
  zone_id     = var.cloudflare_zone_id
  pattern     = "${var.domain_name}/*"
  script_name = cloudflare_worker_script.cv.name
}

resource "cloudflare_worker_route" "www" {
  zone_id     = var.cloudflare_zone_id
  pattern     = "www.${var.domain_name}/*"
  script_name = cloudflare_worker_script.cv.name
}
