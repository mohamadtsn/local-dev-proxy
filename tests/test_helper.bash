#!/bin/bash
# tests/test_helper.bash
# Common test helper functions and setup

# Get the directory where this helper file is located
TEST_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load BATS libraries using absolute paths
load "${TEST_HELPER_DIR}/bats-support/load"
load "${TEST_HELPER_DIR}/bats-assert/load"
load "${TEST_HELPER_DIR}/bats-file/load"

# Project root directory (one level up from tests/)
export PROJECT_ROOT="${TEST_HELPER_DIR}/.."

# Test directories
export TEST_TEMP_DIR=""
export TEST_FIXTURES_DIR="${TEST_HELPER_DIR}/fixtures"
export TEST_MOCKS_DIR="${TEST_HELPER_DIR}/mocks"

# Common setup for all tests
common_setup() {
    # Create temporary directory for this test
    TEST_TEMP_DIR="$(mktemp -d -t local-dev-proxy-test.XXXXXX)"
    
    # Export test environment variables
    export CERT_DIR="${TEST_TEMP_DIR}/certificates"
    export SITE_ENABLED_DIR="${TEST_TEMP_DIR}/sites-enabled"
    export CONFIG_DIR="${TEST_TEMP_DIR}/config"
    export TEMPLATE_DIR="${TEST_TEMP_DIR}/config/templates"
    export LOG_FILE="${TEST_TEMP_DIR}/test.log"
    export BASE_DIR="${TEST_TEMP_DIR}"
    
    # Create test directories
    mkdir -p "$CERT_DIR"
    mkdir -p "$SITE_ENABLED_DIR"
    mkdir -p "$TEMPLATE_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Disable colors in tests
    export COLOR_RED=""
    export COLOR_GREEN=""
    export COLOR_YELLOW=""
    export COLOR_BLUE=""
    export COLOR_CYAN=""
    export COLOR_MAGENTA=""
    export COLOR_RESET=""
    
    # Set test-friendly defaults
    export BACKUP_CONFIGS="false"
    export AUTO_RELOAD="false"
    export VERIFY_CERTIFICATES="false"
    export LOG_LEVEL="ERROR"
    
    # Docker test settings
    export DOCKER_CONTAINER_NAME="test-nginx-container"
    export DOCKER_HOST_ACCESS="gateway"
    export DOCKER_SSL_PATH="/etc/nginx/ssl"
    export DOCKER_CONF_PATH="/etc/nginx/conf.d"
    
    # SSL test settings
    export SSL_COUNTRY="US"
    export SSL_STATE="TestState"
    export SSL_CITY="TestCity"
    export SSL_ORGANIZATION="Test Org"
    export SSL_ORGANIZATION_UNIT="Test Unit"
    export SSL_EMAIL="test@test.local"
    export SSL_VALIDITY_DAYS="365"
    export SSL_KEY_SIZE="2048"
    
    # Nginx test settings
    export NGINX_CONF_DIR="${TEST_TEMP_DIR}/nginx/sites-available"
    export NGINX_ENABLED_DIR="${TEST_TEMP_DIR}/nginx/sites-enabled"
    export NGINX_SSL_DIR="${TEST_TEMP_DIR}/nginx/ssl"
    export NGINX_BIN="nginx"
    mkdir -p "$NGINX_CONF_DIR" "$NGINX_ENABLED_DIR" "$NGINX_SSL_DIR"
    
    # Hosts file
    export HOSTS_FILE="${TEST_TEMP_DIR}/hosts"
    touch "$HOSTS_FILE"
    
    # Default values
    export DEFAULT_IP="127.0.0.1"
    export DEFAULT_SSL_ENABLED="true"
    export DEFAULT_TEMPLATE="nginx-mixed"
}

# Common teardown for all tests
common_teardown() {
    # Clean up temporary directory
    if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Load a library file
load_lib() {
    local lib_name="$1"
    local lib_path="${PROJECT_ROOT}/lib/${lib_name}.sh"
    
    if [[ ! -f "$lib_path" ]]; then
        echo "Library not found: $lib_path" >&2
        return 1
    fi
    
    source "$lib_path"
}

# Load project configuration
load_config() {
    local config_path="${PROJECT_ROOT}/config/default.conf"
    
    if [[ ! -f "$config_path" ]]; then
        echo "Config not found: $config_path" >&2
        return 1
    fi
    
    source "$config_path"
}

# Create a test certificate
create_test_certificate() {
    local hostname="$1"
    local cert_dir="${2:-$CERT_DIR}"
    
    mkdir -p "$cert_dir"
    
    # Create a simple self-signed certificate for testing
    openssl req -new -x509 -nodes -sha256 \
        -days 365 \
        -newkey rsa:2048 \
        -keyout "${cert_dir}/${hostname}.key" \
        -out "${cert_dir}/${hostname}.crt" \
        -subj "/C=US/ST=Test/L=Test/O=Test/CN=${hostname}" \
        2>/dev/null
}

# Create a test nginx config
create_test_nginx_config() {
    local domain="$1"
    local port="$2"
    local config_file="${SITE_ENABLED_DIR}/${domain}.conf"
    
    cat > "$config_file" << EOF
server {
    listen 80;
    server_name ${domain};
    
    location / {
        proxy_pass http://localhost:${port};
    }
}
EOF
}

# Mock docker command for tests
mock_docker() {
    export -f docker_mock
    alias docker=docker_mock
}

# Mock nginx command for tests
mock_nginx() {
    export -f nginx_mock
    alias nginx=nginx_mock
}

# Check if running on CI
is_ci() {
    [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]
}

# Skip test if not on specific OS
skip_if_not_os() {
    local required_os="$1"
    local current_os="$(uname -s)"
    
    case "$required_os" in
        linux)
            [[ "$current_os" != "Linux" ]] && skip "Test requires Linux"
            ;;
        macos)
            [[ "$current_os" != "Darwin" ]] && skip "Test requires macOS"
            ;;
        windows)
            [[ "$current_os" != *"MINGW"* ]] && [[ "$current_os" != *"CYGWIN"* ]] && skip "Test requires Windows"
            ;;
    esac
}

# Skip test if command not available
skip_if_no_command() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null || skip "Command not available: $cmd"
}

# Skip test if not root
skip_if_not_root() {
    [[ $EUID -eq 0 ]] || skip "Test requires root privileges"
}

# Skip test if docker not available
skip_if_no_docker() {
    command -v docker &>/dev/null || skip "Docker not available"
    docker info &>/dev/null || skip "Docker daemon not running"
}

# Assert file contains string
assert_file_contains() {
    local file="$1"
    local pattern="$2"
    
    assert_file_exist "$file"
    run grep -q "$pattern" "$file"
    assert_success
}

# Assert file not contains string
assert_file_not_contains() {
    local file="$1"
    local pattern="$2"
    
    assert_file_exist "$file"
    run grep -q "$pattern" "$file"
    assert_failure
}

# Create test template files
create_test_templates() {
    mkdir -p "$TEMPLATE_DIR"
    
    # HTTP template
    cat > "${TEMPLATE_DIR}/nginx-http.stub" << 'EOF'
server {
    listen 80;
    server_name {{DOMAIN}};
    
    location / {
        proxy_pass http://{{PROXY_HOST}}:{{PORT}};
    }
}
EOF

    # HTTPS template
    cat > "${TEMPLATE_DIR}/nginx-https.stub" << 'EOF'
server {
    listen 80;
    server_name {{DOMAIN}};
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name {{DOMAIN}};
    
    ssl_certificate {{SSL_DIR}}/{{CERTIFICATE_NAME_FILE}}.crt;
    ssl_certificate_key {{SSL_DIR}}/{{CERTIFICATE_NAME_FILE}}.key;
    
    location / {
        proxy_pass http://{{PROXY_HOST}}:{{PORT}};
    }
}
EOF

    # Mixed template
    cat > "${TEMPLATE_DIR}/nginx-mixed.stub" << 'EOF'
server {
    listen 80;
    server_name {{DOMAIN}};
    
    location / {
        proxy_pass http://{{PROXY_HOST}}:{{PORT}};
    }
}

server {
    listen 443 ssl;
    server_name {{DOMAIN}};
    
    ssl_certificate {{SSL_DIR}}/{{CERTIFICATE_NAME_FILE}}.crt;
    ssl_certificate_key {{SSL_DIR}}/{{CERTIFICATE_NAME_FILE}}.key;
    
    location / {
        proxy_pass http://{{PROXY_HOST}}:{{PORT}};
    }
}
EOF
}

# Print test environment info (useful for debugging)
print_test_env() {
    echo "Test Environment:"
    echo "  OS: $(uname -s)"
    echo "  Temp Dir: $TEST_TEMP_DIR"
    echo "  Project Root: $PROJECT_ROOT"
    echo "  CI: $(is_ci && echo 'Yes' || echo 'No')"
}
