"""
Domain Manager - Handles read/write operations on domain list
"""
import os
import re
from typing import List, Set
from config import DOMAINS_FILE


def validate_domain(domain: str) -> bool:
    """
    Validate domain name format.
    Allows: alphanumeric, dots, hyphens
    """
    pattern = r'^[a-zA-Z0-9.-]+$'
    return bool(re.match(pattern, domain)) and len(domain) <= 253


def read_domains() -> List[str]:
    """
    Read domains from the domains file.
    Returns empty list if file doesn't exist.
    """
    if not os.path.exists(DOMAINS_FILE):
        return []
    
    try:
        with open(DOMAINS_FILE, 'r') as f:
            domains = [line.strip() for line in f if line.strip()]
        # Remove duplicates and sort
        return sorted(list(set(domains)))
    except (IOError, PermissionError) as e:
        raise Exception(f"Failed to read domains file: {e}")


def write_domains(domains: List[str]) -> None:
    """
    Write domains to the domains file.
    Validates all domains before writing.
    """
    # Validate all domains
    for domain in domains:
        if not validate_domain(domain):
            raise ValueError(f"Invalid domain format: {domain}")
    
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(DOMAINS_FILE), exist_ok=True)
    
    # Remove duplicates and sort
    unique_domains = sorted(list(set(domains)))
    
    try:
        with open(DOMAINS_FILE, 'w') as f:
            for domain in unique_domains:
                f.write(f"{domain}\n")
    except (IOError, PermissionError) as e:
        raise Exception(f"Failed to write domains file: {e}")


def add_domain(domain: str) -> bool:
    """
    Add a domain to the list.
    Returns True if added, False if already exists.
    """
    if not validate_domain(domain):
        raise ValueError(f"Invalid domain format: {domain}")
    
    domains = read_domains()
    if domain in domains:
        return False
    
    domains.append(domain)
    write_domains(domains)
    return True


def remove_domain(domain: str) -> bool:
    """
    Remove a domain from the list.
    Returns True if removed, False if not found.
    """
    domains = read_domains()
    if domain not in domains:
        return False
    
    domains.remove(domain)
    write_domains(domains)
    return True

