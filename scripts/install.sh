#!/bin/bash
# scripts/install.sh

set -e

REPO="mohamadtsn/local-dev-proxy"
BRANCH="master"
VERSION="${VERSION:-latest}"

COLOR_GREEN='\033[1;32m'
COLOR_BLUE='\033[1;34m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[1;31m'
COLOR_RESET='\033[0m'

print_header() {
    echo -e "${COLOR_BLUE}════════════════════════════════════════════════════════════════"
    echo "           Installing Local Dev Proxy"
    echo -e "════════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
}

# Detect platform
OS_TYPE="$(uname -s 2>/dev/null)"
case "$OS_TYPE" in
    Linux*)   PLATFORM="linux";;
    Darwin*)  PLATFORM="macos";;
    CYGWIN*|MINGW*|MSYS*) PLATFORM="windows";;
    *) PLATFORM="unknown";;
esac

# Windows: Docker mode only (no native Nginx), sudo not available
if [[ "$PLATFORM" == "windows" ]]; then
    INSTALL_DIR="$HOME/.local/lib/local-dev-proxy"
    BIN_DIR="$HOME/.local/bin"
    USE_SUDO=false
else
    INSTALL_DIR="/usr/local/lib/local-dev-proxy"
    BIN_DIR="/usr/local/bin"
    USE_SUDO=true
fi

BIN_LINK="${BIN_DIR}/devproxy"

# Root check (skip on Windows Git Bash)
if [[ "$USE_SUDO" == "true" ]] && [[ $EUID -ne 0 ]]; then
    echo -e "${COLOR_YELLOW}This script must be run as root (use sudo)${COLOR_RESET}"
    exit 1
fi

print_header

if [[ "$PLATFORM" == "windows" ]]; then
    echo -e "${COLOR_YELLOW}Windows detected (Git Bash / MSYS2)${COLOR_RESET}"
    echo "Note: Only Docker mode is supported on Windows."
    echo "      For full support, use WSL (Windows Subsystem for Linux)."
    echo ""
fi

# Detect if running from a local clone or remotely via curl
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [[ "$SCRIPT_SOURCE" == "/dev/stdin" || -z "$SCRIPT_SOURCE" || "$SCRIPT_SOURCE" == "bash" ]]; then
    REMOTE_INSTALL=true
else
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
    if [[ ! -f "${BASE_DIR}/bin/devproxy" ]]; then
        REMOTE_INSTALL=true
    else
        REMOTE_INSTALL=false
    fi
fi

if [[ "$REMOTE_INSTALL" == "true" ]]; then
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        echo -e "${COLOR_RED}Error: curl or wget is required for remote installation${COLOR_RESET}"
        exit 1
    fi

    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    # Resolve version: query GitHub API for latest release, fallback to branch
    RESOLVED_TAG=""
    if [[ "$VERSION" == "latest" ]]; then
        echo "Checking latest release..."
        if command -v curl &>/dev/null; then
            RESOLVED_TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
                2>/dev/null | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
        elif command -v wget &>/dev/null; then
            RESOLVED_TAG=$(wget -qO- "https://api.github.com/repos/${REPO}/releases/latest" \
                2>/dev/null | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
        fi
    elif [[ "$VERSION" != "master" ]]; then
        RESOLVED_TAG="$VERSION"
    fi

    if [[ -n "$RESOLVED_TAG" ]]; then
        ARCHIVE_URL="https://github.com/${REPO}/archive/refs/tags/${RESOLVED_TAG}.tar.gz"
        EXTRACT_SUBDIR="local-dev-proxy-${RESOLVED_TAG#v}"
        echo "Installing version ${RESOLVED_TAG}..."
    else
        ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"
        EXTRACT_SUBDIR="local-dev-proxy-${BRANCH}"
        echo "Installing from branch ${BRANCH}..."
    fi

    echo "Downloading from GitHub..."
    if command -v curl &>/dev/null; then
        curl -fsSL "$ARCHIVE_URL" -o "${TMP_DIR}/archive.tar.gz"
    else
        wget -q "$ARCHIVE_URL" -O "${TMP_DIR}/archive.tar.gz"
    fi

    echo "Extracting..."
    tar -xzf "${TMP_DIR}/archive.tar.gz" -C "$TMP_DIR"
    BASE_DIR="${TMP_DIR}/${EXTRACT_SUBDIR}"
fi

# Create installation directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"

# Copy files
echo "Copying files..."
cp -r "${BASE_DIR}/bin" "$INSTALL_DIR/"
cp -r "${BASE_DIR}/lib" "$INSTALL_DIR/"
cp -r "${BASE_DIR}/config" "$INSTALL_DIR/"
cp -r "${BASE_DIR}/scripts" "$INSTALL_DIR/"

# Set permissions
echo "Setting permissions..."
chmod +x "$INSTALL_DIR/bin/devproxy"
chmod +x "$INSTALL_DIR/lib"/*.sh
chmod +x "$INSTALL_DIR/scripts"/*.sh

# Create symlink
echo "Creating symbolic link..."
ln -sf "$INSTALL_DIR/bin/devproxy" "$BIN_LINK"

# Create required directories
mkdir -p "$INSTALL_DIR/certificates"
mkdir -p "$INSTALL_DIR/sites-enabled"
mkdir -p "$INSTALL_DIR/config/templates"

# Set ownership (Linux/macOS only)
if [[ "$USE_SUDO" == "true" ]]; then
    chown -R root:root "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR"
fi

# Ensure BIN_DIR is in PATH (Windows/user-local installs)
if [[ "$PLATFORM" == "windows" ]] || [[ "$USE_SUDO" == "false" ]]; then
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo ""
        echo -e "${COLOR_YELLOW}Add the following to your shell profile (~/.bashrc or ~/.bash_profile):${COLOR_RESET}"
        echo "  export PATH=\"\$PATH:${BIN_DIR}\""
    fi
fi

echo ""
echo -e "${COLOR_GREEN}════════════════════════════════════════════════════════════════"
echo "           Installation completed successfully!"
echo -e "════════════════════════════════════════════════════════════════${COLOR_RESET}"
echo ""
echo -e "You can now use: ${COLOR_BLUE}devproxy${COLOR_RESET}"
echo ""
echo "Quick start:"
echo "  devproxy help                          Show help"
echo "  devproxy config                        Show configuration"
echo "  devproxy create -h app.local -p 3000  Create domain"
echo ""
echo -e "Configuration file: ${COLOR_BLUE}~/.local-dev-proxy.conf${COLOR_RESET}"
echo ""