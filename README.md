# WG-Domain Routing Web UI

A lightweight Flask-based web interface for managing domain-based routing through WireGuard VPN using nftables. This application allows you to selectively route specific domains through your WireGuard VPN while keeping other traffic on your regular connection.

## Features

- 🌐 **Web-based Management**: Clean, modern web UI for managing routed domains
- 🔄 **Automatic Updates**: DNS resolution and routing updates every 60 seconds
- 🎯 **Selective Routing**: Route only specified domains through VPN
- ⚡ **Real-time Updates**: Manual update button for immediate DNS resolution
- 🔒 **Secure**: Runs locally on 127.0.0.1, no external exposure
- 🛠️ **Easy Setup**: Simple installation and configuration

## Architecture

```
Flask Web UI → Domain Manager → DNS Resolver → nftables Sets → WireGuard Routing
```

- **Flask App**: Provides web UI and REST API
- **Domain Manager**: Handles domain list CRUD operations
- **DNS Resolver**: Resolves domain names to IP addresses
- **Nftables**: Marks packets matching domain IPs
- **WireGuard**: Routes marked packets through VPN

## Requirements

- Python 3.8+
- WireGuard installed and configured
- nftables (Linux)
- Root/sudo access for routing configuration

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/MuhammadUsamaMX/wg-domain-webui.git
cd wg-domain-webui
```

### 2. Install Dependencies

```bash
sudo pip3 install -r requirements.txt
```

### 3. Install Application

```bash
# Copy application to system directory
sudo cp -r wg-domain-webui /usr/local/

# Install manager script
sudo cp wg-domain-manager.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/wg-domain-manager.sh

# Create domains directory
sudo mkdir -p /etc/wg-domain
sudo touch /etc/wg-domain/domains.txt
```

### 4. Configure WireGuard

Ensure your WireGuard config (`/etc/wireguard/wg0.conf`) has:
- `AllowedIPs = 10.8.0.0/24` (or your VPN subnet)
- No `DNS` directive (uses system DNS)

### 5. Setup Nftables and Routing

```bash
cd /usr/local/wg-domain-webui
sudo ./setup_nftables.sh
```

### 6. Install Systemd Services

```bash
sudo cp wg-domain-webui.service /etc/systemd/system/
sudo cp wg-domain-update.service /etc/systemd/system/
sudo cp wg-domain-update.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable wg-domain-webui.service
sudo systemctl enable wg-domain-update.timer
sudo systemctl start wg-domain-webui.service
sudo systemctl start wg-domain-update.timer
```

## Configuration

Edit `/usr/local/wg-domain-webui/config.py` to customize:

```python
PORT = 8877          # Web UI port
HOST = "127.0.0.1"   # Bind address (localhost only)
```

## Usage

### Web Interface

Access the web UI at: **http://127.0.0.1:8877**

- **Add Domain**: Enter domain name and click "Add Domain"
- **Remove Domain**: Click "Remove" button next to domain
- **Update Now**: Manually trigger DNS resolution and routing update

### API Endpoints

- `GET /api/domains` - List all configured domains
- `POST /api/add` - Add a domain (`{"domain": "example.com"}`)
- `POST /api/remove` - Remove a domain (`{"domain": "example.com"}`)
- `POST /api/update` - Trigger immediate DNS update

### Command Line

```bash
# List domains
wg-domain-manager.sh list

# Add domain
wg-domain-manager.sh add example.com

# Remove domain
wg-domain-manager.sh remove example.com
```

## How It Works

1. **Domain Addition**: User adds domain via web UI
2. **DNS Resolution**: System resolves domain to IP addresses
3. **Nftables Marking**: Packets destined for domain IPs are marked
4. **Policy Routing**: Marked packets route through WireGuard interface
5. **WireGuard**: Domain IPs added to AllowedIPs dynamically
6. **SNAT**: Source IP changed to WireGuard interface IP

## Making Configuration Persistent

After verifying everything works, make it persistent:

```bash
cd /usr/local/wg-domain-webui
sudo ./make_persistent.sh
```

This will:
- Save nftables rules to `/etc/nftables.conf`
- Enable WireGuard on boot
- Create routing persistence service

## File Structure

```
wg-domain-webui/
├── app.py                 # Main Flask application
├── config.py              # Configuration settings
├── routes.py              # API routes and handlers
├── domain_manager.py      # Domain list management
├── updater.py             # DNS resolution and WireGuard updates
├── setup_nftables.sh     # Nftables and routing setup
├── make_persistent.sh     # Make config persistent
├── wg-domain-manager.sh   # Command-line domain manager
├── wg-domain-webui.service    # Systemd service file
├── wg-domain-update.service  # Update service
├── wg-domain-update.timer    # Update timer
├── requirements.txt       # Python dependencies
├── templates/             # HTML templates
│   └── index.html
└── static/                # CSS and JavaScript
    ├── style.css
    └── script.js
```

## Troubleshooting

### Domains Not Routing Through VPN

1. Check WireGuard status: `sudo wg show wg0`
2. Verify domain IPs in AllowedIPs: `sudo wg show wg0 | grep allowed`
3. Check nftables sets: `sudo nft list set inet mangle domlist4`
4. Verify routing: `sudo ip route get <domain-ip> mark 0x1`

### Web UI Not Accessible

1. Check service status: `sudo systemctl status wg-domain-webui`
2. Check logs: `sudo journalctl -u wg-domain-webui -f`
3. Verify port: `sudo netstat -tlnp | grep 8877`

### DNS Resolution Failing

1. Check system DNS: `cat /etc/resolv.conf`
2. Test resolution: `dig example.com`
3. Check updater logs: `sudo journalctl -u wg-domain-update -f`

## Security Notes

- Web UI binds to `127.0.0.1` only (localhost)
- No authentication (local-only access)
- Domain validation prevents injection attacks
- All privileged operations require sudo/root

## License

This project is open source. See LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

**Muhammad Usama**

- GitHub: [@MuhammadUsamaMX](https://github.com/MuhammadUsamaMX)

## Acknowledgments

- Built with Flask and Waitress
- Uses nftables for packet marking
- WireGuard for VPN connectivity

