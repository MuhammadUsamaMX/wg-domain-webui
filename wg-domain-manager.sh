#!/bin/bash
#
# WG-Domain Manager Script
# Handles domain list operations and privileged nftables updates
#

DOMAINS_FILE="/etc/wg-domain/domains.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate domain format
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+$ ]] || [ ${#domain} -gt 253 ]; then
        return 1
    fi
    return 0
}

# Read domains from file
read_domains() {
    if [ ! -f "$DOMAINS_FILE" ]; then
        return 0
    fi
    
    while IFS= read -r line; do
        line=$(echo "$line" | xargs)
        [ -n "$line" ] && echo "$line"
    done < "$DOMAINS_FILE" | sort -u
}

# Write domains to file
write_domains() {
    local domains="$1"
    mkdir -p "$(dirname "$DOMAINS_FILE")"
    echo "$domains" | sort -u > "$DOMAINS_FILE"
}

# Add domain
add_domain() {
    local domain="$1"
    
    if ! validate_domain "$domain"; then
        echo "Error: Invalid domain format: $domain" >&2
        exit 1
    fi
    
    local existing=$(read_domains)
    if echo "$existing" | grep -Fxq "$domain"; then
        echo "Domain already exists: $domain"
        return 1
    fi
    
    write_domains "$existing"$'\n'"$domain"
    echo "Domain added: $domain"
    return 0
}

# Remove domain
remove_domain() {
    local domain="$1"
    local existing=$(read_domains)
    
    if ! echo "$existing" | grep -Fxq "$domain"; then
        echo "Domain not found: $domain"
        return 1
    fi
    
    local updated=$(echo "$existing" | grep -Fxv "$domain")
    write_domains "$updated"
    echo "Domain removed: $domain"
    return 0
}

# List domains
list_domains() {
    read_domains
}

# Main command handler
case "${1:-}" in
    add)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 add <domain>" >&2
            exit 1
        fi
        add_domain "$2"
        ;;
    remove)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 remove <domain>" >&2
            exit 1
        fi
        remove_domain "$2"
        ;;
    list)
        list_domains
        ;;
    *)
        echo "Usage: $0 {add|remove|list} [domain]" >&2
        exit 1
        ;;
esac

