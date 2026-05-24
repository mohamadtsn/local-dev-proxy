#!/bin/bash
# lib/nginx.sh

# Nginx configuration management (supports both Docker and local modes)

# Get nginx configuration directory based on mode
get_nginx_conf_dir() {
  local mode=$(determine_proxy_mode)

  case "$mode" in
  docker)
    echo "$DOCKER_CONF_PATH"
    ;;
  local)
    echo "$NGINX_CONF_DIR"
    ;;
  *)
    return 1
    ;;
  esac
}

# Get nginx SSL directory based on mode
get_nginx_ssl_dir() {
  local mode=$(determine_proxy_mode)

  case "$mode" in
  docker)
    echo "$DOCKER_SSL_PATH"
    ;;
  local)
    echo "$NGINX_SSL_DIR"
    ;;
  *)
    return 1
    ;;
  esac
}

# Get template file path
get_template_path() {
  local ssl_enabled="$1"

  # If custom template is specified, use it
  if [[ -n "$CUSTOM_TEMPLATE_PATH" ]]; then
    if [[ -f "$CUSTOM_TEMPLATE_PATH" ]]; then
      echo "$CUSTOM_TEMPLATE_PATH"
      return 0
    else
      warning "Custom template not found: $CUSTOM_TEMPLATE_PATH"
      return 1
    fi
  fi

  # Use default template based on SSL mode
  local template_name="$DEFAULT_TEMPLATE"

  # Override with SSL-specific template
  if [[ "$ssl_enabled" == "true" ]]; then
    template_name="nginx-https"
  elif [[ "$ssl_enabled" == "false" ]]; then
    template_name="nginx-http"
  fi

  local template_path="${TEMPLATE_DIR}/${template_name}.stub"

  if [[ ! -f "$template_path" ]]; then
    error "Template not found: $template_path"
    return 1
  fi

  echo "$template_path"
  return 0
}

# Get proxy host for upstream
get_proxy_host() {
  local mode=$(determine_proxy_mode)

  case "$mode" in
  docker)
    get_docker_host_address
    ;;
  local)
    echo "127.0.0.1"
    ;;
  *)
    echo "localhost"
    ;;
  esac
}

# Create nginx site configuration
create_site_config() {
  local domain="$1"
  local port="$2"
  local cert_domain="${3:-$domain}"
  local ssl_enabled="${4:-$DEFAULT_SSL_ENABLED}"

  if [[ -z "$domain" ]]; then
    error "Domain is required"
    return 1
  fi

  if [[ -z "$port" ]]; then
    error "Port is required"
    return 1
  fi

  # Validate port
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
    error "Invalid port: $port"
    return 1
  fi

  # Validate domain
  domain=$(validate_domain "$domain")
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  local mode=$(determine_proxy_mode)
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  info "Creating Nginx configuration for: $domain (SSL: $ssl_enabled)"

  # Ensure directory exists
  ensure_directory "$SITE_ENABLED_DIR" || return 1

  local config_file="${SITE_ENABLED_DIR}/${domain}.conf"
  local template_file=$(get_template_path "$ssl_enabled")

  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Backup existing config if exists
  if [[ -f "$config_file" ]] && [[ "$BACKUP_CONFIGS" == "true" ]]; then
    cp "$config_file" "${config_file}.bak.$(date +%Y%m%d_%H%M%S)"
    info "Backed up existing configuration"
  fi

  # Get proxy host
  local proxy_host=$(get_proxy_host)

  # Copy template and replace placeholders
  cp "$template_file" "$config_file"

  sed -i.tmp "s|{{DOMAIN}}|$domain|g" "$config_file"
  sed -i.tmp "s|{{CERTIFICATE_NAME_FILE}}|$cert_domain|g" "$config_file"
  sed -i.tmp "s|{{PORT}}|$port|g" "$config_file"
  sed -i.tmp "s|{{PROXY_HOST}}|$proxy_host|g" "$config_file"
  sed -i.tmp "s|{{SSL_DIR}}|$(get_nginx_ssl_dir)|g" "$config_file"
  rm -f "${config_file}.tmp"

  success "Configuration created: $config_file"

  # Deploy configuration based on mode
  case "$mode" in
  docker)
    deploy_config_docker "$domain" "$config_file"
    ;;
  local)
    deploy_config_local "$domain" "$config_file"
    ;;
  esac

  local result=$?

  # Reload nginx if configured
  if [[ $result -eq 0 ]] && [[ "$AUTO_RELOAD" == "true" ]]; then
    reload_nginx
  fi

  return $result
}

# Deploy configuration to Docker container
deploy_config_docker() {
  local domain="$1"
  local config_file="$2"

  # In ecosystem mode SITE_ENABLED_DIR already points to the volume-mounted nginx
  # conf dir, so the file written there is immediately visible to the container.
  if is_ecosystem_active; then
    success "Configuration deployed via ecosystem volume mount"
    return 0
  fi

  info "Deploying configuration to Docker container..."

  # Ensure directory exists in container
  docker_mkdir "$DOCKER_CONF_PATH"

  # Copy configuration file
  docker_copy_to_container "$config_file" "${DOCKER_CONF_PATH}/${domain}.conf"

  success "Configuration deployed to Docker"
  return 0
}

# Deploy configuration to local nginx
deploy_config_local() {
  local domain="$1"
  local config_file="$2"

  if ! check_root; then
    error "Root privileges required for local Nginx configuration"
    return 1
  fi

  info "Deploying configuration to local Nginx..."

  # Copy to sites-available
  cp "$config_file" "${NGINX_CONF_DIR}/${domain}.conf"

  # Create symlink in sites-enabled
  ln -sf "${NGINX_CONF_DIR}/${domain}.conf" "${NGINX_ENABLED_DIR}/${domain}.conf" 2>/dev/null

  success "Configuration deployed to local Nginx"
  return 0
}

# Remove nginx site configuration
remove_site_config() {
  local domain="$1"

  if [[ -z "$domain" ]]; then
    error "Domain is required"
    return 1
  fi

  local mode=$(determine_proxy_mode)
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  local config_file="${SITE_ENABLED_DIR}/${domain}.conf"

  # Remove local copy
  if [[ -f "$config_file" ]]; then
    if [[ "$BACKUP_CONFIGS" == "true" ]]; then
      mv "$config_file" "${config_file}.bak.$(date +%Y%m%d_%H%M%S)"
      info "Backed up configuration before removal"
    else
      rm -f "$config_file"
    fi
  fi

  # Remove from nginx
  case "$mode" in
  docker)
    # In ecosystem mode the file was already removed from the host-mounted conf dir
    # above; exec into the container is unnecessary (and the path may not exist).
    if ! is_ecosystem_active; then
      docker_rm "${DOCKER_CONF_PATH}/${domain}.conf"
    fi
    ;;
  local)
    if check_root; then
      rm -f "${NGINX_ENABLED_DIR}/${domain}.conf"
      rm -f "${NGINX_CONF_DIR}/${domain}.conf"
    fi
    ;;
  esac

  success "Configuration removed: $domain"

  # Reload nginx if configured
  if [[ "$AUTO_RELOAD" == "true" ]]; then
    reload_nginx
  fi

  return 0
}

# Test nginx configuration
test_nginx_config() {
  local mode=$(determine_proxy_mode)

  case "$mode" in
  docker)
    docker_nginx_test
    ;;
  local)
    info "Testing local Nginx configuration..."
    if $NGINX_BIN -t 2>&1; then
      success "Nginx configuration is valid"
      return 0
    else
      error "Nginx configuration test failed"
      return 1
    fi
    ;;
  *)
    return 1
    ;;
  esac
}

# Reload nginx configuration
reload_nginx() {
  local mode=$(determine_proxy_mode)

  case "$mode" in
  docker)
    docker_nginx_reload
    ;;
  local)
    info "Reloading local Nginx..."
    if test_nginx_config; then
      if [[ "$USE_SYSTEMD" == "true" ]] && command_exists systemctl; then
        systemctl reload nginx
      else
        $NGINX_BIN -s reload
      fi
      success "Nginx reloaded successfully"
      return 0
    else
      error "Cannot reload Nginx due to configuration errors"
      return 1
    fi
    ;;
  *)
    return 1
    ;;
  esac
}

# Create nginx static site configuration (no upstream proxy — serves files directly)
create_static_config() {
  local domain="$1"
  local static_root="$2"
  local cert_domain="${3:-$domain}"
  local ssl_enabled="${4:-$DEFAULT_SSL_ENABLED}"

  if [[ -z "$domain" ]]; then
    error "Domain is required"
    return 1
  fi

  if [[ -z "$static_root" ]]; then
    error "Static root directory is required (--root)"
    return 1
  fi

  # Validate domain
  domain=$(validate_domain "$domain")
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  local mode=$(determine_proxy_mode)
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  info "Creating static Nginx configuration for: $domain (root: $static_root, SSL: $ssl_enabled)"

  ensure_directory "$SITE_ENABLED_DIR" || return 1

  local config_file="${SITE_ENABLED_DIR}/${domain}.conf"

  # Select appropriate static template
  local template_name="nginx-static"
  [[ "$ssl_enabled" == "false" ]] && template_name="nginx-static-http"

  # Allow override via CUSTOM_TEMPLATE_PATH
  local template_file
  if [[ -n "$CUSTOM_TEMPLATE_PATH" ]]; then
    if [[ -f "$CUSTOM_TEMPLATE_PATH" ]]; then
      template_file="$CUSTOM_TEMPLATE_PATH"
    else
      warning "Custom template not found: $CUSTOM_TEMPLATE_PATH"
      return 1
    fi
  else
    template_file="${TEMPLATE_DIR}/${template_name}.stub"
    if [[ ! -f "$template_file" ]]; then
      error "Template not found: $template_file"
      return 1
    fi
  fi

  # Backup existing config if present
  if [[ -f "$config_file" ]] && [[ "$BACKUP_CONFIGS" == "true" ]]; then
    cp "$config_file" "${config_file}.bak.$(date +%Y%m%d_%H%M%S)"
    info "Backed up existing configuration"
  fi

  cp "$template_file" "$config_file"

  sed -i.tmp "s|{{DOMAIN}}|$domain|g" "$config_file"
  sed -i.tmp "s|{{CERTIFICATE_NAME_FILE}}|$cert_domain|g" "$config_file"
  sed -i.tmp "s|{{STATIC_ROOT}}|$static_root|g" "$config_file"
  sed -i.tmp "s|{{SSL_DIR}}|$(get_nginx_ssl_dir)|g" "$config_file"
  rm -f "${config_file}.tmp"

  success "Static configuration created: $config_file"

  # Deploy configuration based on mode
  case "$mode" in
  docker)
    deploy_config_docker "$domain" "$config_file"
    ;;
  local)
    deploy_config_local "$domain" "$config_file"
    ;;
  esac

  local result=$?

  if [[ $result -eq 0 ]] && [[ "$AUTO_RELOAD" == "true" ]]; then
    reload_nginx
  fi

  return $result
}

# List nginx site configurations
list_site_configs() {
  info "Nginx site configurations:"

  if [[ -d "$SITE_ENABLED_DIR" ]]; then
    find "$SITE_ENABLED_DIR" -name "*.conf" -type f | while read -r conf; do
      local name=$(basename "$conf" .conf)

      # Detect static vs proxy config
      if grep -q "^\s*root " "$conf" && ! grep -q "proxy_pass" "$conf"; then
        local root_path
        root_path=$(grep -m1 "^\s*root " "$conf" | awk '{print $2}' | tr -d ';' 2>/dev/null || echo "N/A")
        local ssl_status="No SSL"
        grep -q "ssl_certificate" "$conf" && ssl_status="SSL"
        echo "  - $name (static: $root_path, $ssl_status)"
      else
        local port
        port=$(grep -m1 "proxy_pass" "$conf" | grep -o ':[0-9]*' | tail -1 | tr -d ':' 2>/dev/null || echo "N/A")
        local ssl_status="No SSL"
        grep -q "ssl_certificate" "$conf" && ssl_status="SSL"
        echo "  - $name (port: $port, $ssl_status)"
      fi
    done
  else
    warning "Site configuration directory not found"
  fi
}