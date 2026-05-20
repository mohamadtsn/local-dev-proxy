#!/usr/bin/env bats
# tests/e2e/test_create_domain.bats
# End-to-end tests for complete domain creation workflow

load '../test_helper'
load '../mocks/docker'
load '../mocks/nginx'
load '../mocks/openssl'

setup() {
    common_setup
    
    # Load all required libraries
    load_lib "common"
    load_lib "docker"
    load_lib "nginx"
    load_lib "certificate"
    load_lib "hosts"
    
    # Create test templates
    create_test_templates
    
    # Setup all mocks
    setup_docker_mock
    setup_nginx_mock
    setup_openssl_mock

    # Mock check_root to avoid sudo requirement in tests
    check_root() { return 0; }
    export -f check_root
}

teardown() {
    teardown_openssl_mock
    teardown_nginx_mock
    teardown_docker_mock
    common_teardown
}

# ============================================================================
# Complete domain creation workflow tests
# ============================================================================

@test "E2E: create HTTP-only domain in local mode" {
    export PROXY_MODE="local"
    export DEFAULT_SSL_ENABLED="false"
    
    local domain="myapp.local"
    local port="3000"
    
    # Create nginx configuration
    run create_site_config "$domain" "$port" "$domain" "false"
    assert_success
    
    # Verify config file exists
    assert_file_exist "${SITE_ENABLED_DIR}/${domain}.conf"
    
    # Verify config content
    assert_file_contains "${SITE_ENABLED_DIR}/${domain}.conf" "server_name ${domain}"
    assert_file_contains "${SITE_ENABLED_DIR}/${domain}.conf" "listen 80"
    assert_file_not_contains "${SITE_ENABLED_DIR}/${domain}.conf" "listen 443"
    
    # Verify nginx can be tested
    run test_nginx_config
    assert_success
}

@test "E2E: create HTTPS domain with SSL certificate in local mode" {
    export PROXY_MODE="local"
    export DEFAULT_SSL_ENABLED="true"
    
    local domain="secure.local"
    local port="3000"
    
    # Generate certificate
    run generate_certificate "$domain"
    assert_success
    
    # Verify certificate files exist
    assert_file_exist "${CERT_DIR}/${domain}.crt"
    assert_file_exist "${CERT_DIR}/${domain}.key"
    
    # Create nginx configuration with SSL
    run create_site_config "$domain" "$port" "$domain" "true"
    assert_success
    
    # Verify config file exists
    assert_file_exist "${SITE_ENABLED_DIR}/${domain}.conf"
    
    # Verify SSL configuration
    assert_file_contains "${SITE_ENABLED_DIR}/${domain}.conf" "listen 443 ssl"
    assert_file_contains "${SITE_ENABLED_DIR}/${domain}.conf" "ssl_certificate"
    assert_file_contains "${SITE_ENABLED_DIR}/${domain}.conf" "ssl_certificate_key"
    
    # Verify nginx configuration is valid
    run test_nginx_config
    assert_success
}

@test "E2E: create domain with subdomain using shared certificate" {
    export PROXY_MODE="local"
    export DEFAULT_SSL_ENABLED="true"
    
    local main_domain="myapp.local"
    local subdomain="api.myapp.local"
    local port="8080"
    
    # Generate certificate for main domain
    run generate_certificate "$main_domain"
    assert_success
    
    # Create subdomain config using main domain certificate
    run create_site_config "$subdomain" "$port" "$main_domain" "true"
    assert_success
    
    # Verify subdomain config exists
    assert_file_exist "${SITE_ENABLED_DIR}/${subdomain}.conf"
    
    # Verify it uses the main domain certificate
    assert_file_contains "${SITE_ENABLED_DIR}/${subdomain}.conf" "${main_domain}.crt"
    assert_file_contains "${SITE_ENABLED_DIR}/${subdomain}.conf" "${main_domain}.key"
}

@test "E2E: create domain in docker mode" {
    export PROXY_MODE="docker"
    export DEFAULT_SSL_ENABLED="false"
    
    local domain="docker.local"
    local port="3000"
    
    # Create nginx configuration
    run create_site_config "$domain" "$port" "$domain" "false"
    assert_success
    
    # Verify config file exists locally
    assert_file_exist "${SITE_ENABLED_DIR}/${domain}.conf"
    
    # Verify it uses docker host address
    local config_content="$(cat ${SITE_ENABLED_DIR}/${domain}.conf)"
    
    # Should not use localhost in docker mode
    if [[ "$config_content" =~ "proxy_pass http://127.0.0.1" ]]; then
        # This would be incorrect for docker mode
        fail "Docker mode should not use 127.0.0.1"
    fi
}

@test "E2E: create multiple domains with different ports" {
    export PROXY_MODE="local"
    
    # Create three different applications
    local domains=("app1.local" "app2.local" "app3.local")
    local ports=("3000" "4000" "5000")
    
    for i in {0..2}; do
        run create_site_config "${domains[$i]}" "${ports[$i]}" "${domains[$i]}" "false"
        assert_success
    done
    
    # Verify all configs exist
    for domain in "${domains[@]}"; do
        assert_file_exist "${SITE_ENABLED_DIR}/${domain}.conf"
    done
    
    # Verify each has correct port
    for i in {0..2}; do
        assert_file_contains "${SITE_ENABLED_DIR}/${domains[$i]}.conf" "${ports[$i]}"
    done
}

@test "E2E: update existing domain configuration" {
    export PROXY_MODE="local"
    export BACKUP_CONFIGS="true"
    
    local domain="updateme.local"
    
    # Create initial configuration
    run create_site_config "$domain" "3000" "$domain" "false"
    assert_success
    
    # Update with different port
    run create_site_config "$domain" "8080" "$domain" "false"
    assert_success
    
    # Verify backup was created
    run bash -c "ls ${SITE_ENABLED_DIR}/${domain}.conf.bak.* 2>/dev/null"
    assert_success
    
    # Verify new port is in config
    assert_file_contains "${SITE_ENABLED_DIR}/${domain}.conf" "8080"
}

@test "E2E: remove domain completely" {
    export PROXY_MODE="local"
    
    local domain="removeme.local"
    local port="3000"
    
    # Create domain with certificate
    generate_certificate "$domain"
    create_site_config "$domain" "$port" "$domain" "true"
    
    # Verify everything exists
    assert_file_exist "${CERT_DIR}/${domain}.crt"
    assert_file_exist "${SITE_ENABLED_DIR}/${domain}.conf"
    
    # Remove nginx config
    run remove_site_config "$domain"
    assert_success
    
    # Remove certificate
    run remove_certificate "$domain"
    assert_success
}

@test "E2E: handle invalid inputs gracefully" {
    export PROXY_MODE="local"
    
    # Test invalid domain
    run create_site_config "invalid domain!" "3000" "test.local" "false"
    assert_failure
    
    # Test invalid port
    run create_site_config "test.local" "invalid" "test.local" "false"
    assert_failure
    
    # Test empty domain
    run create_site_config "" "3000" "test.local" "false"
    assert_failure
    
    # Test empty port
    run create_site_config "test.local" "" "test.local" "false"
    assert_failure
}

@test "E2E: auto mode selection works correctly" {
    export PROXY_MODE="auto"
    
    # With docker available, should use docker
    run determine_proxy_mode
    assert_success
    assert_output --partial "docker"
    
    local domain="auto.local"
    run create_site_config "$domain" "3000" "$domain" "false"
    assert_success
}

@test "E2E: certificate validation works" {
    export PROXY_MODE="local"
    local domain="validate.local"

    # Generate certificate
    run generate_certificate "$domain"
    assert_success
    
    # Verify certificate
    run verify_certificate "${CERT_DIR}/${domain}.crt"
    assert_success
    assert_output --partial "valid"
}

@test "E2E: hosts file management" {
    local domain="hosts.local"
    local ip="127.0.0.1"
    
    # Add to hosts file (using test hosts file)
    run add_host "$ip" "$domain"
    assert_success
    
    # Verify entry exists
    run grep "$domain" "$HOSTS_FILE"
    assert_success
    assert_output --partial "$ip"
    
    # Remove from hosts file
    run remove_host "$domain"
    assert_success
    
    # Verify entry is gone
    run grep "$domain" "$HOSTS_FILE"
    assert_failure
}

@test "E2E: template customization works" {
    export PROXY_MODE="local"
    
    # Create custom template
    local custom_template="${TEST_TEMP_DIR}/custom.stub"
    cat > "$custom_template" << 'EOF'
server {
    listen 80;
    server_name {{DOMAIN}};
    
    # Custom configuration
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://{{PROXY_HOST}}:{{PORT}};
    }
}
EOF
    
    export CUSTOM_TEMPLATE_PATH="$custom_template"
    
    local domain="custom.local"
    run create_site_config "$domain" "3000" "$domain" "false"
    assert_success
    
    # Verify custom directive is in config
    assert_file_contains "${SITE_ENABLED_DIR}/${domain}.conf" "client_max_body_size 100M"
}

# ============================================================================
# Error recovery tests
# ============================================================================

@test "E2E: recover from certificate generation failure" {
    local domain="failcert.local"
    
    # Simulate certificate generation failure
    simulate_cert_generation_failure
    
    run generate_certificate "$domain"
    assert_failure
    
    # Verify no certificate files were created
    assert_file_not_exist "${CERT_DIR}/${domain}.crt"
    assert_file_not_exist "${CERT_DIR}/${domain}.key"
}

@test "E2E: recover from nginx config test failure" {
    export PROXY_MODE="local"
    simulate_nginx_test_failure
    
    local domain="failconfig.local"
    
    # Config creation should succeed (it's the test that fails)
    run create_site_config "$domain" "3000" "$domain" "false"
    assert_success
    
    # But nginx test should fail
    run test_nginx_config
    assert_failure
}

# ============================================================================
# Cross-platform compatibility tests
# ============================================================================

@test "E2E: works on current platform" {
    local os="$(detect_os)"
    
    # Test should run on any platform
    case "$os" in
        linux|macos|windows)
            # Create a simple domain
            export PROXY_MODE="local"
            run create_site_config "platform.local" "3000" "platform.local" "false"
            assert_success
            ;;
        *)
            skip "Unknown platform: $os"
            ;;
    esac
}
