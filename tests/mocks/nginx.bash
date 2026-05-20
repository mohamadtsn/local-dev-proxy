#!/bin/bash
# tests/mocks/nginx.bash
# Mock Nginx commands for testing

# Mock nginx command
nginx_mock() {
    local arg="$1"
    
    case "$arg" in
        -t)
            # Test configuration
            echo "nginx: the configuration file /etc/nginx/nginx.conf syntax is ok"
            echo "nginx: configuration file /etc/nginx/nginx.conf test is successful"
            return 0
            ;;
            
        -s)
            local signal="$2"
            case "$signal" in
                reload)
                    echo "nginx reloaded successfully"
                    return 0
                    ;;
                stop|quit)
                    echo "nginx stopped"
                    return 0
                    ;;
                *)
                    return 0
                    ;;
            esac
            ;;
            
        -v)
            echo "nginx version: nginx/1.24.0"
            return 0
            ;;
            
        *)
            return 0
            ;;
    esac
}

# Export the mock function
export -f nginx_mock

# Setup nginx mock
setup_nginx_mock() {
    # Save original nginx if exists
    if command -v nginx &>/dev/null; then
        export ORIGINAL_NGINX="$(command -v nginx)"
    fi
    
    # Replace nginx with mock
    nginx() {
        nginx_mock "$@"
    }
    export -f nginx
}

# Teardown nginx mock
teardown_nginx_mock() {
    # Restore original nginx if it existed
    if [[ -n "${ORIGINAL_NGINX:-}" ]]; then
        nginx() {
            "$ORIGINAL_NGINX" "$@"
        }
        export -f nginx
    else
        unset -f nginx
    fi
}

# Simulate nginx not available
simulate_nginx_unavailable() {
    nginx() {
        echo "nginx: command not found" >&2
        return 127
    }
    export -f nginx
}

# Simulate nginx config test failure
simulate_nginx_test_failure() {
    nginx() {
        local arg="$1"
        
        if [[ "$arg" == "-t" ]]; then
            echo "nginx: [emerg] unexpected end of file" >&2
            echo "nginx: configuration file /etc/nginx/nginx.conf test failed" >&2
            return 1
        else
            nginx_mock "$@"
        fi
    }
    export -f nginx
}

# Mock systemctl for nginx
systemctl_mock() {
    local cmd="$1"
    local service="$2"
    
    case "$cmd" in
        reload|restart|start|stop)
            if [[ "$service" == "nginx" ]]; then
                echo "nginx $cmd successful"
                return 0
            fi
            ;;
        status)
            if [[ "$service" == "nginx" ]]; then
                echo "● nginx.service - A high performance web server"
                echo "   Loaded: loaded"
                echo "   Active: active (running)"
                return 0
            fi
            ;;
    esac
    
    return 0
}

# Setup systemctl mock
setup_systemctl_mock() {
    if command -v systemctl &>/dev/null; then
        export ORIGINAL_SYSTEMCTL="$(command -v systemctl)"
    fi
    
    systemctl() {
        systemctl_mock "$@"
    }
    export -f systemctl
}

# Teardown systemctl mock
teardown_systemctl_mock() {
    if [[ -n "${ORIGINAL_SYSTEMCTL:-}" ]]; then
        systemctl() {
            "$ORIGINAL_SYSTEMCTL" "$@"
        }
        export -f systemctl
    else
        unset -f systemctl
    fi
}
