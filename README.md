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

| Requirement | Docker mode | Docker + ecosystem | Local mode |
|-------------|-------------|-------------------|------------|
| Docker + Nginx container | required | required | — |
| System Nginx | — | — | required |
| OpenSSL | required | required | required |
| sudo / admin access | — | only for hosts file & system trust | required |

> **Ecosystem mode** is detected automatically when using [public-services-containers](https://github.com/mohamadtsn/public-services-containers) — see [Ecosystem (public-services)](#ecosystem-public-services) below.

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
  --static                  Serve static files (no upstream proxy)
  --root PATH               Document root for static sites
  --name APP                App name shorthand: resolves to /srv/static/APP
```

```bash
# Subdomain sharing certificate with main domain
devproxy create -h api.myapp.local -p 8080 -s -m myapp.local

# Custom template
devproxy create -h myapp.local -p 3000 --template /path/to/custom.stub

# Force local Nginx
devproxy create -h myapp.local -p 3000 --mode local

# Static site — explicit path
devproxy create -h myapp.local --static --root /path/to/dist

# Static site — app name shorthand (ecosystem mode: resolves to /srv/static/myapp)
devproxy create -h myapp.local --static --name myapp
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

## Ecosystem (public-services)

When [public-services-containers](https://github.com/mohamadtsn/public-services-containers) is running, `devproxy` detects it automatically via `docker inspect` and switches to **ecosystem mode**:

- Nginx site configs are written directly to the container's volume-mounted conf directory (`nginx/site-enabled/`) on the host — no `docker cp`.
- SSL certificates are written directly to the volume-mounted ssl directory (`nginx/certificates/`) — no `docker cp`.
- Neither operation requires `sudo` (the mounted directories are owned by your user).
- `nginx -s reload` is still executed inside the container to pick up changes.

Detection is based on the volume mounts of the configured nginx container (`DOCKER_CONTAINER_NAME`, default `nginx-main`). No extra configuration is needed.

```
devproxy config     # shows "Ecosystem: ● detected" with the resolved paths
```

To disable ecosystem detection:
```bash
# ~/.local-dev-proxy.conf
export ECOSYSTEM_AUTO_DETECT="false"
```

> **Note:** Installing a certificate to the system trust store still requires `sudo`. Only Nginx config and cert file management are handled without root in ecosystem mode.

## Static Sites

For apps with a backend (Laravel, Node, etc.), `devproxy create -h myapp.local -p 3000` proxies traffic to a running port — no special setup needed. Static sites (React, Vue, plain HTML builds) are different: Nginx must read files directly from a path that exists **inside** the Nginx container.

```bash
devproxy create -h myapp.local --static --root <path>
```

The `--root` path must be visible inside the Nginx container. How you achieve that depends on your setup:

### With public-services (ecosystem mode)

[public-services-containers](https://github.com/mohamadtsn/public-services-containers) permanently mounts `nginx/static/` into `nginx-main` at `/srv/static/` (read-only) and provides CLI commands for managing static sites.

**First time setup:**

```bash
cd ~/projects/myapp && npm run build
pubservices static-add myapp "$PWD/dist"
devproxy create -h myapp.local --static --name myapp
```

**After each rebuild** — just sync again, no `devproxy` step needed:

```bash
pubservices static-add myapp ~/projects/myapp/dist
```

`static-add` uses `rsync --delete` (falls back to `cp` if rsync is unavailable), so only changed files are transferred.

**Other static commands:**

```bash
pubservices static-list                # list all static sites with size
pubservices static-remove myapp        # remove from nginx/static/
devproxy remove -h myapp.local         # then clean up the nginx config
```

**Tip:** point your build tool's output directly to `nginx/static/myapp` to skip the sync step entirely:

```bash
# Vite
vite build --outDir /path/to/public-services/nginx/static/myapp
```

### With local Nginx (local mode)

The path is read directly from the host filesystem, so use the real host path:

```bash
devproxy create -h myapp.local --static --root /home/youruser/projects/myapp/dist --mode local
```

### With a custom Docker volume (home-dir mount)

Use `pubservices static-mount` to generate `docker-compose.override.yml` automatically — no manual file editing needed:

```bash
# Mount $HOME into nginx (default)
pubservices static-mount

# Or mount a specific directory instead
pubservices static-mount ~/projects

# Restart nginx to apply
pubservices run make up-proxy

# Register using the real host path (no copying needed)
devproxy create -h myapp.local --static --root /home/youruser/projects/myapp/dist

# To undo
pubservices static-unmount && pubservices run make up-proxy
```

`docker-compose.override.yml` is git-ignored and merged automatically by Docker Compose on every `up`. Trade-off: mounts the chosen directory read-only into the container.

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

# Ecosystem integration
export ECOSYSTEM_AUTO_DETECT="true"    # set to "false" to disable
```

## Templates

**Proxy templates** (for apps with an upstream port):

| Template | Behavior |
|----------|----------|
| `nginx-mixed` | HTTP and HTTPS both work (default) |
| `nginx-https` | HTTPS only, HTTP redirects to HTTPS |
| `nginx-http` | HTTP only, no SSL |

**Static templates** (for pre-built HTML/JS/CSS with no upstream port):

| Template | Behavior |
|----------|----------|
| `nginx-static` | HTTPS only with SPA routing (`try_files`) and asset caching |
| `nginx-static-http` | HTTP only version of the above |

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

Proxy placeholders: `{{DOMAIN}}`, `{{PORT}}`, `{{PROXY_HOST}}`, `{{CERTIFICATE_NAME_FILE}}`, `{{SSL_DIR}}`

Static placeholders: `{{DOMAIN}}`, `{{STATIC_ROOT}}`, `{{CERTIFICATE_NAME_FILE}}`, `{{SSL_DIR}}`

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

**Permission denied writing certificates or configs (Docker mode):**

If `devproxy` is installed system-wide (as root) and you run it without `sudo` in Docker mode, it may fail to write to the system install directories. The recommended fix is to use [public-services-containers](https://github.com/mohamadtsn/public-services-containers) as the nginx provider — ecosystem mode writes directly to the user-owned volume-mounted directories.

If you prefer to keep separate directories, set user-writable paths in `~/.local-dev-proxy.conf`:
```bash
export CERT_DIR="$HOME/.local/share/devproxy/certificates"
export SITE_ENABLED_DIR="$HOME/.local/share/devproxy/sites-enabled"
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