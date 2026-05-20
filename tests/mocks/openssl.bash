#!/bin/bash
# tests/mocks/openssl.bash
# Mock OpenSSL commands for testing

# Mock openssl command
openssl_mock() {
    local subcmd="$1"
    shift
    
    case "$subcmd" in
        req)
            # Certificate generation request
            local keyout=""
            local out=""
            
            # Parse arguments
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -keyout)
                        keyout="$2"
                        shift 2
                        ;;
                    -out)
                        out="$2"
                        shift 2
                        ;;
                    *)
                        shift
                        ;;
                esac
            done
            
            # Create mock certificate files
            if [[ -n "$keyout" ]]; then
                cat > "$keyout" << 'EOF'
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7VJTUt9Us8cKj
MzEfYyjiWA4R4/M2bS1+fWIcPm15j5xJv1nMvp9Uv0zLv5nMvp9Uv0zL
-----END PRIVATE KEY-----
EOF
            fi
            
            if [[ -n "$out" ]]; then
                cat > "$out" << 'EOF'
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAJC1HiIAZAiIMA0GCSqGSIb3DQEBBQUAMEUxCzAJBgNV
BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
-----END CERTIFICATE-----
EOF
            fi
            
            return 0
            ;;
            
        x509)
            # Certificate operations
            local in_file=""
            local checkend=""
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -in)
                        in_file="$2"
                        shift 2
                        ;;
                    -checkend)
                        checkend="$2"
                        shift 2
                        ;;
                    -noout)
                        shift
                        ;;
                    -subject)
                        echo "subject=CN=test.local"
                        shift
                        ;;
                    -issuer)
                        echo "issuer=CN=test.local"
                        shift
                        ;;
                    -startdate)
                        echo "notBefore=Jan  1 00:00:00 2024 GMT"
                        shift
                        ;;
                    -enddate)
                        echo "notAfter=Jan  1 00:00:00 2034 GMT"
                        shift
                        ;;
                    *)
                        shift
                        ;;
                esac
            done
            
            # Check if certificate is expired
            if [[ -n "$checkend" ]]; then
                # Mock: certificate is valid
                return 0
            fi
            
            return 0
            ;;
            
        *)
            # Unknown subcommand
            return 0
            ;;
    esac
}

# Export the mock function
export -f openssl_mock

# Setup openssl mock
setup_openssl_mock() {
    # Save original openssl if exists
    if command -v openssl &>/dev/null; then
        export ORIGINAL_OPENSSL="$(command -v openssl)"
    fi
    
    # Replace openssl with mock
    openssl() {
        openssl_mock "$@"
    }
    export -f openssl
}

# Teardown openssl mock
teardown_openssl_mock() {
    # Restore original openssl if it existed
    if [[ -n "${ORIGINAL_OPENSSL:-}" ]]; then
        openssl() {
            "$ORIGINAL_OPENSSL" "$@"
        }
        export -f openssl
    else
        unset -f openssl
    fi
}

# Simulate openssl not available
simulate_openssl_unavailable() {
    openssl() {
        echo "openssl: command not found" >&2
        return 127
    }
    export -f openssl
}

# Simulate certificate expired
simulate_certificate_expired() {
    openssl() {
        local subcmd="$1"
        shift
        
        if [[ "$subcmd" == "x509" ]] && [[ "$*" == *"checkend"* ]]; then
            echo "Certificate will expire" >&2
            return 1
        else
            openssl_mock "$subcmd" "$@"
        fi
    }
    export -f openssl
}

# Simulate certificate generation failure
simulate_cert_generation_failure() {
    openssl() {
        local subcmd="$1"
        
        if [[ "$subcmd" == "req" ]]; then
            echo "Error generating certificate" >&2
            return 1
        else
            openssl_mock "$@"
        fi
    }
    export -f openssl
}
