#!/bin/bash
# tests/quickstart.sh
# Quick setup and run tests

set -e

COLOR_GREEN='\033[0;32m'
COLOR_CYAN='\033[0;36m'
COLOR_YELLOW='\033[1;33m'
COLOR_RESET='\033[0m'

echo -e "${COLOR_CYAN}╔════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_CYAN}║     Local Dev Proxy - Test Quick Start                ║${COLOR_RESET}"
echo -e "${COLOR_CYAN}╚════════════════════════════════════════════════════════╝${COLOR_RESET}"
echo ""

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unknown";;
    esac
}

OS=$(detect_os)
echo -e "${COLOR_GREEN}✓${COLOR_RESET} Detected OS: $OS"

# Check prerequisites
echo ""
echo "Checking prerequisites..."

# Check Bash
if [[ -n "$BASH_VERSION" ]]; then
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} Bash: $BASH_VERSION"
else
    echo -e "${COLOR_YELLOW}✗${COLOR_RESET} Bash not detected"
fi

# Check Git
if command -v git &>/dev/null; then
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} Git: $(git --version | cut -d' ' -f3)"
else
    echo -e "${COLOR_YELLOW}✗${COLOR_RESET} Git not found (required for setup)"
    exit 1
fi

# Check OpenSSL (optional)
if command -v openssl &>/dev/null; then
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} OpenSSL: $(openssl version | cut -d' ' -f2)"
else
    echo -e "${COLOR_YELLOW}!${COLOR_RESET} OpenSSL not found (optional, some tests will be skipped)"
fi

# Check Docker (optional)
if command -v docker &>/dev/null && docker info &>/dev/null; then
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} Docker: Available"
else
    echo -e "${COLOR_YELLOW}!${COLOR_RESET} Docker not available (optional, Docker tests will be skipped)"
fi

# Setup BATS
echo ""
echo "Setting up BATS testing framework..."

if [[ ! -d "tests/bats" ]]; then
    echo "Installing BATS and dependencies..."
    git clone --quiet --depth 1 https://github.com/bats-core/bats-core.git tests/bats
    git clone --quiet --depth 1 https://github.com/bats-core/bats-support.git tests/bats-support
    git clone --quiet --depth 1 https://github.com/bats-core/bats-assert.git tests/bats-assert
    git clone --quiet --depth 1 https://github.com/bats-core/bats-file.git tests/bats-file
    chmod +x tests/bats/bin/bats
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} BATS installed successfully"
else
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} BATS already installed"
fi

# Create directories
mkdir -p tests/reports
mkdir -p tests/fixtures

echo -e "${COLOR_GREEN}✓${COLOR_RESET} Test environment ready"

# Ask what to run
echo ""
echo "What would you like to do?"
echo "  1) Run unit tests (fast, no dependencies)"
echo "  2) Run integration tests (with mocks)"
echo "  3) Run E2E tests (complete workflows)"
echo "  4) Run all tests"
echo "  5) Run tests with verbose output"
echo "  6) Exit"
echo ""

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo ""
        echo -e "${COLOR_CYAN}Running unit tests...${COLOR_RESET}"
        ./tests/bats/bin/bats tests/unit/*.bats
        ;;
    2)
        echo ""
        echo -e "${COLOR_CYAN}Running integration tests...${COLOR_RESET}"
        ./tests/bats/bin/bats tests/integration/*.bats
        ;;
    3)
        echo ""
        echo -e "${COLOR_CYAN}Running E2E tests...${COLOR_RESET}"
        ./tests/bats/bin/bats tests/e2e/*.bats
        ;;
    4)
        echo ""
        echo -e "${COLOR_CYAN}Running all tests...${COLOR_RESET}"
        ./tests/bats/bin/bats tests/unit/*.bats
        ./tests/bats/bin/bats tests/integration/*.bats
        ./tests/bats/bin/bats tests/e2e/*.bats
        ;;
    5)
        echo ""
        echo -e "${COLOR_CYAN}Running all tests (verbose)...${COLOR_RESET}"
        ./tests/bats/bin/bats -t tests/unit/*.bats
        ./tests/bats/bin/bats -t tests/integration/*.bats
        ./tests/bats/bin/bats -t tests/e2e/*.bats
        ;;
    6)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo -e "${COLOR_GREEN}╔════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_GREEN}║  ✓ Tests completed successfully!                      ║${COLOR_RESET}"
echo -e "${COLOR_GREEN}╚════════════════════════════════════════════════════════╝${COLOR_RESET}"
echo ""
echo "Next steps:"
echo "  - Run 'make test' to run all tests"
echo "  - Run 'make test-unit' for unit tests only"
echo "  - Run 'make help' to see all available commands"
echo "  - Check 'tests/README.md' for detailed documentation"
echo ""
