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
COLOR_CYAN='\033[1;36m'
COLOR_RESET='\033[0m'

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
VERSION_FILE="${INSTALL_DIR}/VERSION"

# Root check (skip on Windows Git Bash)
if [[ "$USE_SUDO" == "true" ]] && [[ $EUID -ne 0 ]]; then
    echo -e "${COLOR_YELLOW}This script must be run as root (use sudo)${COLOR_RESET}"
    exit 1
fi

# ─── Detect existing installation ────────────────────────────────────────────

IS_UPDATE=false
INSTALLED_VERSION=""

if [[ -f "$VERSION_FILE" ]]; then
    IS_UPDATE=true
    INSTALLED_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
fi

# ─── Header ──────────────────────────────────────────────────────────────────

print_header() {
    if [[ "$IS_UPDATE" == "true" ]]; then
        echo -e "${COLOR_CYAN}════════════════════════════════════════════════════════════════"
        echo "              Updating Local Dev Proxy"
        echo -e "════════════════════════════════════════════════════════════════${COLOR_RESET}"
    else
        echo -e "${COLOR_BLUE}════════════════════════════════════════════════════════════════"
        echo "            Installing Local Dev Proxy"
        echo -e "════════════════════════════════════════════════════════════════${COLOR_RESET}"
    fi
    echo ""
}

print_header

if [[ "$PLATFORM" == "windows" ]]; then
    echo -e "${COLOR_YELLOW}Windows detected (Git Bash / MSYS2)${COLOR_RESET}"
    echo "Note: Only Docker mode is supported on Windows."
    echo "      For full support, use WSL (Windows Subsystem for Linux)."
    echo ""
fi

# ─── Resolve source (local clone or remote) ──────────────────────────────────

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

# ─── Resolve new version tag ─────────────────────────────────────────────────

RESOLVED_TAG=""

if [[ "$REMOTE_INSTALL" == "true" ]]; then
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        echo -e "${COLOR_RED}Error: curl or wget is required for remote installation${COLOR_RESET}"
        exit 1
    fi

    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

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
else
    # Local clone: read version from VERSION file in repo
    if [[ -f "${BASE_DIR}/VERSION" ]]; then
        LOCAL_FILE_VERSION="$(tr -d '[:space:]' < "${BASE_DIR}/VERSION")"
        RESOLVED_TAG="v${LOCAL_FILE_VERSION#v}"
    fi
fi

NEW_VERSION="${RESOLVED_TAG:-dev-${BRANCH}}"

# ─── Update confirmation ─────────────────────────────────────────────────────

if [[ "$IS_UPDATE" == "true" ]]; then
    CURRENT_DISPLAY="${INSTALLED_VERSION:-unknown}"
    NEW_DISPLAY="${NEW_VERSION}"

    if [[ "$CURRENT_DISPLAY" == "$NEW_DISPLAY" ]] || \
       [[ "v${CURRENT_DISPLAY#v}" == "${NEW_DISPLAY}" ]] || \
       [[ "${CURRENT_DISPLAY}" == "${NEW_DISPLAY#v}" ]]; then
        echo -e "  Installed : ${COLOR_GREEN}${CURRENT_DISPLAY}${COLOR_RESET}"
        echo -e "  Available : ${COLOR_YELLOW}${NEW_DISPLAY}${COLOR_RESET} (same version)"
        echo ""
        read -r -p "  Same version is already installed. Continue anyway? [y/N]: " _confirm
        _confirm="${_confirm:-n}"
        if [[ ! "$_confirm" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "  ${COLOR_YELLOW}Update cancelled.${COLOR_RESET}"
            echo ""
            exit 0
        fi
    else
        echo -e "  Installed : ${COLOR_GREEN}${CURRENT_DISPLAY}${COLOR_RESET}"
        echo -e "  Available : ${COLOR_CYAN}${NEW_DISPLAY}${COLOR_RESET}"
        echo ""
        read -r -p "  Update from ${CURRENT_DISPLAY} → ${NEW_DISPLAY}? [Y/n]: " _confirm
        _confirm="${_confirm:-y}"
        if [[ ! "$_confirm" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "  ${COLOR_YELLOW}Update cancelled.${COLOR_RESET}"
            echo ""
            exit 0
        fi
    fi
    echo ""
fi

# ─── Download (remote installs only) ─────────────────────────────────────────

if [[ "$REMOTE_INSTALL" == "true" ]]; then
    if [[ -n "$RESOLVED_TAG" ]]; then
        ARCHIVE_URL="https://github.com/${REPO}/archive/refs/tags/${RESOLVED_TAG}.tar.gz"
        EXTRACT_SUBDIR="local-dev-proxy-${RESOLVED_TAG#v}"
        echo "Downloading version ${RESOLVED_TAG}..."
    else
        ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"
        EXTRACT_SUBDIR="local-dev-proxy-${BRANCH}"
        echo "Downloading from branch ${BRANCH}..."
    fi

    if command -v curl &>/dev/null; then
        curl -fsSL "$ARCHIVE_URL" -o "${TMP_DIR}/archive.tar.gz"
    else
        wget -q "$ARCHIVE_URL" -O "${TMP_DIR}/archive.tar.gz"
    fi

    echo "Extracting..."
    tar -xzf "${TMP_DIR}/archive.tar.gz" -C "$TMP_DIR"
    BASE_DIR="${TMP_DIR}/${EXTRACT_SUBDIR}"
fi

# ─── Install / Update files ───────────────────────────────────────────────────

if [[ "$IS_UPDATE" == "true" ]]; then
    echo "Updating files..."
else
    echo "Creating installation directory..."
fi

mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"

echo "Copying files..."
cp -r "${BASE_DIR}/bin"     "$INSTALL_DIR/"
cp -r "${BASE_DIR}/lib"     "$INSTALL_DIR/"
cp -r "${BASE_DIR}/config"  "$INSTALL_DIR/"
cp -r "${BASE_DIR}/scripts" "$INSTALL_DIR/"

# Write version file
if [[ -n "$RESOLVED_TAG" ]]; then
    echo "${RESOLVED_TAG#v}" > "$VERSION_FILE"
elif [[ -f "${BASE_DIR}/VERSION" ]]; then
    cp "${BASE_DIR}/VERSION" "$VERSION_FILE"
else
    echo "dev-${BRANCH}" > "$VERSION_FILE"
fi

echo "Setting permissions..."
chmod +x "$INSTALL_DIR/bin/devproxy"
chmod +x "$INSTALL_DIR/lib"/*.sh
chmod +x "$INSTALL_DIR/scripts"/*.sh

echo "Creating symbolic link..."
ln -sf "$INSTALL_DIR/bin/devproxy" "$BIN_LINK"

# Ensure data directories exist (never overwrite user data)
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

# ─── Success message ──────────────────────────────────────────────────────────

FINAL_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null)"

echo ""
if [[ "$IS_UPDATE" == "true" ]]; then
    echo -e "${COLOR_CYAN}════════════════════════════════════════════════════════════════"
    echo "              Update completed successfully!"
    echo -e "════════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_GREEN}${INSTALLED_VERSION}${COLOR_RESET}  →  ${COLOR_CYAN}${FINAL_VERSION}${COLOR_RESET}"
else
    echo -e "${COLOR_GREEN}════════════════════════════════════════════════════════════════"
    echo "            Installation completed successfully!"
    echo -e "════════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
    echo -e "  Version   : ${COLOR_GREEN}${FINAL_VERSION}${COLOR_RESET}"
fi

echo ""
echo -e "  Run ${COLOR_BLUE}devproxy${COLOR_RESET} to get started."
echo ""
echo -e "${COLOR_BLUE}  ┌──────────────────────────────────────────────────────────────┐${COLOR_RESET}"
echo -e "${COLOR_BLUE}  │${COLOR_RESET}                      Quick Start Commands                     ${COLOR_BLUE}│${COLOR_RESET}"
echo -e "${COLOR_BLUE}  ├──────────────────────────────────────┬───────────────────────┤${COLOR_RESET}"
echo -e "${COLOR_BLUE}  │${COLOR_RESET}  ${COLOR_GREEN}devproxy help${COLOR_RESET}                      ${COLOR_BLUE}│${COLOR_RESET}  Show all commands       ${COLOR_BLUE}│${COLOR_RESET}"
echo -e "${COLOR_BLUE}  │${COLOR_RESET}  ${COLOR_GREEN}devproxy config${COLOR_RESET}                    ${COLOR_BLUE}│${COLOR_RESET}  Show configuration      ${COLOR_BLUE}│${COLOR_RESET}"
echo -e "${COLOR_BLUE}  │${COLOR_RESET}  ${COLOR_GREEN}devproxy mode${COLOR_RESET}                      ${COLOR_BLUE}│${COLOR_RESET}  Show proxy mode         ${COLOR_BLUE}│${COLOR_RESET}"
echo -e "${COLOR_BLUE}  │${COLOR_RESET}  ${COLOR_GREEN}devproxy create -h app.local -p 3000${COLOR_RESET} ${COLOR_BLUE}│${COLOR_RESET}  Create domain           ${COLOR_BLUE}│${COLOR_RESET}"
echo -e "${COLOR_BLUE}  │${COLOR_RESET}  ${COLOR_GREEN}devproxy remove -h app.local${COLOR_RESET}        ${COLOR_BLUE}│${COLOR_RESET}  Remove domain           ${COLOR_BLUE}│${COLOR_RESET}"
echo -e "${COLOR_BLUE}  └──────────────────────────────────────┴───────────────────────┘${COLOR_RESET}"
echo ""
echo -e "  Config file: ${COLOR_YELLOW}~/.local-dev-proxy.conf${COLOR_RESET}"
echo ""