#!/usr/bin/env bats
# tests/unit/test_minimal.bats
# Minimal test to verify BATS setup

load '../test_helper'

@test "minimal: BATS is working" {
    result="$(echo 'hello')"
    assert_equal "$result" "hello"
}

@test "minimal: test_helper loads correctly" {
    # If we got here, test_helper loaded successfully
    [ -n "$TEST_HELPER_DIR" ]
}

@test "minimal: assert functions work" {
    run echo "test"
    assert_success
    assert_output "test"
}
