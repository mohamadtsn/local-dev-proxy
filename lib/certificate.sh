#!/bin/bash
# lib/certificate.sh

# SSL Certificate management (supports both Docker and local modes)

# Generate SSL certificate
generate_certificate() {
  local hostname="$1"

  if [[ -z "$hostname" ]]; then
    error "Hostname is required"
    return 1
  fi

  # Validate hostname
  hostname=$(validate_domain "$hostname")
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  info "Generating SSL certificate for: $hostname"

  # Ensure directories exist
  ensure_directory "$CERT_DIR" || return 1

  local key_file="${CERT_DIR}/${hostname}.key"
  local crt_file="${CERT_DIR}/${hostname}.crt"
  local cnf_file="${CERT_DIR}/${hostname}.cnf"

  # Create OpenSSL configuration
  create_openssl_config "$hostname" "$cnf_file" || return 1

  # Generate certificate
  show_progress "Generating certificate"

  if ! openssl req -new -x509 -nodes -sha256 \
    -days "$SSL_VALIDITY_DAYS" \
    -newkey rsa:$SSL_KEY_SIZE \
    -keyout "$key_file" \
    -out "$crt_file" \
    -config "$cnf_file" &>/dev/null; then
    hide_progress
    error "Failed to generate certificate"
    rm -f "$cnf_file"
    return 1
  fi

  hide_progress

  # Cleanup config file
  rm -f "$cnf_file"

  success "Certificate generated: $hostname"

  # Deploy certificate based on mode
  local mode=$(determine_proxy_mode)

  case "$mode" in
  docker)
    deploy_certificate_docker "$hostname" "$key_file" "$crt_file"
    ;;
  local)
    deploy_certificate_local "$hostname" "$key_file" "$crt_file"
    ;;
  *)
    error "Cannot determine proxy mode"
    return 1
    ;;
  esac

  local result=$?

  # Verify certificate if configured
  if [[ $result -eq 0 ]] && [[ "$VERIFY_CERTIFICATES" == "true" ]]; then
    verify_certificate "$crt_file"
  fi

  return $result
}

# Create OpenSSL configuration file
create_openssl_config() {
  local hostname="$1"
  local config_file="$2"

  cat > "$config_file" << EOF
[req]
default_bits = $SSL_KEY_SIZE
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = dn

[dn]
C = ${SSL_COUNTRY}
ST = ${SSL_STATE}
L = ${SSL_CITY}
O = ${SSL_ORGANIZATION}
OU = ${SSL_ORGANIZATION_UNIT}
emailAddress = ${SSL_EMAIL}
CN = ${hostname}

[v3_req]
subjectAltName = @alt_names
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = ${hostname}
DNS.2 = *.${hostname}
EOF

  return 0
}

# Deploy certificate to Docker container
deploy_certificate_docker() {
  local hostname="$1"
  local key_file="$2"
  local crt_file="$3"

  if ! is_docker_container_running "$DOCKER_CONTAINER_NAME"; then
    error "Docker container is not running: $DOCKER_CONTAINER_NAME"
    return 1
  fi

  info "Deploying certificate to Docker container..."

  # Ensure SSL directory exists in container
  docker_mkdir "$DOCKER_SSL_PATH" || return 1

  # Remove old certificates if exist
  docker_rm "${DOCKER_SSL_PATH}/${hostname}.key"
  docker_rm "${DOCKER_SSL_PATH}/${hostname}.crt"

  # Copy new certificates
  if ! docker_copy_to_container "$key_file" "${DOCKER_SSL_PATH}/${hostname}.key"; then
    error "Failed to copy key to container"
    return 1
  fi

  if ! docker_copy_to_container "$crt_file" "${DOCKER_SSL_PATH}/${hostname}.crt"; then
    error "Failed to copy certificate to container"
    return 1
  fi

  success "Certificate deployed to Docker container"

  # Install to system if running as root (best-effort)
  if check_root; then
    install_system_certificate "$hostname" "$key_file" "$crt_file" || true
  else
    warning "Run with sudo to install certificate to system trust store"
  fi

  return 0
}

# Deploy certificate to local nginx
deploy_certificate_local() {
  local hostname="$1"
  local key_file="$2"
  local crt_file="$3"

  if ! check_root; then
    error "Root privileges required for local certificate deployment"
    return 1
  fi

  info "Deploying certificate to local system..."

  # Ensure SSL directory exists
  ensure_directory "$NGINX_SSL_DIR" || return 1

  # Copy certificates
  cp "$key_file" "${NGINX_SSL_DIR}/${hostname}.key"
  cp "$crt_file" "${NGINX_SSL_DIR}/${hostname}.crt"

  # Set proper permissions
  chmod 600 "${NGINX_SSL_DIR}/${hostname}.key"
  chmod 644 "${NGINX_SSL_DIR}/${hostname}.crt"

  success "Certificate deployed to local system"

  # Install to system trust store (best-effort, failure is non-fatal)
  install_system_certificate "$hostname" "$key_file" "$crt_file" || true

  return 0
}

# Install certificate to system trust store
install_system_certificate() {
  local hostname="$1"
  local key_file="$2"
  local crt_file="$3"
  local os=$(detect_os)

  info "Installing certificate to system trust store..."

  case "$os" in
  linux)
  # Copy to system directories
    if [[ -d "$SYSTEM_SSL_KEY_DIR" ]]; then
      cp "$key_file" "${SYSTEM_SSL_KEY_DIR}/${hostname}.key" 2>/dev/null
      chmod 600 "${SYSTEM_SSL_KEY_DIR}/${hostname}.key" 2>/dev/null
    fi

    if [[ -d "$SYSTEM_SSL_CERT_DIR" ]]; then
      cp "$crt_file" "${SYSTEM_SSL_CERT_DIR}/${hostname}.crt" 2>/dev/null
      chmod 644 "${SYSTEM_SSL_CERT_DIR}/${hostname}.crt" 2>/dev/null
    fi

    # Install to browser certificate database
    if command_exists certutil; then
      local nssdb_dir="$(dirname ${BROWSER_CERT_DB#sql:})"
      if [[ -d "$nssdb_dir" ]]; then
        # Remove old certificate if exists
        certutil -d "$BROWSER_CERT_DB" -D -n "$hostname" 2>/dev/null
        # Add new certificate
        if certutil -d "$BROWSER_CERT_DB" -A -t "CT,c,c" -n "$hostname" \
          -i "$crt_file" 2>/dev/null; then
          success "Certificate installed to browser database"
        fi
      fi
    fi

    # Update CA certificates
    if command_exists update-ca-certificates; then
      update-ca-certificates 2>/dev/null
    elif command_exists update-ca-trust; then
      update-ca-trust 2>/dev/null
    fi
    ;;

  macos)
  # Add to system keychain
    if security add-trusted-cert -d -r trustRoot \
      -k /Library/Keychains/System.keychain "$crt_file" 2>/dev/null; then
      success "Certificate added to macOS keychain"
    else
      warning "Failed to add certificate to keychain (may need manual trust)"
    fi
    ;;

  windows)
  # Try to install using certutil
    if command_exists certutil.exe; then
      certutil.exe -addstore -user Root "$crt_file" 2>/dev/null
      success "Certificate added to Windows certificate store"
    else
      warning "Please install certificate manually (double-click and import)"
    fi
    ;;
  esac
}

# Verify certificate
verify_certificate() {
  local crt_file="$1"

  if [[ ! -f "$crt_file" ]]; then
    error "Certificate file not found: $crt_file"
    return 1
  fi

  info "Verifying certificate..."

  # Check certificate validity
  if ! openssl x509 -in "$crt_file" -noout -checkend 0 &>/dev/null; then
    error "Certificate has expired"
    return 1
  fi

  # Get certificate info
  local subject=$(openssl x509 -in "$crt_file" -noout -subject | sed 's/subject=//')
  local start=$(openssl x509 -in "$crt_file" -noout -startdate | sed 's/notBefore=//')
  local end=$(openssl x509 -in "$crt_file" -noout -enddate | sed 's/notAfter=//')

  success "Certificate is valid"
  info "  Subject: $subject"
  info "  Valid from: $start"
  info "  Valid until: $end"

  return 0
}

# Remove certificate
remove_certificate() {
  local hostname="$1"

  if [[ -z "$hostname" ]]; then
    error "Hostname is required"
    return 1
  fi

  info "Removing certificate for: $hostname"

  # Remove from local directory
  safe_remove "${CERT_DIR}/${hostname}.key" "$BACKUP_CONFIGS"
  safe_remove "${CERT_DIR}/${hostname}.crt" "$BACKUP_CONFIGS"
  safe_remove "${CERT_DIR}/${hostname}.cnf" false

  # Remove based on mode
  local mode=$(determine_proxy_mode)

  case "$mode" in
  docker)
    if is_docker_container_running "$DOCKER_CONTAINER_NAME"; then
      docker_rm "${DOCKER_SSL_PATH}/${hostname}.key"
      docker_rm "${DOCKER_SSL_PATH}/${hostname}.crt"
    fi
    ;;
  local)
    if check_root; then
      rm -f "${NGINX_SSL_DIR}/${hostname}.key" 2>/dev/null
      rm -f "${NGINX_SSL_DIR}/${hostname}.crt" 2>/dev/null
    fi
    ;;
  esac

  # Remove from system (requires root)
  if check_root; then
    rm -f "${SYSTEM_SSL_KEY_DIR}/${hostname}.key" 2>/dev/null
    rm -f "${SYSTEM_SSL_CERT_DIR}/${hostname}.crt" 2>/dev/null

    # Remove from browser database (Linux)
    if command_exists certutil; then
      certutil -d "$BROWSER_CERT_DB" -D -n "$hostname" 2>/dev/null
    fi
  fi

  success "Certificate removed: $hostname"
  return 0
}

# List certificates
list_certificates() {
  info "Certificates in ${CERT_DIR}:"
  echo ""

  if [[ ! -d "$CERT_DIR" ]]; then
    warning "Certificate directory not found"
    return 0
  fi

  local count=0

  find "$CERT_DIR" -name "*.crt" -type f | sort | while read -r cert; do
    local name=$(basename "$cert" .crt)
    local size=$(stat -f%z "$cert" 2>/dev/null || stat -c%s "$cert" 2>/dev/null || echo 0)

    # Get certificate info
    local subject=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/.*CN = //')
    local start=$(openssl x509 -in "$cert" -noout -startdate 2>/dev/null | sed 's/notBefore=//')
    local end=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | sed 's/notAfter=//')

    # Check if expired
    local status="${COLOR_GREEN}Valid${COLOR_RESET}"
    if ! openssl x509 -in "$cert" -noout -checkend 0 &>/dev/null; then
      status="${COLOR_RED}Expired${COLOR_RESET}"
    elif ! openssl x509 -in "$cert" -noout -checkend 2592000 &>/dev/null; then
      status="${COLOR_YELLOW}Expiring soon${COLOR_RESET}"
    fi

    echo -e "  ${COLOR_CYAN}$name${COLOR_RESET}"
    echo "    Status: $status"
    echo "    Valid until: $end"
    echo "    Size: $(format_size $size)"
    echo ""

    ((count++))
  done

  if [[ $count -eq 0 ]]; then
    warning "No certificates found"
  else
    info "Total: $count certificate(s)"
  fi
}

# Renew certificate (regenerate)
renew_certificate() {
  local hostname="$1"

  if [[ -z "$hostname" ]]; then
    error "Hostname is required"
    return 1
  fi

  info "Renewing certificate for: $hostname"

  # Backup old certificate
  if [[ -f "${CERT_DIR}/${hostname}.crt" ]]; then
    cp "${CERT_DIR}/${hostname}.crt" "${CERT_DIR}/${hostname}.crt.old"
    cp "${CERT_DIR}/${hostname}.key" "${CERT_DIR}/${hostname}.key.old"
  fi

  # Generate new certificate
  generate_certificate "$hostname"
}

# Check certificate expiration
check_certificate_expiry() {
  local hostname="$1"
  local days="${2:-30}"

  local cert_file="${CERT_DIR}/${hostname}.crt"

  if [[ ! -f "$cert_file" ]]; then
    error "Certificate not found: $hostname"
    return 1
  fi

  if ! openssl x509 -in "$cert_file" -noout -checkend $((days * 86400)) &>/dev/null; then
    warning "Certificate for $hostname expires within $days days"
    return 1
  fi

  return 0
}