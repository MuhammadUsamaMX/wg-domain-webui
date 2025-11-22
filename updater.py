"""
Updater - Resolves domain IPs and updates nftables sets
"""
import socket
import subprocess
import logging
from typing import List, Set, Tuple
from domain_manager import read_domains

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def resolve_domain(domain: str) -> Tuple[Set[str], Set[str]]:
    """
    Resolve domain to IPv4 and IPv6 addresses.
    Returns (ipv4_set, ipv6_set)
    """
    ipv4_addresses = set()
    ipv6_addresses = set()
    
    try:
        # Get all address info
        addr_infos = socket.getaddrinfo(domain, None, socket.AF_UNSPEC, socket.SOCK_STREAM)
        
        for addr_info in addr_infos:
            addr = addr_info[4][0]
            # Check if IPv4 or IPv6
            try:
                socket.inet_pton(socket.AF_INET, addr)
                ipv4_addresses.add(addr)
            except (OSError, ValueError):
                try:
                    socket.inet_pton(socket.AF_INET6, addr)
                    ipv6_addresses.add(addr)
                except (OSError, ValueError):
                    pass
    except socket.gaierror as e:
        logger.warning(f"Failed to resolve {domain}: {e}")
    
    return ipv4_addresses, ipv6_addresses


def update_nftables_sets(ipv4_addresses: Set[str], ipv6_addresses: Set[str]) -> bool:
    """
    Update nftables sets (domlist4 and domlist6) with resolved IPs.
    Updates both filter and mangle tables.
    Returns True on success, False on failure.
    """
    try:
        # Flush and populate IPv4 set in both filter and mangle tables
        if ipv4_addresses:
            for table in ["filter", "mangle"]:
                # Flush existing set
                subprocess.run(
                    ["nft", "flush", "set", "inet", table, "domlist4"],
                    check=False,
                    capture_output=True
                )
                # Add IPs to set
                for ip in ipv4_addresses:
                    subprocess.run(
                        ["nft", "add", "element", "inet", table, "domlist4", f"{{ {ip} }}"],
                        check=False,
                        capture_output=True
                    )
        
        # Flush and populate IPv6 set in both filter and mangle tables
        if ipv6_addresses:
            for table in ["filter", "mangle"]:
                # Flush existing set
                subprocess.run(
                    ["nft", "flush", "set", "inet", table, "domlist6"],
                    check=False,
                    capture_output=True
                )
                # Add IPs to set
                for ip in ipv6_addresses:
                    subprocess.run(
                        ["nft", "add", "element", "inet", table, "domlist6", f"{{ {ip} }}"],
                        check=False,
                        capture_output=True
                    )
        
        return True
    except Exception as e:
        logger.error(f"Failed to update nftables sets: {e}")
        return False


def update_wireguard_allowedips(ipv4_addresses: Set[str], ipv6_addresses: Set[str]) -> bool:
    """
    Update WireGuard peer's AllowedIPs to include domain IPs.
    Includes the base VPN subnet (10.8.0.0/24) plus all domain IPs.
    Returns True on success, False on failure.
    """
    try:
        # Get current peer public key from WireGuard
        result = subprocess.run(
            ["wg", "show", "wg0", "peers"],
            capture_output=True,
            text=True,
            check=False
        )
        
        if result.returncode != 0:
            logger.warning("Could not get WireGuard peers, skipping AllowedIPs update")
            return False
        
        # Get the first peer's public key
        peer_key = result.stdout.strip().split('\n')[0] if result.stdout.strip() else None
        if not peer_key:
            logger.warning("No WireGuard peer found")
            return False
        
        # Build AllowedIPs list: VPN subnet + domain IPs
        allowed_ips = ["10.8.0.0/24"]  # Base VPN subnet
        
        # Add domain IPs as /32 (single host routes)
        for ip in ipv4_addresses:
            allowed_ips.append(f"{ip}/32")
        
        for ip in ipv6_addresses:
            allowed_ips.append(f"{ip}/128")
        
        # Update WireGuard peer's AllowedIPs
        allowed_ips_str = ",".join(allowed_ips)
        result = subprocess.run(
            ["wg", "set", "wg0", "peer", peer_key, "allowed-ips", allowed_ips_str],
            capture_output=True,
            check=False
        )
        
        if result.returncode == 0:
            logger.info(f"Updated WireGuard AllowedIPs: {len(allowed_ips)} routes")
            return True
        else:
            logger.error(f"Failed to update WireGuard AllowedIPs: {result.stderr.decode()}")
            return False
            
    except Exception as e:
        logger.error(f"Error updating WireGuard AllowedIPs: {e}")
        return False


def update_all_domains() -> dict:
    """
    Resolve all domains and update nftables sets and WireGuard AllowedIPs.
    Returns dict with status and statistics.
    """
    domains = read_domains()
    all_ipv4 = set()
    all_ipv6 = set()
    resolved_count = 0
    failed_domains = []
    
    for domain in domains:
        ipv4, ipv6 = resolve_domain(domain)
        if ipv4 or ipv6:
            all_ipv4.update(ipv4)
            all_ipv6.update(ipv6)
            resolved_count += 1
        else:
            failed_domains.append(domain)
    
    # Update nftables sets
    nftables_success = update_nftables_sets(all_ipv4, all_ipv6)
    
    # Update WireGuard AllowedIPs
    wg_success = update_wireguard_allowedips(all_ipv4, all_ipv6)
    
    # Ensure routing table 200 has routes (may be lost on interface restart)
    # Use correct source IP (10.8.0.5) for WireGuard interface
    try:
        subprocess.run(
            ["ip", "route", "del", "default", "table", "200"],
            check=False,
            capture_output=True
        )
        subprocess.run(
            ["ip", "route", "add", "default", "dev", "wg0", "table", "200", "src", "10.8.0.5"],
            check=False,
            capture_output=True
        )
        subprocess.run(
            ["ip", "route", "add", "10.8.0.0/24", "dev", "wg0", "table", "200"],
            check=False,
            capture_output=True
        )
    except Exception as e:
        logger.warning(f"Could not restore routing table 200: {e}")
    
    return {
        "success": nftables_success and wg_success,
        "domains_processed": len(domains),
        "domains_resolved": resolved_count,
        "ipv4_count": len(all_ipv4),
        "ipv6_count": len(all_ipv6),
        "failed_domains": failed_domains,
        "nftables_updated": nftables_success,
        "wireguard_updated": wg_success
    }

