#!/bin/bash
#
# Make WG-Domain Routing configuration persistent across reboots
# Run this script AFTER verifying everything works correctly
#

set -e

echo "Making WG-Domain Routing configuration persistent..."
echo ""
echo "⚠️  WARNING: This will make the current configuration permanent!"
echo "   Make sure you have verified everything works correctly first."
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# 1. Save nftables rules
echo "1. Saving nftables rules..."
echo "1318" | sudo -S nft list ruleset > /tmp/nftables_ruleset.nft
echo "1318" | sudo -S cp /tmp/nftables_ruleset.nft /etc/nftables.conf
echo "1318" | sudo -S systemctl enable nftables.service
echo "   ✓ Nftables rules saved to /etc/nftables.conf"

# 2. Enable WireGuard on boot
echo "2. Enabling WireGuard on boot..."
echo "1318" | sudo -S systemctl enable wg-quick@wg0.service
echo "   ✓ WireGuard will start on boot"

# 3. Save routing table configuration
echo "3. Creating routing persistence script..."
cat > /tmp/wg-route-setup.sh << 'EOF'
#!/bin/bash
# Restore routing table 200 on boot

# Ensure routing table is defined
if ! grep -q "wg_route" /etc/iproute2/rt_tables 2>/dev/null; then
    echo "200 wg_route" >> /etc/iproute2/rt_tables
fi

# Wait for WireGuard interface
sleep 2
while ! ip link show wg0 &>/dev/null; do
    sleep 1
done

# Create routing table for WireGuard
ip route add default dev wg0 table 200 2>/dev/null || true
ip route add 10.8.0.0/24 dev wg0 table 200 2>/dev/null || true

# Create routing rule for marked packets
if ! ip rule show | grep -q "fwmark 0x1 lookup 200"; then
    ip rule add fwmark 0x1 table 200
fi
EOF

echo "1318" | sudo -S cp /tmp/wg-route-setup.sh /usr/local/bin/wg-route-setup.sh
echo "1318" | sudo -S chmod +x /usr/local/bin/wg-route-setup.sh

# Create systemd service for routing setup
cat > /tmp/wg-route-setup.service << 'EOF'
[Unit]
Description=WG-Domain Routing Table Setup
After=network.target wg-quick@wg0.service
Requires=wg-quick@wg0.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wg-route-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "1318" | sudo -S cp /tmp/wg-route-setup.service /etc/systemd/system/
echo "1318" | sudo -S systemctl daemon-reload
echo "1318" | sudo -S systemctl enable wg-route-setup.service
echo "   ✓ Routing table setup service created"

# 4. Verify WireGuard config
echo "4. Verifying WireGuard configuration..."
if ! echo "1318" | sudo -S grep -q "AllowedIPs = 10.8.0.0/24" /etc/wireguard/wg0.conf; then
    echo "   ⚠️  WARNING: WireGuard config may not be set to domain-only mode!"
    echo "      Current AllowedIPs:"
    echo "1318" | sudo -S grep "AllowedIPs" /etc/wireguard/wg0.conf || echo "      Not found"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  PERSISTENCE CONFIGURATION COMPLETE"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Enabled services:"
echo "  ✓ nftables.service"
echo "  ✓ wg-quick@wg0.service"
echo "  ✓ wg-route-setup.service"
echo ""
echo "Configuration files:"
echo "  ✓ /etc/nftables.conf (nftables rules)"
echo "  ✓ /etc/wireguard/wg0.conf (WireGuard config)"
echo "  ✓ /usr/local/bin/wg-route-setup.sh (routing setup)"
echo ""
echo "To test persistence, reboot the system."
echo "After reboot, verify with:"
echo "  sudo systemctl status wg-quick@wg0"
echo "  sudo nft list table inet mangle"
echo "  sudo ip rule show | grep 0x1"
echo ""

