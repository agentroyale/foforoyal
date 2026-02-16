#!/bin/bash
set -euo pipefail

# Setup nginx + HTTPS for chibiroyale.xyz website.
# Run as root on the droplet AFTER setup-server.sh.
# Usage: bash setup-website.sh

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

DOMAIN="chibiroyale.xyz"
WEBROOT="/var/www/chibiroyale"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Website Setup for ${DOMAIN} ==="

# 1. Install nginx and certbot
echo "Installing nginx and certbot..."
apt-get update -qq
apt-get install -y -qq nginx certbot python3-certbot-nginx

# 2. Create webroot
mkdir -p "${WEBROOT}"
echo "<h1>Setting up...</h1>" > "${WEBROOT}/index.html"

# 3. Open firewall ports
echo "Opening HTTP/HTTPS ports..."
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"
ufw status

# 4. Setup initial nginx config (HTTP only, for certbot)
cat > /etc/nginx/sites-available/chibiroyale <<NGINX
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    root ${WEBROOT};
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/chibiroyale /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# 5. Get SSL certificate
echo "Obtaining SSL certificate..."
certbot --nginx -d "${DOMAIN}" -d "www.${DOMAIN}" --non-interactive --agree-tos --email admin@${DOMAIN} --redirect

# 6. Install full nginx config with SSL
cp "${SCRIPT_DIR}/nginx.conf" /etc/nginx/sites-available/chibiroyale
nginx -t && systemctl reload nginx

# 7. Setup auto-renewal
echo "Setting up certificate auto-renewal..."
systemctl enable certbot.timer
systemctl start certbot.timer

echo ""
echo "=== Website setup complete ==="
echo "Deploy files with: ./deploy.sh --website root@$(hostname -I | awk '{print $1}')"
echo "Site will be live at: https://${DOMAIN}"
