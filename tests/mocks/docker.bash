#!/bin/bash
# tests/mocks/docker.bash
# Mock Docker commands for testing

# Mock docker command
docker_mock() {
    local cmd="$1"
    shift
    
    case "$cmd" in
        ps)
            # Return running containers
            if [[ "$*" == *"--format"* ]]; then
                echo "test-nginx-container"
            else
                echo "CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES"
                echo "abc123         nginx     ...       1 hour    Up        80/tcp    test-nginx-container"
            fi
            return 0
            ;;
            
        info)
            # Docker is available
            echo "Docker Info"
            return 0
            ;;
            
        exec)
            local container="$1"
            shift
            # Simulate successful command execution
            case "$*" in
                *"nginx -t"*)
                    echo "nginx: configuration file /etc/nginx/nginx.conf test is successful"
                    return 0
                    ;;
                *"nginx -s reload"*)
                    echo "nginx reloaded"
                    return 0
                    ;;
                *"mkdir"*)
                    return 0
                    ;;
                *"rm"*)
                    return 0
                    ;;
                *)
                    return 0
                    ;;
            esac
            ;;
            
        cp)
            # Simulate docker cp
            local source="$1"
            local dest="$2"
            
            # Extract container and path
            if [[ "$dest" == *":"* ]]; then
                local container="${dest%%:*}"
                local path="${dest#*:}"
                
                # Create a mock destination
                local mock_dest="${TEST_TEMP_DIR}/docker_${container}${path}"
                mkdir -p "$(dirname "$mock_dest")"
                cp "$source" "$mock_dest" 2>/dev/null || true
            fi
            return 0
            ;;
            
        network)
            if [[ "$1" == "inspect" ]]; then
                if [[ "$*" == *"--format"* ]]; then
                    echo "172.17.0.1"
                else
                    echo '{"IPAM": {"Config": [{"Gateway": "172.17.0.1"}]}}'
                fi
            fi
            return 0
            ;;
            
        *)
            # Unknown command, return success
            return 0
            ;;
    esac
}

# Export the mock function
export -f docker_mock

# Setup docker mock
setup_docker_mock() {
    # Save original docker if exists
    if command -v docker &>/dev/null; then
        export ORIGINAL_DOCKER="$(command -v docker)"
    fi
    
    # Replace docker with mock
    docker() {
        docker_mock "$@"
    }
    export -f docker
}

# Teardown docker mock
teardown_docker_mock() {
    # Restore original docker if it existed
    if [[ -n "${ORIGINAL_DOCKER:-}" ]]; then
        docker() {
            "$ORIGINAL_DOCKER" "$@"
        }
        export -f docker
    else
        unset -f docker
    fi
}

# Simulate docker not available
simulate_docker_unavailable() {
    docker() {
        echo "docker: command not found" >&2
        return 127
    }
    export -f docker
}

# Simulate docker container not running
simulate_docker_container_stopped() {
    docker() {
        local cmd="$1"
        
        if [[ "$cmd" == "ps" ]]; then
            if [[ "$*" == *"-a"* ]]; then
                echo "test-nginx-container"
            else
                # Container exists but not running
                echo ""
            fi
        else
            docker_mock "$@"
        fi
    }
    export -f docker
}

# Simulate docker exec failure
simulate_docker_exec_failure() {
    docker() {
        local cmd="$1"
        
        if [[ "$cmd" == "exec" ]]; then
            echo "Error: command failed" >&2
            return 1
        else
            docker_mock "$@"
        fi
    }
    export -f docker
}
