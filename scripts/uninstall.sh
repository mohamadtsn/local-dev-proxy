#!/bin/bash
# scripts/uninstall.sh

set -e

INSTALL_DIR="/usr/local/lib/local-dev-proxy"
BIN_LINK="/usr/local/bin/devproxy"

COLOR_GREEN='\033[1;32m'
COLOR_BLUE='\033[1;34m'
COLOR_YELLOW='\033[1;33m'
COLOR_RESET='\033[0m'

echo -e "${COLOR_BLUE}════════════════════════════════════════════════════════════════"
echo "           Uninstalling Local Dev Proxy"
echo -e "════════════════════════════════════════════════════════════════${COLOR_RESET}"
echo ""

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
  echo -e "${COLOR_YELLOW}This script must be run as root (use sudo)${COLOR_RESET}"
  exit 1
fi

# Remove symbolic link
if [[ -L "$BIN_LINK" ]]; then
  rm -f "$BIN_LINK"
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} Removed symbolic link"
fi

# Remove installation directory
if [[ -d "$INSTALL_DIR" ]]; then
  echo ""
  read -p "Remove all data including certificates and configurations? [y/N]: " -r response

  if [[ "$response" =~ ^[Yy]$ ]]; then
    rm -rf "$INSTALL_DIR"
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} Removed all files and data"
  else
    # Keep certificates and configs
    rm -rf "${INSTALL_DIR:?}/bin"
    rm -rf "${INSTALL_DIR:?}/lib"
    rm -rf "${INSTALL_DIR:?}/scripts"
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} Removed program files"
    echo -e "${COLOR_YELLOW}ℹ${COLOR_RESET} Kept certificates and configurations in: $INSTALL_DIR"
  fi
fi

# Ask about user config
if [[ -f "$HOME/.local-dev-proxy.conf" ]]; then
  echo ""
  read -p "Remove user configuration (~/.local-dev-proxy.conf)? [y/N]: " -r response

  if [[ "$response" =~ ^[Yy]$ ]]; then
    rm -f "$HOME/.local-dev-proxy.conf"
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} Removed user configuration"
  fi
fi

# Ask about logs
if [[ -f "$INSTALL_DIR/local-dev-proxy.log" ]]; then
  echo ""
  read -p "Remove log files? [y/N]: " -r response

  if [[ "$response" =~ ^[Yy]$ ]]; then
    rm -f "$INSTALL_DIR"/*.log
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} Removed log files"
  fi
fi

echo ""
echo -e "${COLOR_GREEN}════════════════════════════════════════════════════════════════"
echo "           Uninstallation completed!"
echo -e "════════════════════════════════════════════════════════════════${COLOR_RESET}"
echo ""