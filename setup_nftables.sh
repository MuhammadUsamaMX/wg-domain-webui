#!/bin/bash
#
# Setup nftables rules for domain-based WireGuard routing
# This script creates the necessary nftables sets and rules
#

set -e

echo "Setting up nftables for domain-based routing..."

# Create inet filter table if it doesn't exist
if ! nft list table inet filter &>/dev/null; then
    echo "Creating inet filter table..."
    nft create table inet filter
fi

# Create IPv4 domain set in both filter and mangle tables
for table in filter mangle; do
    if ! nft list set inet $table domlist4 &>/dev/null; then
        echo "Creating domlist4 set in $table table..."
        nft create set inet $table domlist4 { type ipv4_addr\; flags interval\; }
    else
        echo "domlist4 set already exists in $table table"
    fi
done

# Create IPv6 domain set in both filter and mangle tables
for table in filter mangle; do
    if ! nft list set inet $table domlist6 &>/dev/null; then
        echo "Creating domlist6 set in $table table..."
        nft create set inet $table domlist6 { type ipv6_addr\; flags interval\; }
    else
        echo "domlist6 set already exists in $table table"
    fi
done

# Ensure routing table is defined
if ! grep -q "wg_route" /etc/iproute2/rt_tables 2>/dev/null; then
    echo "Adding wg_route to rt_tables..."
    echo "200 wg_route" >> /etc/iproute2/rt_tables
fi

# Create routing table for WireGuard (use table 200)
if ! ip route show table 200 &>/dev/null 2>&1; then
    echo "Creating wg_route routing table (200)..."
    # Get default gateway for fallback
    DEFAULT_GW=$(ip route | grep default | head -1 | awk '{print $3}')
    DEFAULT_IF=$(ip route | grep default | head -1 | awk '{print $5}')
    
    # Route marked domain traffic through WireGuard interface
    ip route add default dev wg0 table 200 2>/dev/null || true
    # Add WireGuard subnet
    ip route add 10.8.0.0/24 dev wg0 table 200 2>/dev/null || true
    
    # Add default gateway as fallback (for non-domain traffic)
    if [ -n "$DEFAULT_GW" ] && [ -n "$DEFAULT_IF" ]; then
        ip route add default via "$DEFAULT_GW" dev "$DEFAULT_IF" table 200 2>/dev/null || true
    fi
fi

# Create routing rule for marked packets (mark 0x1 = 1)
if ! ip rule show | grep -q "fwmark 0x1 lookup 200"; then
    echo "Creating routing rule for marked packets..."
    ip rule add fwmark 0x1 table 200
fi

# Create mangle table for packet marking (must happen before routing)
if ! nft list table inet mangle &>/dev/null; then
    echo "Creating inet mangle table..."
    nft create table inet mangle
fi

# Create OUTPUT chain in mangle table (runs before routing)
if ! nft list chain inet mangle OUTPUT &>/dev/null 2>&1; then
    echo "Creating OUTPUT chain in mangle table..."
    nft create chain inet mangle OUTPUT { type route hook output priority mangle\; }
else
    echo "Flushing existing mangle OUTPUT chain..."
    nft flush chain inet mangle OUTPUT
fi

# Remove any existing rules in filter table if they exist
nft delete chain inet filter OUTPUT 2>/dev/null || true

# Add rules to mark packets matching domain IPs (in mangle table)
echo "Adding nftables rules to mangle table..."
nft add rule inet mangle OUTPUT ip daddr @domlist4 counter mark set 0x1
nft add rule inet mangle OUTPUT ip6 daddr @domlist6 counter mark set 0x1

# Create NAT table for SNAT (source NAT to use WireGuard IP)
if ! nft list table inet nat &>/dev/null; then
    echo "Creating inet nat table..."
    nft create table inet nat
fi

# Create POSTROUTING chain for SNAT
if ! nft list chain inet nat POSTROUTING &>/dev/null 2>&1; then
    echo "Creating POSTROUTING chain in nat table..."
    nft create chain inet nat POSTROUTING { type nat hook postrouting priority srcnat\; }
else
    echo "Flushing existing POSTROUTING chain..."
    nft flush chain inet nat POSTROUTING
fi

# Add SNAT rule to force source IP 10.8.0.5 for packets going through wg0
echo "Adding SNAT rule for WireGuard interface..."
nft add rule inet nat POSTROUTING oif wg0 ip saddr 192.168.0.0/16 snat to 10.8.0.5
nft add rule inet nat POSTROUTING oif wg0 ip saddr 192.168.5.0/24 snat to 10.8.0.5

# Ensure routes are in place (WireGuard should be primary route for marked packets)
# Always ensure table 200 has routes (they may be lost on interface restart)
echo "Ensuring routing table 200 has WireGuard routes..."
# Remove any existing default route first
ip route del default table 200 2>/dev/null || true
# Add WireGuard as default route for marked packets with correct source IP
ip route add default dev wg0 table 200 src 10.8.0.5 2>/dev/null || true
ip route add 10.8.0.0/24 dev wg0 table 200 2>/dev/null || true

echo ""
echo "Nftables setup complete!"
echo "Sets created: domlist4, domlist6"
echo "Rules created: Mark packets matching domain IPs"
echo "Routing table: 200 (wg_route)"
echo ""
echo "To verify:"
echo "  nft list table inet filter"
echo "  ip rule show"
echo "  ip route show table 200"

