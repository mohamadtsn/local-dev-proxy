#!/bin/bash
# lib/hosts.sh

# Hosts file management

# List all non-commented entries in hosts file
list_hosts() {
  info "Active entries in ${HOSTS_FILE}:"
  grep -E -v '^\s*(#|$)' "$HOSTS_FILE" | sed 's/^/  /'
}

# Check if a hostname entry exists in hosts file (exact word match)
host_exists() {
  local hostname="$1"
  awk -v h="$hostname" '
    /^[[:space:]]*#/ { next }
    { for (i=2; i<=NF; i++) if ($i == h) { found=1; exit } }
    END { exit !found }
  ' "$HOSTS_FILE"
}

# Write content from a temp file back to HOSTS_FILE.
# Uses direct write if root, sudo tee otherwise.
_hosts_write() {
  local tmp="$1"
  if check_root; then
    cat "$tmp" > "$HOSTS_FILE"
  elif command_exists sudo; then
    cat "$tmp" | sudo tee "$HOSTS_FILE" > /dev/null
  else
    rm -f "$tmp"
    error "Cannot write to hosts file — run with sudo or as root"
    return 1
  fi
}

# Add entry to hosts file
add_host() {
  local ip_address="${1:-127.0.0.1}"
  local hostname="$2"

  if [[ -z "$hostname" ]]; then
    error "Hostname cannot be empty"
    return 1
  fi

  local tmp
  tmp=$(mktemp) || { error "Failed to create temp file"; return 1; }

  # Build new content: strip any existing entry for this hostname, then append
  awk -v h="$hostname" '
    /^[[:space:]]*#/ { print; next }
    {
      skip=0
      for (i=2; i<=NF; i++) if ($i == h) { skip=1; break }
      if (!skip) print
    }
  ' "$HOSTS_FILE" > "$tmp"
  echo "$ip_address $hostname" >> "$tmp"

  if ! _hosts_write "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"

  success "Added to hosts: $ip_address $hostname"
  flush_dns_cache
  return 0
}

# Remove entry from hosts file
remove_host() {
  local entry="$1"

  if [[ -z "$entry" ]]; then
    error "Entry cannot be empty"
    return 1
  fi

  if ! host_exists "$entry"; then
    warning "Entry not found in hosts: $entry"
    return 1
  fi

  local tmp
  tmp=$(mktemp) || { error "Failed to create temp file"; return 1; }

  awk -v h="$entry" '
    /^[[:space:]]*#/ { print; next }
    {
      skip=0
      for (i=2; i<=NF; i++) if ($i == h) { skip=1; break }
      if (!skip) print
    }
  ' "$HOSTS_FILE" > "$tmp"

  # Backup before writing
  if check_root; then
    cp "$HOSTS_FILE" "${HOSTS_FILE}.bak" 2>/dev/null || true
  elif command_exists sudo; then
    sudo cp "$HOSTS_FILE" "${HOSTS_FILE}.bak" 2>/dev/null || true
  fi

  if ! _hosts_write "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"

  success "Removed from hosts: $entry"
  flush_dns_cache
  return 0
}

# Flush DNS cache based on operating system
flush_dns_cache() {
  local os
  os=$(detect_os)

  case "$os" in
  linux)
    if command_exists resolvectl; then
      resolvectl flush-caches 2>/dev/null || true
    elif command_exists systemd-resolve; then
      systemd-resolve --flush-caches 2>/dev/null || true
    elif command_exists nscd; then
      nscd -i hosts 2>/dev/null || true
    fi
    ;;
  macos)
    dscacheutil -flushcache 2>/dev/null || true
    killall -HUP mDNSResponder 2>/dev/null || true
    ;;
  windows)
    ipconfig //flushdns 2>/dev/null || true
    ;;
  esac
}

# Interactive hosts management
manage_hosts() {
  echo ""
  echo "=== Hosts File Management ==="
  echo "1. Add entry"
  echo "2. Remove entry"
  echo "3. List entries"
  echo "4. Exit"
  echo ""

  read -p "Enter your choice (1-4): " choice

  case $choice in
  1)
    read -p "Enter IP address [127.0.0.1]: " ip
    ip=${ip:-127.0.0.1}
    read -p "Enter hostname: " hostname
    add_host "$ip" "$hostname"
    ;;
  2)
    read -p "Enter hostname or IP to remove: " entry
    remove_host "$entry"
    ;;
  3)
    list_hosts
    ;;
  4)
    return 0
    ;;
  *)
    error "Invalid choice"
    return 1
    ;;
  esac
}