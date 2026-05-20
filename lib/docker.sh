#!/bin/bash
# lib/docker.sh

# Docker management functions

# Check if Docker is available
is_docker_available() {
  command_exists docker && docker info &>/dev/null
}

# Check if Docker container exists
docker_container_exists() {
  local container_name="$1"
  docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"
}

# Check if Docker container is running
is_docker_container_running() {
  local container_name="$1"
  docker ps --format '{{.Names}}' | grep -q "^${container_name}$"
}

# Get Docker gateway IP
get_docker_gateway_ip() {
  docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "172.17.0.1"
}

# Get Docker host address for proxy_pass
get_docker_host_address() {
  local os=$(detect_os)

  case "$DOCKER_HOST_ACCESS" in
  auto)
    if [[ "$os" == "linux" ]]; then
      # Linux: use gateway IP
      echo "$(get_docker_gateway_ip)"
    else
      # macOS/Windows: use host.docker.internal
      echo "host.docker.internal"
    fi
    ;;
  gateway)
    echo "$(get_docker_gateway_ip)"
    ;;
  host.docker.internal)
    echo "host.docker.internal"
    ;;
  custom)
    echo "$DOCKER_CUSTOM_HOST_IP"
    ;;
  *)
    error "Invalid DOCKER_HOST_ACCESS setting: $DOCKER_HOST_ACCESS"
    return 1
    ;;
  esac
}

# Determine proxy mode
determine_proxy_mode() {
  case "$PROXY_MODE" in
  docker)
    if ! is_docker_available; then
      error "Docker is not available, but PROXY_MODE is set to 'docker'"
      return 1
    fi
    if ! is_docker_container_running "$DOCKER_CONTAINER_NAME"; then
      error "Docker container '$DOCKER_CONTAINER_NAME' is not running"
      return 1
    fi
    echo "docker"
    ;;
  local)
    if ! command_exists "$NGINX_BIN"; then
      error "Nginx is not installed, but PROXY_MODE is set to 'local'"
      return 1
    fi
    echo "local"
    ;;
  auto)
    if is_docker_available && is_docker_container_running "$DOCKER_CONTAINER_NAME"; then
      info "Auto-detected: Using Docker mode"
      echo "docker"
    elif command_exists "$NGINX_BIN"; then
      info "Auto-detected: Using local Nginx mode"
      echo "local"
    else
      error "Neither Docker nor local Nginx is available"
      return 1
    fi
    ;;
  *)
    error "Invalid PROXY_MODE: $PROXY_MODE"
    return 1
    ;;
  esac
}

# Copy file to Docker container
docker_copy_to_container() {
  local source="$1"
  local dest="$2"
  local container="${3:-$DOCKER_CONTAINER_NAME}"

  if ! is_docker_container_running "$container"; then
    error "Container '$container' is not running"
    return 1
  fi

  docker cp "$source" "${container}:${dest}"
}

# Copy file from Docker container
docker_copy_from_container() {
  local source="$1"
  local dest="$2"
  local container="${3:-$DOCKER_CONTAINER_NAME}"

  if ! is_docker_container_running "$container"; then
    error "Container '$container' is not running"
    return 1
  fi

  docker cp "${container}:${source}" "$dest"
}

# Execute command in Docker container
docker_exec() {
  local container="${1:-$DOCKER_CONTAINER_NAME}"
  shift
  local cmd="$*"

  if ! is_docker_container_running "$container"; then
    error "Container '$container' is not running"
    return 1
  fi

  docker exec "$container" $cmd
}

# Create directory in Docker container
docker_mkdir() {
  local dir="$1"
  local container="${2:-$DOCKER_CONTAINER_NAME}"

  docker_exec "$container" mkdir -p "$dir"
}

# Remove file in Docker container
docker_rm() {
  local path="$1"
  local container="${2:-$DOCKER_CONTAINER_NAME}"

  docker_exec "$container" rm -f "$path" 2>/dev/null
}

# Test nginx configuration in Docker
docker_nginx_test() {
  local container="${1:-$DOCKER_CONTAINER_NAME}"

  info "Testing Nginx configuration in Docker..."
  if docker_exec "$container" nginx -t 2>&1; then
    return 0
  else
    return 1
  fi
}

# Reload nginx in Docker
docker_nginx_reload() {
  local container="${1:-$DOCKER_CONTAINER_NAME}"

  info "Reloading Nginx in Docker container..."
  if docker_nginx_test "$container"; then
    docker_exec "$container" nginx -s reload
    success "Nginx reloaded successfully in Docker"
    return 0
  else
    error "Nginx configuration test failed"
    return 1
  fi
}