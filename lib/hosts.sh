#!/bin/bash
# lib/hosts.sh

# Hosts file management

# List all non-commented entries in hosts file
list_hosts() {
  info "Active entries in ${HOSTS_FILE}:"
  grep -E -v '^\s*(#|$)' "$HOSTS_FILE" | sed 's/^/  /'
}

# Check if entry exists in hosts file
host_exists() {
  local search="$1"
  grep -q "$search" "$HOSTS_FILE"
}

# Add entry to hosts file
add_host() {
  local ip_address="${1:-127.0.0.1}"
  local hostname="$2"

  if [[ -z "$hostname" ]]; then
    error "Hostname cannot be empty"
    return 1
  fi

  if ! check_root; then
    return 1
  fi

  # Remove existing entry if present — ignore failure (entry may not exist yet)
  remove_host "$hostname" &> /dev/null || true

  # Add new entry
  echo "$ip_address $hostname" >> "$HOSTS_FILE"
  success "Added to hosts: $ip_address $hostname"

  # Flush DNS cache based on OS
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

  if ! check_root; then
    return 1
  fi

  if host_exists "$entry"; then
    # Create backup
    cp "$HOSTS_FILE" "${HOSTS_FILE}.bak"

    # Remove entry
    sed -i.tmp "/$entry/d" "$HOSTS_FILE"
    rm -f "${HOSTS_FILE}.tmp"

    success "Removed from hosts: $entry"
    return 0
  else
    warning "Entry not found in hosts: $entry"
    return 1
  fi
}

# Flush DNS cache based on operating system
flush_dns_cache() {
  local os=$(detect_os)

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
    dscacheutil -flushcache 2>/dev/null
    killall -HUP mDNSResponder 2>/dev/null
    ;;
  windows)
    ipconfig //flushdns 2>/dev/null
    ;;
  esac
}

# Interactive hosts management
manage_hosts() {
  if ! check_root; then
    return 1
  fi

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