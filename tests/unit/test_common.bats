#!/usr/bin/env bats
# tests/unit/test_common.bats
# Unit tests for lib/common.sh

load '../test_helper'

setup() {
    common_setup
    load_lib "common"
}

teardown() {
    common_teardown
}

# ============================================================================
# detect_os tests
# ============================================================================

@test "detect_os: returns valid OS type" {
    run detect_os
    assert_success
    
    # Should return one of: linux, macos, windows, unknown
    assert_output --regexp "^(linux|macos|windows|unknown)$"
}

# ============================================================================
# validate_domain tests
# ============================================================================

@test "validate_domain: accepts valid domain" {
    run validate_domain "myapp.local"
    assert_success
    assert_output "myapp.local"
}

@test "validate_domain: accepts subdomain" {
    run validate_domain "api.myapp.local"
    assert_success
    assert_output "api.myapp.local"
}

@test "validate_domain: accepts multi-level subdomain" {
    run validate_domain "api.v1.myapp.local"
    assert_success
    assert_output "api.v1.myapp.local"
}

@test "validate_domain: converts to lowercase" {
    run validate_domain "MyApp.LOCAL"
    assert_success
    assert_output "myapp.local"
}

@test "validate_domain: accepts domain with hyphens" {
    run validate_domain "my-app.local"
    assert_success
    assert_output "my-app.local"
}

@test "validate_domain: rejects empty domain" {
    run validate_domain ""
    assert_failure
    assert_output --partial "Domain cannot be empty"
}

@test "validate_domain: rejects domain starting with hyphen" {
    run validate_domain "-myapp.local"
    assert_failure
    assert_output --partial "Invalid domain name"
}

@test "validate_domain: rejects domain ending with hyphen" {
    run validate_domain "myapp-.local"
    assert_failure
    assert_output --partial "Invalid domain name"
}

@test "validate_domain: rejects domain with spaces" {
    run validate_domain "my app.local"
    assert_failure
}

@test "validate_domain: rejects domain with special characters" {
    run validate_domain "my@app.local"
    assert_failure
}

@test "validate_domain: rejects domain with underscore" {
    run validate_domain "my_app.local"
    assert_failure
}

# ============================================================================
# validate_port tests
# ============================================================================

@test "validate_port: accepts valid port 80" {
    run validate_port "80"
    assert_success
    assert_output "80"
}

@test "validate_port: accepts valid port 3000" {
    run validate_port "3000"
    assert_success
    assert_output "3000"
}

@test "validate_port: accepts valid port 8080" {
    run validate_port "8080"
    assert_success
    assert_output "8080"
}

@test "validate_port: accepts port 1 (minimum)" {
    run validate_port "1"
    assert_success
    assert_output "1"
}

@test "validate_port: accepts port 65535 (maximum)" {
    run validate_port "65535"
    assert_success
    assert_output "65535"
}

@test "validate_port: rejects port 0" {
    run validate_port "0"
    assert_failure
    assert_output --partial "Port must be between 1 and 65535"
}

@test "validate_port: rejects port 65536" {
    run validate_port "65536"
    assert_failure
    assert_output --partial "Port must be between 1 and 65535"
}

@test "validate_port: rejects negative port" {
    run validate_port "-1"
    assert_failure
}

@test "validate_port: rejects non-numeric port" {
    run validate_port "abc"
    assert_failure
    assert_output --partial "Invalid port number"
}

@test "validate_port: rejects empty port" {
    run validate_port ""
    assert_failure
}

@test "validate_port: rejects port with spaces" {
    run validate_port "80 80"
    assert_failure
}

# ============================================================================
# command_exists tests
# ============================================================================

@test "command_exists: returns success for existing command" {
    run command_exists "bash"
    assert_success
}

@test "command_exists: returns success for ls" {
    run command_exists "ls"
    assert_success
}

@test "command_exists: returns failure for non-existing command" {
    run command_exists "this-command-does-not-exist-12345"
    assert_failure
}

# ============================================================================
# ensure_directory tests
# ============================================================================

@test "ensure_directory: creates new directory" {
    local test_dir="${TEST_TEMP_DIR}/new_directory"
    
    run ensure_directory "$test_dir"
    assert_success
    assert_dir_exists "$test_dir"
}

@test "ensure_directory: succeeds for existing directory" {
    local test_dir="${TEST_TEMP_DIR}/existing_directory"
    mkdir -p "$test_dir"
    
    run ensure_directory "$test_dir"
    assert_success
    assert_dir_exists "$test_dir"
}

@test "ensure_directory: creates nested directories" {
    local test_dir="${TEST_TEMP_DIR}/level1/level2/level3"
    
    run ensure_directory "$test_dir"
    assert_success
    assert_dir_exists "$test_dir"
}

# ============================================================================
# confirm tests
# ============================================================================

@test "confirm: returns success for 'y' response" {
    run bash -c 'source '"${PROJECT_ROOT}"'/lib/common.sh; echo "y" | confirm "Test?"'
    assert_success
}

@test "confirm: returns success for 'Y' response" {
    run bash -c 'source '"${PROJECT_ROOT}"'/lib/common.sh; echo "Y" | confirm "Test?"'
    assert_success
}

@test "confirm: returns failure for 'n' response" {
    run bash -c 'source '"${PROJECT_ROOT}"'/lib/common.sh; echo "n" | confirm "Test?"'
    assert_failure
}

@test "confirm: returns failure for 'N' response" {
    run bash -c 'source '"${PROJECT_ROOT}"'/lib/common.sh; echo "N" | confirm "Test?"'
    assert_failure
}

@test "confirm: uses default 'y' when no input" {
    run bash -c 'source '"${PROJECT_ROOT}"'/lib/common.sh; echo "" | confirm "Test?" "y"'
    assert_success
}

@test "confirm: uses default 'n' when no input" {
    run bash -c 'source '"${PROJECT_ROOT}"'/lib/common.sh; echo "" | confirm "Test?" "n"'
    assert_failure
}

# ============================================================================
# safe_remove tests
# ============================================================================

@test "safe_remove: removes file without backup" {
    local test_file="${TEST_TEMP_DIR}/test.txt"
    echo "test content" > "$test_file"
    
    run safe_remove "$test_file" false
    assert_success
    assert_file_not_exist "$test_file"
}

@test "safe_remove: removes file with backup" {
    local test_file="${TEST_TEMP_DIR}/test.txt"
    echo "test content" > "$test_file"
    
    run safe_remove "$test_file" true
    assert_success
    assert_file_not_exist "$test_file"
    
    # Check backup was created
    run bash -c "ls ${TEST_TEMP_DIR}/test.txt.bak.* 2>/dev/null"
    assert_success
}

@test "safe_remove: succeeds for non-existing file" {
    local test_file="${TEST_TEMP_DIR}/non_existing.txt"
    
    run safe_remove "$test_file" false
    assert_success
}

# ============================================================================
# is_writable tests
# ============================================================================

@test "is_writable: returns success for writable file" {
    local test_file="${TEST_TEMP_DIR}/writable.txt"
    touch "$test_file"
    chmod 644 "$test_file"
    
    run is_writable "$test_file"
    assert_success
}

@test "is_writable: returns success for writable directory" {
    local test_dir="${TEST_TEMP_DIR}/writable_dir"
    mkdir -p "$test_dir"
    chmod 755 "$test_dir"
    
    run is_writable "$test_dir"
    assert_success
}

@test "is_writable: returns failure for read-only file" {
    local test_file="${TEST_TEMP_DIR}/readonly.txt"
    touch "$test_file"
    chmod 444 "$test_file"
    
    run is_writable "$test_file"
    assert_failure
}

# ============================================================================
# format_size tests
# ============================================================================

@test "format_size: formats bytes" {
    run format_size 500
    assert_success
    assert_output "500B"
}

@test "format_size: formats kilobytes" {
    run format_size 2048
    assert_success
    assert_output "2KB"
}

@test "format_size: formats megabytes" {
    run format_size 2097152
    assert_success
    assert_output "2MB"
}

@test "format_size: handles zero size" {
    run format_size 0
    assert_success
    assert_output "0B"
}

# ============================================================================
# get_file_mtime tests
# ============================================================================

@test "get_file_mtime: returns modification time for existing file" {
    local test_file="${TEST_TEMP_DIR}/mtime_test.txt"
    echo "test" > "$test_file"
    
    run get_file_mtime "$test_file"
    assert_success
    # Should return a numeric timestamp
    assert_output --regexp "^[0-9]+$"
}

@test "get_file_mtime: returns failure for non-existing file" {
    run get_file_mtime "${TEST_TEMP_DIR}/non_existing.txt"
    assert_failure
}

# ============================================================================
# is_file_older_than tests
# ============================================================================

@test "is_file_older_than: returns failure for recent file" {
    local test_file="${TEST_TEMP_DIR}/recent.txt"
    echo "test" > "$test_file"
    
    # File is less than 1 day old
    run is_file_older_than "$test_file" 1
    assert_failure
}

@test "is_file_older_than: returns failure for non-existing file" {
    run is_file_older_than "${TEST_TEMP_DIR}/non_existing.txt" 1
    assert_failure
}
