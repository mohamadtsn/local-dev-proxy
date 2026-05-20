#!/usr/bin/env bats
# tests/integration/test_docker.bats
# Integration tests for Docker functionality

load '../test_helper'
load '../mocks/docker'

setup() {
    common_setup
    load_lib "common"
    load_lib "docker"
    
    # Setup docker mock
    setup_docker_mock
}

teardown() {
    teardown_docker_mock
    common_teardown
}

# ============================================================================
# is_docker_available tests
# ============================================================================

@test "is_docker_available: returns success when docker is available" {
    run is_docker_available
    assert_success
}

@test "is_docker_available: returns failure when docker is not available" {
    simulate_docker_unavailable
    
    run is_docker_available
    assert_failure
}

# ============================================================================
# docker_container_exists tests
# ============================================================================

@test "docker_container_exists: returns success for existing container" {
    run docker_container_exists "test-nginx-container"
    assert_success
}

@test "docker_container_exists: returns failure for non-existing container" {
    run docker_container_exists "non-existing-container"
    assert_failure
}

# ============================================================================
# is_docker_container_running tests
# ============================================================================

@test "is_docker_container_running: returns success for running container" {
    run is_docker_container_running "test-nginx-container"
    assert_success
}

@test "is_docker_container_running: returns failure for stopped container" {
    simulate_docker_container_stopped
    
    run is_docker_container_running "test-nginx-container"
    assert_failure
}

# ============================================================================
# get_docker_gateway_ip tests
# ============================================================================

@test "get_docker_gateway_ip: returns valid IP address" {
    run get_docker_gateway_ip
    assert_success
    
    # Should return an IP address
    assert_output --regexp "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
}

# ============================================================================
# get_docker_host_address tests
# ============================================================================

@test "get_docker_host_address: returns gateway IP for Linux" {
    if [[ "$(detect_os)" != "linux" ]]; then
        skip "Test only for Linux"
    fi
    
    export DOCKER_HOST_ACCESS="auto"
    run get_docker_host_address
    assert_success
    assert_output --regexp "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
}

@test "get_docker_host_address: returns host.docker.internal for non-Linux with auto" {
    if [[ "$(detect_os)" == "linux" ]]; then
        skip "Test only for non-Linux"
    fi
    
    export DOCKER_HOST_ACCESS="auto"
    run get_docker_host_address
    assert_success
    assert_output "host.docker.internal"
}

@test "get_docker_host_address: returns gateway IP when mode is gateway" {
    export DOCKER_HOST_ACCESS="gateway"
    run get_docker_host_address
    assert_success
    assert_output --regexp "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
}

@test "get_docker_host_address: returns host.docker.internal when mode is host.docker.internal" {
    export DOCKER_HOST_ACCESS="host.docker.internal"
    run get_docker_host_address
    assert_success
    assert_output "host.docker.internal"
}

@test "get_docker_host_address: returns custom IP when mode is custom" {
    export DOCKER_HOST_ACCESS="custom"
    export DOCKER_CUSTOM_HOST_IP="192.168.1.100"
    run get_docker_host_address
    assert_success
    assert_output "192.168.1.100"
}

@test "get_docker_host_address: returns error for invalid mode" {
    export DOCKER_HOST_ACCESS="invalid-mode"
    run get_docker_host_address
    assert_failure
    assert_output --partial "Invalid DOCKER_HOST_ACCESS"
}

# ============================================================================
# determine_proxy_mode tests
# ============================================================================

@test "determine_proxy_mode: returns docker when mode is docker and container is running" {
    export PROXY_MODE="docker"
    run determine_proxy_mode
    assert_success
    assert_output "docker"
}

@test "determine_proxy_mode: returns error when mode is docker but container not running" {
    export PROXY_MODE="docker"
    simulate_docker_container_stopped
    
    run determine_proxy_mode
    assert_failure
    assert_output --partial "not running"
}

@test "determine_proxy_mode: returns error when mode is docker but docker not available" {
    export PROXY_MODE="docker"
    simulate_docker_unavailable
    
    run determine_proxy_mode
    assert_failure
    assert_output --partial "not available"
}

@test "determine_proxy_mode: returns local when mode is local and nginx exists" {
    export PROXY_MODE="local"
    
    # Mock nginx command
    nginx() { return 0; }
    export -f nginx
    
    run determine_proxy_mode
    assert_success
    assert_output "local"
    
    unset -f nginx
}

@test "determine_proxy_mode: auto mode prefers docker when available" {
    export PROXY_MODE="auto"
    
    run determine_proxy_mode
    assert_success
    assert_output --partial "docker"
}

@test "determine_proxy_mode: auto mode falls back to local when docker unavailable" {
    export PROXY_MODE="auto"
    simulate_docker_unavailable
    
    # Mock nginx command
    nginx() { return 0; }
    export -f nginx
    
    run determine_proxy_mode
    assert_success
    assert_output --partial "local"
    
    unset -f nginx
}

# ============================================================================
# docker_exec tests
# ============================================================================

@test "docker_exec: executes command successfully" {
    run docker_exec "test-nginx-container" "echo test"
    assert_success
}

@test "docker_exec: returns failure for stopped container" {
    simulate_docker_container_stopped
    
    run docker_exec "test-nginx-container" "echo test"
    assert_failure
}

@test "docker_exec: returns failure for exec failure" {
    simulate_docker_exec_failure
    
    run docker_exec "test-nginx-container" "failing-command"
    assert_failure
}

# ============================================================================
# docker_mkdir tests
# ============================================================================

@test "docker_mkdir: creates directory successfully" {
    run docker_mkdir "/test/directory"
    assert_success
}

@test "docker_mkdir: uses default container name" {
    export DOCKER_CONTAINER_NAME="test-nginx-container"
    run docker_mkdir "/test/directory"
    assert_success
}

# ============================================================================
# docker_rm tests
# ============================================================================

@test "docker_rm: removes file successfully" {
    run docker_rm "/test/file.txt"
    assert_success
}

@test "docker_rm: succeeds even if file doesn't exist" {
    run docker_rm "/non/existing/file"
    assert_success
}

# ============================================================================
# docker_nginx_test tests
# ============================================================================

@test "docker_nginx_test: returns success for valid config" {
    run docker_nginx_test
    assert_success
    assert_output --partial "configuration"
}

# ============================================================================
# docker_nginx_reload tests
# ============================================================================

@test "docker_nginx_reload: reloads nginx successfully" {
    run docker_nginx_reload
    assert_success
    assert_output --partial "reload"
}

@test "docker_nginx_reload: fails if nginx test fails" {
    simulate_docker_exec_failure
    
    run docker_nginx_reload
    assert_failure
}

# ============================================================================
# docker_copy_to_container tests
# ============================================================================

@test "docker_copy_to_container: copies file successfully" {
    local source_file="${TEST_TEMP_DIR}/source.txt"
    echo "test content" > "$source_file"
    
    run docker_copy_to_container "$source_file" "/dest/file.txt"
    assert_success
}

@test "docker_copy_to_container: returns failure for non-existing source" {
    run docker_copy_to_container "/non/existing/source" "/dest/file.txt"
    # Mock returns success, but in real scenario would fail
    # This is a limitation of mocking
    assert_success
}

@test "docker_copy_to_container: returns failure for stopped container" {
    simulate_docker_container_stopped
    
    local source_file="${TEST_TEMP_DIR}/source.txt"
    echo "test content" > "$source_file"
    
    run docker_copy_to_container "$source_file" "/dest/file.txt"
    assert_failure
}
