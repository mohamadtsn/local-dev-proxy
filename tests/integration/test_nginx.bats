#!/usr/bin/env bats
# tests/integration/test_nginx.bats
# Integration tests for Nginx configuration management

load '../test_helper'
load '../mocks/docker'
load '../mocks/nginx'

setup() {
    common_setup
    load_lib "common"
    load_lib "docker"
    load_lib "nginx"

    create_test_templates

    setup_docker_mock
    setup_nginx_mock

    # Mock check_root to avoid sudo requirement
    check_root() { return 0; }
    export -f check_root
}

teardown() {
    teardown_nginx_mock
    teardown_docker_mock
    common_teardown
}

# ============================================================================
# get_template_path tests
# ============================================================================

@test "get_template_path: returns HTTP template when SSL disabled" {
    export DEFAULT_TEMPLATE="nginx-mixed"
    run get_template_path "false"
    assert_success
    assert_output "${TEMPLATE_DIR}/nginx-http.stub"
}

@test "get_template_path: returns HTTPS template when SSL enabled" {
    export DEFAULT_TEMPLATE="nginx-mixed"
    run get_template_path "true"
    assert_success
    assert_output "${TEMPLATE_DIR}/nginx-https.stub"
}

@test "get_template_path: returns custom template when specified" {
    local custom_template="${TEST_TEMP_DIR}/custom.stub"
    echo "custom template" > "$custom_template"
    
    export CUSTOM_TEMPLATE_PATH="$custom_template"
    run get_template_path "true"
    assert_success
    assert_output "$custom_template"
}

@test "get_template_path: returns error for non-existing custom template" {
    export CUSTOM_TEMPLATE_PATH="/non/existing/template.stub"
    run get_template_path "true"
    assert_failure
}

@test "get_template_path: returns error for non-existing default template" {
    export DEFAULT_TEMPLATE="non-existing-template"
    export CUSTOM_TEMPLATE_PATH=""
    run get_template_path ""
    assert_failure
    assert_output --partial "Template not found"
}

# ============================================================================
# get_proxy_host tests
# ============================================================================

@test "get_proxy_host: returns localhost for local mode" {
    export PROXY_MODE="local"
    
    # Mock nginx command
    nginx() { return 0; }
    export -f nginx
    
    run get_proxy_host
    assert_success
    assert_output "127.0.0.1"
    
    unset -f nginx
}

@test "get_proxy_host: returns docker host for docker mode" {
    export PROXY_MODE="docker"
    run get_proxy_host
    assert_success
    # Should return an IP or host.docker.internal
    [[ -n "$output" ]]
}

# ============================================================================
# create_site_config tests
# ============================================================================

@test "create_site_config: creates HTTP config successfully" {
    export PROXY_MODE="local"
    export DEFAULT_SSL_ENABLED="false"
    
    # Mock nginx
    nginx() { return 0; }
    export -f nginx
    
    run create_site_config "test.local" "3000" "test.local" "false"
    assert_success
    
    # Check if config file was created
    assert_file_exist "${SITE_ENABLED_DIR}/test.local.conf"
    
    # Check config content
    assert_file_contains "${SITE_ENABLED_DIR}/test.local.conf" "server_name test.local"
    assert_file_contains "${SITE_ENABLED_DIR}/test.local.conf" "proxy_pass http://127.0.0.1:3000"
    
    unset -f nginx
}

@test "create_site_config: creates HTTPS config with SSL" {
    export PROXY_MODE="local"
    export DEFAULT_SSL_ENABLED="true"
    
    # Mock nginx
    nginx() { return 0; }
    export -f nginx
    
    run create_site_config "test.local" "3000" "test.local" "true"
    assert_success
    
    # Check if config file was created
    assert_file_exist "${SITE_ENABLED_DIR}/test.local.conf"
    
    # Check config content for SSL
    assert_file_contains "${SITE_ENABLED_DIR}/test.local.conf" "listen 443 ssl"
    assert_file_contains "${SITE_ENABLED_DIR}/test.local.conf" "ssl_certificate"
    
    unset -f nginx
}

@test "create_site_config: replaces placeholders correctly" {
    export PROXY_MODE="local"
    
    # Mock nginx
    nginx() { return 0; }
    export -f nginx
    
    run create_site_config "myapp.local" "8080" "myapp.local" "false"
    assert_success
    
    local config_file="${SITE_ENABLED_DIR}/myapp.local.conf"
    assert_file_exist "$config_file"
    
    # Check all placeholders were replaced
    run grep "{{" "$config_file"
    assert_failure  # Should not contain any {{placeholder}}
    
    # Check actual values
    assert_file_contains "$config_file" "server_name myapp.local"
    assert_file_contains "$config_file" "proxy_pass http://127.0.0.1:8080"
    
    unset -f nginx
}

@test "create_site_config: returns error for empty domain" {
    run create_site_config "" "3000" "test.local" "false"
    assert_failure
    assert_output --partial "Domain is required"
}

@test "create_site_config: returns error for empty port" {
    run create_site_config "test.local" "" "test.local" "false"
    assert_failure
    assert_output --partial "Port is required"
}

@test "create_site_config: returns error for invalid domain" {
    run create_site_config "invalid domain!" "3000" "test.local" "false"
    assert_failure
}

@test "create_site_config: backs up existing config when enabled" {
    export BACKUP_CONFIGS="true"
    export PROXY_MODE="local"
    
    # Mock nginx
    nginx() { return 0; }
    export -f nginx
    
    # Create initial config
    create_site_config "test.local" "3000" "test.local" "false"
    
    # Create again to trigger backup
    run create_site_config "test.local" "8080" "test.local" "false"
    assert_success
    
    # Check if backup was created
    run bash -c "ls ${SITE_ENABLED_DIR}/test.local.conf.bak.* 2>/dev/null"
    assert_success
    
    unset -f nginx
}

# ============================================================================
# remove_site_config tests
# ============================================================================

@test "remove_site_config: removes config successfully" {
    export PROXY_MODE="local"
    
    # Mock nginx
    nginx() { return 0; }
    export -f nginx
    
    # Create config first
    create_site_config "test.local" "3000" "test.local" "false"
    assert_file_exist "${SITE_ENABLED_DIR}/test.local.conf"
    
    # Remove it
    run remove_site_config "test.local"
    assert_success
    
    unset -f nginx
}

@test "remove_site_config: returns error for empty domain" {
    run remove_site_config ""
    assert_failure
    assert_output --partial "Domain is required"
}

@test "remove_site_config: succeeds for non-existing config" {
    export PROXY_MODE="local"
    
    # Mock nginx
    nginx() { return 0; }
    export -f nginx
    
    run remove_site_config "non-existing.local"
    assert_success
    
    unset -f nginx
}

# ============================================================================
# test_nginx_config tests
# ============================================================================

@test "test_nginx_config: returns success for valid config in local mode" {
    export PROXY_MODE="local"
    
    run test_nginx_config
    assert_success
    assert_output --partial "valid"
}

@test "test_nginx_config: returns success for valid config in docker mode" {
    export PROXY_MODE="docker"
    
    run test_nginx_config
    assert_success
}

@test "test_nginx_config: returns failure for invalid config" {
    export PROXY_MODE="local"
    simulate_nginx_test_failure
    
    run test_nginx_config
    assert_failure
}

# ============================================================================
# reload_nginx tests
# ============================================================================

@test "reload_nginx: reloads successfully in local mode" {
    export PROXY_MODE="local"
    
    run reload_nginx
    assert_success
    assert_output --partial "reload"
}

@test "reload_nginx: reloads successfully in docker mode" {
    export PROXY_MODE="docker"
    
    run reload_nginx
    assert_success
}

@test "reload_nginx: fails when config test fails" {
    export PROXY_MODE="local"
    simulate_nginx_test_failure
    
    run reload_nginx
    assert_failure
    assert_output --partial "configuration errors"
}

# ============================================================================
# list_site_configs tests
# ============================================================================

@test "list_site_configs: lists all configurations" {
    export PROXY_MODE="local"
    
    # Mock nginx
    nginx() { return 0; }
    export -f nginx
    
    # Create multiple configs
    create_site_config "app1.local" "3000" "app1.local" "false"
    create_site_config "app2.local" "8080" "app2.local" "true"
    
    run list_site_configs
    assert_success
    assert_output --partial "app1.local"
    assert_output --partial "app2.local"
    
    unset -f nginx
}

@test "list_site_configs: shows port numbers" {
    export PROXY_MODE="local"
    
    # Mock nginx
    nginx() { return 0; }
    export -f nginx
    
    create_site_config "test.local" "3000" "test.local" "false"
    
    run list_site_configs
    assert_success
    assert_output --partial "3000"
    
    unset -f nginx
}

@test "list_site_configs: shows SSL status" {
    export PROXY_MODE="local"
    
    # Mock nginx
    nginx() { return 0; }
    export -f nginx
    
    # Create HTTP-only site
    create_site_config "http.local" "3000" "http.local" "false"
    
    # Create HTTPS site
    create_site_config "https.local" "8080" "https.local" "true"
    
    run list_site_configs
    assert_success
    
    # Check output mentions SSL
    assert_output --regexp "(SSL|No SSL)"
    
    unset -f nginx
}

# ============================================================================
# Docker mode integration tests
# ============================================================================

@test "create_site_config: works in docker mode" {
    export PROXY_MODE="docker"
    
    run create_site_config "docker.local" "3000" "docker.local" "false"
    assert_success
    
    # Config should be created locally
    assert_file_exist "${SITE_ENABLED_DIR}/docker.local.conf"
}

@test "create_site_config: uses docker host address in docker mode" {
    export PROXY_MODE="docker"
    export DOCKER_HOST_ACCESS="gateway"
    
    run create_site_config "docker.local" "3000" "docker.local" "false"
    assert_success
    
    local config_file="${SITE_ENABLED_DIR}/docker.local.conf"
    
    # Should use gateway IP, not localhost
    assert_file_not_contains "$config_file" "proxy_pass http://127.0.0.1"
}
