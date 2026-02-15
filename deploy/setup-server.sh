#!/bin/bash
set -euo pipefail

# Provisioning script for NovoJogo dedicated server.
# Run once as root on a fresh Ubuntu 24.04 Droplet (Sao Paulo).
# Usage: bash setup-server.sh

GODOT_VERSION="4.6-stable"
GODOT_FILENAME="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_FILENAME}.zip"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

echo "=== NovoJogo Server Setup ==="

# 1. Create novojogo user (no login shell)
if ! id -u novojogo &>/dev/null; then
    useradd --system --shell /usr/sbin/nologin --home-dir /opt/novojogo novojogo
    echo "Created user: novojogo"
else
    echo "User novojogo already exists"
fi

# 2. Install Godot headless
mkdir -p /opt/godot
if [[ ! -f /opt/godot/godot-4 ]]; then
    echo "Downloading Godot ${GODOT_VERSION}..."
    apt-get update -qq && apt-get install -y -qq unzip wget
    cd /tmp
    wget -q "${GODOT_URL}" -O godot.zip
    unzip -o godot.zip
    mv "${GODOT_FILENAME}" /opt/godot/godot-4
    chmod +x /opt/godot/godot-4
    ln -sf /opt/godot/godot-4 /usr/local/bin/godot-4
    rm -f godot.zip
    echo "Godot installed: $(godot-4 --version)"
else
    echo "Godot already installed: $(/opt/godot/godot-4 --version)"
fi

# 3. Create project and log directories
mkdir -p /opt/novojogo/godot
mkdir -p /var/log/novojogo
chown -R novojogo:novojogo /opt/novojogo
chown -R novojogo:novojogo /var/log/novojogo

# 4. Configure UFW firewall
echo "Configuring firewall..."
apt-get install -y -qq ufw
ufw allow 22/tcp comment "SSH"
ufw allow 27015/udp comment "NovoJogo game server"
ufw --force enable
ufw status

# 5. Install systemd service
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "${SCRIPT_DIR}/novojogo.service" /etc/systemd/system/novojogo.service
systemctl daemon-reload
systemctl enable novojogo
echo "Systemd service installed and enabled"

# 6. Start service (will fail until first deploy, that's OK)
if systemctl start novojogo 2>/dev/null; then
    echo "Service started"
else
    echo "Service not started yet (deploy project files first with deploy.sh)"
fi

echo ""
echo "=== Setup complete ==="
echo "Next: run deploy.sh from your dev machine to push project files."
