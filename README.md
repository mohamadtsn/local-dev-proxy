# Local Dev Proxy

A CLI tool for managing local development domains with Nginx and SSL. Supports both Docker and system Nginx, handles certificate generation, hosts file entries, and site configuration automatically.

Works on **Linux**, **macOS**, and **Windows** (Git Bash / WSL).

## Platform Support

| Feature | Linux | macOS | Windows (WSL) | Windows (Git Bash) |
|---------|-------|-------|---------------|--------------------|
| Docker mode | ✓ | ✓ | ✓ | ✓ |
| Local Nginx mode | ✓ | ✓ | ✓ | — |
| SSL certificate generation | ✓ | ✓ | ✓ | ✓ |
| Hosts file management | ✓ | ✓ | ✓ | ✓ (as Admin) |
| System cert trust | ✓ | ✓ | ✓ | ✓ |

> **Windows note:** WSL gives full support. Git Bash supports Docker mode only (no native Nginx).

## Prerequisites

| Requirement | Docker mode | Local mode |
|-------------|-------------|------------|
| Docker + Nginx container | required | — |
| System Nginx | — | required |
| OpenSSL | required | required |
| sudo / admin access | — | required |

## Installation

**Quick install:**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mohamadtsn/local-dev-proxy/master/scripts/install.sh)"
```

The script auto-detects the platform. On Linux/macOS it installs system-wide (`/usr/local`). On Windows Git Bash it installs to `~/.local` (no sudo needed).

**From source:**
```bash
git clone https://github.com/mohamadtsn/local-dev-proxy.git
cd local-dev-proxy
sudo ./scripts/install.sh
```

**Uninstall:**
```bash
sudo /usr/local/lib/local-dev-proxy/scripts/uninstall.sh
```

## Quick Start

```bash
# Create domain with SSL (auto-detects Docker or local Nginx)
devproxy create -h myapp.local -p 3000

# Create without SSL
devproxy create -h myapp.local -p 3000 --no-ssl

# Remove domain
devproxy remove -h myapp.local
```

## Commands

### `devproxy create`

```
devproxy create -h <domain> -p <port> [options]

Options:
  -h, --host DOMAIN         Domain name
  -p, --port PORT           Port number
  -i, --ip IP               IP address (default: 127.0.0.1)
  -s, --subdomain           Mark as subdomain (requires -m)
  -m, --main-domain         Main domain for shared certificate
  --ssl / --no-ssl          Enable or disable SSL (default: enabled)
  --template PATH           Custom Nginx template
  --mode docker|local|auto  Override proxy mode
```

```bash
# Subdomain sharing certificate with main domain
devproxy create -h api.myapp.local -p 8080 -s -m myapp.local

# Custom template
devproxy create -h myapp.local -p 3000 --template /path/to/custom.stub

# Force local Nginx
devproxy create -h myapp.local -p 3000 --mode local
```

### `devproxy cert`

```bash
devproxy cert generate -h myapp.local
devproxy cert list
devproxy cert remove -h myapp.local
```

### `devproxy hosts`

```bash
sudo devproxy hosts add -h myapp.local -i 127.0.0.1
sudo devproxy hosts remove -h myapp.local
devproxy hosts list
```

### `devproxy nginx`

```bash
devproxy nginx create-site -h myapp.local -p 8080
devproxy nginx remove-site -h myapp.local
devproxy nginx list
devproxy nginx test
devproxy nginx reload
```

### `devproxy mode`

```bash
devproxy mode                      # Show current mode
devproxy mode --mode docker        # Set to Docker
devproxy mode --mode local         # Set to system Nginx
devproxy mode --mode auto          # Auto-detect (default)
```

### `devproxy config`

Show current configuration and all resolved paths.

## Proxy Modes

**auto** (default) — uses Docker if available, otherwise falls back to local Nginx.

**docker** — proxies through an Nginx container. On Linux, uses the Docker gateway IP; on macOS/Windows, uses `host.docker.internal`.

**local** — uses system-installed Nginx. Requires root for configuration writes.

## Configuration

Create `~/.local-dev-proxy.conf` to override defaults:

```bash
# Proxy mode
export PROXY_MODE="docker"             # docker | local | auto

# Docker
export DOCKER_CONTAINER_NAME="nginx-main"
export DOCKER_HOST_ACCESS="gateway"    # gateway | host.docker.internal | custom
export DOCKER_CUSTOM_HOST_IP="172.17.0.1"

# SSL certificate fields
export SSL_COUNTRY="US"
export SSL_STATE="California"
export SSL_CITY="San Francisco"
export SSL_ORGANIZATION="My Company"
export SSL_EMAIL="admin@example.com"

# Defaults
export DEFAULT_SSL_ENABLED="true"
export DEFAULT_TEMPLATE="nginx-mixed"  # nginx-http | nginx-https | nginx-mixed

# Local Nginx paths
export NGINX_CONF_DIR="/etc/nginx/sites-available"
export NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"

# Storage
export CERT_DIR="/custom/path/certificates"
export SITE_ENABLED_DIR="/custom/path/sites"

export AUTO_RELOAD="true"
export BACKUP_CONFIGS="true"
```

## Templates

Three built-in templates:

| Template | Behavior |
|----------|----------|
| `nginx-mixed` | HTTP and HTTPS both work (default) |
| `nginx-https` | HTTPS only, HTTP redirects to HTTPS |
| `nginx-http` | HTTP only, no SSL |

**Custom templates** use these placeholders:

```nginx
server {
    listen 80;
    server_name {{DOMAIN}};
    location / {
        proxy_pass http://{{PROXY_HOST}}:{{PORT}};
    }
}
```

Available placeholders: `{{DOMAIN}}`, `{{PORT}}`, `{{PROXY_HOST}}`, `{{CERTIFICATE_NAME_FILE}}`, `{{SSL_DIR}}`

Set a custom template as default:
```bash
export CUSTOM_TEMPLATE_PATH="/path/to/my.stub"
```

## Trusting SSL Certificates

Certificates are installed to the system trust store automatically when running with root/admin. To add manually:

**Linux (Chrome/Chromium):**
```bash
certutil -d sql:$HOME/.pki/nssdb -A -t "CT,c,c" \
  -n "myapp.local" \
  -i ~/.local-dev-proxy/certificates/myapp.local.crt
```

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  ~/.local-dev-proxy/certificates/myapp.local.crt
```

**Windows:**
Double-click the `.crt` file and import into "Trusted Root Certification Authorities", or in an elevated terminal:
```
certutil -addstore -user Root %USERPROFILE%\.local-dev-proxy\certificates\myapp.local.crt
```

## Troubleshooting

**Docker container not found:**
```bash
docker ps | grep nginx-main
devproxy mode --mode local      # switch to local Nginx instead
```

**Nginx config test fails:**
```bash
devproxy nginx test
docker logs nginx-main          # Docker mode
sudo journalctl -u nginx        # Local mode (Linux)
```

**Windows Git Bash: `devproxy` not found after install:**
```bash
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc
```

## Development

Tests use [BATS](https://github.com/bats-core/bats-core) and run on Linux, macOS, and Windows (Git Bash / WSL).

```bash
make setup              # Install BATS and dependencies
make test               # Run all tests (unit + integration + e2e)
make test-unit          # Unit tests only
make test-integration   # Integration tests only
make test-e2e           # E2E tests only
make lint               # Run shellcheck
make check              # lint + test
```

Test structure:
```
tests/
├── unit/               # Core function tests (~60 tests)
├── integration/        # Docker/Nginx integration (~55 tests)
├── e2e/                # Full workflow tests (~15 tests)
└── mocks/              # Mock functions for Docker, Nginx, OpenSSL
```

## License

MIT

---

*This project was developed with the assistance of [Claude AI](https://claude.ai).*