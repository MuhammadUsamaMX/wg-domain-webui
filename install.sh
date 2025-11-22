#!/bin/bash
#
# WG-Domain Routing Web UI - Auto Installer
# This script automatically installs and configures the application
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local/wg-domain-webui"
REPO_URL="https://github.com/MuhammadUsamaMX/wg-domain-webui.git"
BRANCH="main"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}WG-Domain Routing Web UI - Installer${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if Debian/Ubuntu
if ! command -v apt-get &> /dev/null; then
    echo -e "${RED}Error: This script is designed for Debian/Ubuntu systems${NC}"
    exit 1
fi

# Check for required commands
echo -e "${YELLOW}[1/8] Checking prerequisites...${NC}"
for cmd in git python3 pip3 wg nft; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${YELLOW}Installing $cmd...${NC}"
        if [ "$cmd" = "wg" ]; then
            apt-get update
            apt-get install -y wireguard wireguard-tools
        elif [ "$cmd" = "nft" ]; then
            apt-get update
            apt-get install -y nftables
        elif [ "$cmd" = "pip3" ]; then
            apt-get update
            apt-get install -y python3-pip
        fi
    fi
done
echo -e "${GREEN}✓ Prerequisites checked${NC}"
echo ""

# Clone or download repository
echo -e "${YELLOW}[2/8] Downloading application...${NC}"
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

if command -v git &> /dev/null; then
    git clone -b "$BRANCH" "$REPO_URL" wg-domain-webui
else
    echo -e "${YELLOW}Git not available, downloading zip...${NC}"
    apt-get install -y wget unzip
    wget -q "https://github.com/MuhammadUsamaMX/wg-domain-webui/archive/refs/heads/$BRANCH.zip" -O repo.zip
    unzip -q repo.zip
    mv "wg-domain-webui-$BRANCH" wg-domain-webui
fi

echo -e "${GREEN}✓ Application downloaded${NC}"
echo ""

# Install Python dependencies
echo -e "${YELLOW}[3/8] Installing Python dependencies...${NC}"
cd wg-domain-webui
pip3 install --break-system-packages -q -r requirements.txt || pip3 install -q -r requirements.txt
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Copy application to system directory
echo -e "${YELLOW}[4/8] Installing application...${NC}"
mkdir -p "$INSTALL_DIR"
cp -r * "$INSTALL_DIR/" 2>/dev/null || cp -r . "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/*.sh
echo -e "${GREEN}✓ Application installed to $INSTALL_DIR${NC}"
echo ""

# Install manager script
echo -e "${YELLOW}[5/8] Installing manager script...${NC}"
cp "$INSTALL_DIR/wg-domain-manager.sh" /usr/local/bin/
chmod +x /usr/local/bin/wg-domain-manager.sh
echo -e "${GREEN}✓ Manager script installed${NC}"
echo ""

# Create domains directory
echo -e "${YELLOW}[6/8] Creating configuration directories...${NC}"
mkdir -p /etc/wg-domain
touch /etc/wg-domain/domains.txt
chmod 644 /etc/wg-domain/domains.txt
echo -e "${GREEN}✓ Configuration directories created${NC}"
echo ""

# Setup nftables and routing
echo -e "${YELLOW}[7/8] Configuring nftables and routing...${NC}"
if [ -f "$INSTALL_DIR/setup_nftables.sh" ]; then
    bash "$INSTALL_DIR/setup_nftables.sh"
    echo -e "${GREEN}✓ Nftables configured${NC}"
else
    echo -e "${YELLOW}⚠ Warning: setup_nftables.sh not found, skipping nftables setup${NC}"
fi
echo ""

# Install systemd services
echo -e "${YELLOW}[8/8] Installing systemd services...${NC}"
cp "$INSTALL_DIR/wg-domain-webui.service" /etc/systemd/system/
cp "$INSTALL_DIR/wg-domain-update.service" /etc/systemd/system/
cp "$INSTALL_DIR/wg-domain-update.timer" /etc/systemd/system/

systemctl daemon-reload
systemctl enable wg-domain-webui.service
systemctl enable wg-domain-update.timer
systemctl start wg-domain-webui.service
systemctl start wg-domain-update.timer

echo -e "${GREEN}✓ Systemd services installed and started${NC}"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"

# Check WireGuard configuration
echo -e "${YELLOW}Checking WireGuard configuration...${NC}"
if [ -f /etc/wireguard/wg0.conf ]; then
    if grep -q "AllowedIPs = 0.0.0.0/0" /etc/wireguard/wg0.conf; then
        echo -e "${YELLOW}⚠ Warning: WireGuard is configured to route all traffic (0.0.0.0/0)${NC}"
        echo -e "${YELLOW}  For domain-only routing, change AllowedIPs to your VPN subnet (e.g., 10.8.0.0/24)${NC}"
        echo -e "${YELLOW}  Edit: /etc/wireguard/wg0.conf${NC}"
    fi
    
    if grep -q "^DNS" /etc/wireguard/wg0.conf; then
        echo -e "${YELLOW}⚠ Warning: WireGuard has DNS configured${NC}"
        echo -e "${YELLOW}  For domain-only routing, remove DNS line to use system DNS${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Warning: WireGuard config not found at /etc/wireguard/wg0.conf${NC}"
    echo -e "${YELLOW}  Please configure WireGuard before using domain routing${NC}"
fi
echo ""

# Final status
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Web UI: http://127.0.0.1:8877"
echo ""
echo "Service Status:"
systemctl is-active wg-domain-webui.service > /dev/null && \
    echo -e "  ${GREEN}✓ Web UI: Active${NC}" || \
    echo -e "  ${RED}✗ Web UI: Inactive${NC}"

systemctl is-active wg-domain-update.timer > /dev/null && \
    echo -e "  ${GREEN}✓ Update Timer: Active${NC}" || \
    echo -e "  ${RED}✗ Update Timer: Inactive${NC}"
echo ""
echo "Next Steps:"
echo "  1. Access the web UI at http://127.0.0.1:8877"
echo "  2. Add domains you want to route through VPN"
echo "  3. Click 'Update Now' to resolve domain IPs"
echo "  4. Verify routing is working"
echo ""
echo "To make configuration persistent:"
echo "  sudo $INSTALL_DIR/make_persistent.sh"
echo ""

