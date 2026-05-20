#!/bin/bash
# lib/config.sh

# Configuration management functions

# Load all configurations
load_all_configs() {
    # Load default config
    if [[ -f "${CONFIG_DIR}/default.conf" ]]; then
        source "${CONFIG_DIR}/default.conf"
    fi
    
    # Load user config (overrides defaults)
    if [[ -f "$HOME/.local-dev-proxy.conf" ]]; then
        source "$HOME/.local-dev-proxy.conf"
    fi
}

# Initialize directories
init_directories() {
    ensure_directory "$CERT_DIR"
    ensure_directory "$SITE_ENABLED_DIR"
    ensure_directory "$TEMPLATE_DIR"
    ensure_directory "$(dirname "$LOG_FILE")"
}

# Validate configuration
validate_config() {
    local errors=0
    
    # Check proxy mode
    if [[ ! "$PROXY_MODE" =~ ^(docker|local|auto)$ ]]; then
        error "Invalid PROXY_MODE: $PROXY_MODE"
        ((errors++))
    fi
    
    # Check docker host access
    if [[ ! "$DOCKER_HOST_ACCESS" =~ ^(auto|gateway|host.docker.internal|custom)$ ]]; then
        error "Invalid DOCKER_HOST_ACCESS: $DOCKER_HOST_ACCESS"
        ((errors++))
    fi
    
    # Check if required commands exist
    if ! command_exists openssl; then
        error "OpenSSL is not installed"
        ((errors++))
    fi
    
    return $errors
}

# Display configuration summary
show_config_summary() {
    local mode=$(determine_proxy_mode 2>/dev/null || echo "unknown")
    
    info "Configuration Summary:"
    info "  Mode: $mode"
    info "  SSL Default: $DEFAULT_SSL_ENABLED"
    info "  Auto Reload: $AUTO_RELOAD"
}

# Create user config file
create_user_config() {
    local config_file="$HOME/.local-dev-proxy.conf"
    
    if [[ -f "$config_file" ]]; then
        warning "User config already exists: $config_file"
        return 1
    fi
    
    cat > "$config_file" << 'EOF'
# Local Dev Proxy User Configuration
# This file overrides default settings

# Proxy mode: docker, local, or auto
# export PROXY_MODE="auto"

# Docker settings
# export DOCKER_CONTAINER_NAME="nginx-main"
# export DOCKER_HOST_ACCESS="auto"

# SSL settings
# export SSL_COUNTRY="US"
# export SSL_STATE="California"
# export SSL_ORGANIZATION="Development"

# Defaults
# export DEFAULT_SSL_ENABLED="true"
# export AUTO_RELOAD="true"

# Custom template
# export CUSTOM_TEMPLATE_PATH="/path/to/template.stub"
EOF
    
    success "Created user config: $config_file"
    info "Edit this file to customize your settings"
}

# Edit user config
edit_user_config() {
    local config_file="$HOME/.local-dev-proxy.conf"
    
    if [[ ! -f "$config_file" ]]; then
        if confirm "User config doesn't exist. Create it?" "y"; then
            create_user_config
        else
            return 1
        fi
    fi
    
    local editor="${EDITOR:-nano}"
    if ! command_exists "$editor"; then
        editor="vi"
    fi
    
    "$editor" "$config_file"
}

# Reset user config
reset_user_config() {
    local config_file="$HOME/.local-dev-proxy.conf"
    
    if [[ -f "$config_file" ]]; then
        if confirm "This will delete your user configuration. Continue?" "n"; then
            mv "$config_file" "${config_file}.bak.$(date +%Y%m%d_%H%M%S)"
            success "User config backed up and removed"
        fi
    else
        info "No user config found"
    fi
}
