#!/bin/bash
# lib/common.sh

# Common utilities for local-dev-proxy

# Check if running with root privileges (returns 0/1, non-fatal)
check_root() {
    [[ $EUID -eq 0 ]]
}

# Exit with a styled error when root is required
require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo ""
        echo -e "${COLOR_RED}  ✗  This command requires root privileges${COLOR_RESET}"
        echo ""
        echo -e "  Try:  ${COLOR_CYAN}sudo devproxy $*${COLOR_RESET}"
        echo ""
        exit 1
    fi
}

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unknown";;
    esac
}

# Resolve a writable log file path — called once at startup before any log() call.
# If LOG_FILE is not writable (e.g., installed as root), falls back to user-space.
_resolve_log_file() {
    local log_dir
    log_dir="$(dirname "$LOG_FILE")"
    # Use -w test instead of a redirect; bash prints redirect errors before
    # 2>/dev/null takes effect, so the redirect trick leaks error output.
    if { [[ -f "$LOG_FILE" ]] && [[ -w "$LOG_FILE" ]]; } || \
       { [[ ! -f "$LOG_FILE" ]] && [[ -w "$log_dir" ]]; }; then
        return 0
    fi
    local fallback_dir="${XDG_STATE_HOME:-$HOME/.local/state}/local-dev-proxy"
    mkdir -p "$fallback_dir" 2>/dev/null || true
    export LOG_FILE="${fallback_dir}/devproxy.log"
}

# Logging functions with rotation
rotate_log_if_needed() {
    if [[ -f "$LOG_FILE" ]]; then
        local size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        if [[ $size -gt $LOG_MAX_SIZE ]]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            touch "$LOG_FILE"
        fi
    fi
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    rotate_log_if_needed
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}" 2>/dev/null || true

    case "${level}" in
        ERROR)   echo -e "${COLOR_RED}  ✗  ${message}${COLOR_RESET}" >&2;;
        SUCCESS) echo -e "${COLOR_GREEN}  ✓  ${message}${COLOR_RESET}";;
        WARNING) echo -e "${COLOR_YELLOW}  ⚠  ${message}${COLOR_RESET}";;
        INFO)    echo -e "${COLOR_BLUE}  ›  ${message}${COLOR_RESET}";;
        *)       echo "     ${message}";;
    esac
}

info() {
    log "INFO" "$@"
}

success() {
    log "SUCCESS" "$@"
}

warning() {
    log "WARNING" "$@"
}

error() {
    log "ERROR" "$@"
}

# Validate domain name
validate_domain() {
    local domain="$1"
    local pattern="^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$"
    
    if [[ -z "$domain" ]]; then
        error "Domain cannot be empty"
        return 1
    fi
    
    if [[ ! "$domain" =~ $pattern ]]; then
        error "Invalid domain name: $domain"
        return 1
    fi
    
    # Convert to lowercase
    echo "$domain" | tr '[:upper:]' '[:lower:]'
    return 0
}

# Validate port number
validate_port() {
    local port="$1"
    
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        error "Invalid port number: $port"
        return 1
    fi
    
    if [[ $port -lt 1 ]] || [[ $port -gt 65535 ]]; then
        error "Port must be between 1 and 65535"
        return 1
    fi
    
    echo "$port"
    return 0
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            error "Failed to create directory: $dir"
            return 1
        }
    fi
    return 0
}

# Confirm action with user
confirm() {
    local message="$1"
    local default="${2:-n}"
    local response
    
    if [[ "$default" == "y" ]]; then
        read -p "${message} [Y/n]: " -r response
        response=${response:-y}
    else
        read -p "${message} [y/N]: " -r response
        response=${response:-n}
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Safe file removal with backup
safe_remove() {
    local file="$1"
    local backup="${2:-true}"
    
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    if [[ "$backup" == "true" ]]; then
        local backup_file="${file}.bak.$(date +%Y%m%d_%H%M%S)"
        mv "$file" "$backup_file"
        info "Backed up: $backup_file"
    else
        rm -f "$file"
    fi
    
    return 0
}

# Check if file is writable
is_writable() {
    local file="$1"
    
    if [[ -f "$file" ]]; then
        [[ -w "$file" ]]
    else
        [[ -w "$(dirname "$file")" ]]
    fi
}

# Display progress indicator (simple, non-animated)
show_progress() {
    local message="$1"
    echo -ne "${COLOR_BLUE}  ›  ${message}...${COLOR_RESET}"
}

hide_progress() {
    echo -e "\r\033[K"
}

# Animated spinner for long-running operations.
# Usage:  start_spinner "Generating certificate"
#         <long command>
#         stop_spinner $?
_SPINNER_PID=""

start_spinner() {
    local msg="${1:-Working}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    tput civis 2>/dev/null
    (
        local i=0
        while true; do
            printf "\r  ${COLOR_CYAN}%s${COLOR_RESET}  %s  " "${frames[$((i % 10))]}" "$msg"
            sleep 0.08
            i=$(( i + 1 ))
        done
    ) &
    _SPINNER_PID=$!
}

stop_spinner() {
    local status="${1:-0}"
    if [[ -n "$_SPINNER_PID" ]]; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null
        _SPINNER_PID=""
        printf "\r\033[K"
    fi
    tput cnorm 2>/dev/null
    if [[ "$status" -eq 0 ]]; then
        echo -e "${COLOR_GREEN}  ✓  Done${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}  ✗  Failed${COLOR_RESET}"
    fi
}

# Format file size
format_size() {
    local size=$1
    
    if [[ $size -lt 1024 ]]; then
        echo "${size}B"
    elif [[ $size -lt 1048576 ]]; then
        echo "$((size / 1024))KB"
    else
        echo "$((size / 1048576))MB"
    fi
}

# Get file modification time
get_file_mtime() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null
}

# Check if file is older than N days
is_file_older_than() {
    local file="$1"
    local days="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local mtime=$(get_file_mtime "$file")
    local now=$(date +%s)
    local age=$(( (now - mtime) / 86400 ))
    
    [[ $age -gt $days ]]
}

# Cleanup old backups
cleanup_old_backups() {
    local dir="$1"
    local days="${2:-30}"
    
    if [[ ! -d "$dir" ]]; then
        return 0
    fi
    
    info "Cleaning up backups older than $days days..."
    
    find "$dir" -name "*.bak.*" -type f -mtime +$days -delete
    
    success "Cleanup completed"
}
