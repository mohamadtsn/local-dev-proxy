# Makefile for Local Dev Proxy Tests

.PHONY: help test test-unit test-integration test-e2e test-all setup clean install lint check

# Default target
.DEFAULT_GOAL := help

# Colors for output
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
RESET := \033[0m

# Paths
BATS := ./tests/bats/bin/bats
TEST_DIR := ./tests
UNIT_DIR := $(TEST_DIR)/unit
INTEGRATION_DIR := $(TEST_DIR)/integration
E2E_DIR := $(TEST_DIR)/e2e

##@ Help

help: ## Display this help message
	@echo "$(CYAN)Local Dev Proxy - Test Commands$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make $(GREEN)<target>$(RESET)\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(CYAN)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup

setup: ## Setup test environment (install BATS)
	@echo "$(CYAN)Setting up test environment...$(RESET)"
	@if [ ! -d "$(TEST_DIR)/bats" ]; then \
		echo "$(YELLOW)Installing BATS...$(RESET)"; \
		git clone --depth 1 https://github.com/bats-core/bats-core.git $(TEST_DIR)/bats; \
		git clone --depth 1 https://github.com/bats-core/bats-support.git $(TEST_DIR)/bats-support; \
		git clone --depth 1 https://github.com/bats-core/bats-assert.git $(TEST_DIR)/bats-assert; \
		git clone --depth 1 https://github.com/bats-core/bats-file.git $(TEST_DIR)/bats-file; \
		chmod +x $(BATS); \
		echo "$(GREEN)✓ BATS installed successfully$(RESET)"; \
	else \
		echo "$(GREEN)✓ BATS already installed$(RESET)"; \
	fi
	@mkdir -p $(TEST_DIR)/reports
	@mkdir -p $(TEST_DIR)/fixtures
	@echo "$(GREEN)✓ Test environment ready$(RESET)"

##@ Testing

test: setup test-unit test-integration test-e2e ## Run all tests
	@echo ""
	@echo "$(GREEN)✓ All tests completed$(RESET)"

test-unit: setup ## Run unit tests only
	@echo "$(CYAN)Running unit tests...$(RESET)"
	@$(BATS) $(UNIT_DIR)/*.bats || (echo "$(RED)✗ Unit tests failed$(RESET)" && exit 1)
	@echo "$(GREEN)✓ Unit tests passed$(RESET)"

test-integration: setup ## Run integration tests only
	@echo "$(CYAN)Running integration tests...$(RESET)"
	@$(BATS) $(INTEGRATION_DIR)/*.bats || (echo "$(RED)✗ Integration tests failed$(RESET)" && exit 1)
	@echo "$(GREEN)✓ Integration tests passed$(RESET)"

test-e2e: setup ## Run end-to-end tests only
	@echo "$(CYAN)Running E2E tests...$(RESET)"
	@$(BATS) $(E2E_DIR)/*.bats || (echo "$(RED)✗ E2E tests failed$(RESET)" && exit 1)
	@echo "$(GREEN)✓ E2E tests passed$(RESET)"

test-verbose: setup ## Run tests with verbose output
	@echo "$(CYAN)Running tests with verbose output...$(RESET)"
	@$(BATS) -t $(TEST_DIR)/unit/*.bats
	@$(BATS) -t $(TEST_DIR)/integration/*.bats
	@$(BATS) -t $(TEST_DIR)/e2e/*.bats

test-tap: setup ## Run tests with TAP output
	@echo "$(CYAN)Running tests with TAP output...$(RESET)"
	@$(BATS) -T $(TEST_DIR)/unit/*.bats
	@$(BATS) -T $(TEST_DIR)/integration/*.bats
	@$(BATS) -T $(TEST_DIR)/e2e/*.bats

test-file: setup ## Run specific test file (usage: make test-file FILE=tests/unit/test_common.bats)
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Error: FILE parameter required$(RESET)"; \
		echo "Usage: make test-file FILE=tests/unit/test_common.bats"; \
		exit 1; \
	fi
	@echo "$(CYAN)Running test file: $(FILE)$(RESET)"
	@$(BATS) $(FILE)

##@ Platform Specific

test-linux: setup ## Run tests suitable for Linux
	@echo "$(CYAN)Running Linux-specific tests...$(RESET)"
	@$(BATS) $(TEST_DIR)/unit/*.bats
	@$(BATS) $(TEST_DIR)/integration/*.bats
	@$(BATS) $(TEST_DIR)/e2e/*.bats

test-macos: setup ## Run tests suitable for macOS
	@echo "$(CYAN)Running macOS-specific tests...$(RESET)"
	@$(BATS) $(TEST_DIR)/unit/*.bats
	@$(BATS) $(TEST_DIR)/integration/*.bats
	@$(BATS) $(TEST_DIR)/e2e/*.bats

test-windows: setup ## Run tests suitable for Windows (Git Bash/WSL)
	@echo "$(CYAN)Running Windows-compatible tests...$(RESET)"
	@$(BATS) $(TEST_DIR)/unit/*.bats

##@ Code Quality

lint: ## Run shellcheck on all scripts
	@echo "$(CYAN)Running shellcheck...$(RESET)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		find lib -name "*.sh" -exec shellcheck -x {} +; \
		find scripts -name "*.sh" -exec shellcheck {} +; \
		shellcheck bin/devproxy; \
		echo "$(GREEN)✓ Shellcheck passed$(RESET)"; \
	else \
		echo "$(YELLOW)! Shellcheck not installed, skipping$(RESET)"; \
	fi

format: ## Check bash script formatting
	@echo "$(CYAN)Checking script formatting...$(RESET)"
	@if command -v shfmt >/dev/null 2>&1; then \
		find lib -name "*.sh" -exec shfmt -l -w {} +; \
		find scripts -name "*.sh" -exec shfmt -l -w {} +; \
		echo "$(GREEN)✓ Format check passed$(RESET)"; \
	else \
		echo "$(YELLOW)! shfmt not installed, skipping$(RESET)"; \
	fi

check: lint test ## Run all quality checks and tests
	@echo "$(GREEN)✓ All checks passed$(RESET)"

##@ Cleanup

clean: ## Clean test artifacts and temporary files
	@echo "$(CYAN)Cleaning test artifacts...$(RESET)"
	@rm -rf /tmp/local-dev-proxy-test.*
	@rm -rf $(TEST_DIR)/reports/*
	@echo "$(GREEN)✓ Cleaned$(RESET)"

clean-all: clean ## Clean everything including BATS installation
	@echo "$(CYAN)Cleaning everything...$(RESET)"
	@rm -rf $(TEST_DIR)/bats
	@rm -rf $(TEST_DIR)/bats-support
	@rm -rf $(TEST_DIR)/bats-assert
	@rm -rf $(TEST_DIR)/bats-file
	@rm -rf $(TEST_DIR)/reports
	@echo "$(GREEN)✓ All cleaned$(RESET)"

##@ Docker

test-docker: ## Run tests with Docker environment
	@echo "$(CYAN)Setting up Docker test environment...$(RESET)"
	@if docker ps >/dev/null 2>&1; then \
		docker run -d --name test-nginx-container -p 8080:80 nginx:latest 2>/dev/null || true; \
		echo "$(GREEN)✓ Docker container started$(RESET)"; \
		$(MAKE) test-integration; \
		docker stop test-nginx-container 2>/dev/null || true; \
		docker rm test-nginx-container 2>/dev/null || true; \
		echo "$(GREEN)✓ Docker container cleaned up$(RESET)"; \
	else \
		echo "$(RED)✗ Docker not available$(RESET)"; \
		exit 1; \
	fi

##@ Completions

install-completions: ## Install shell completions system-wide (requires sudo)
	@echo "$(CYAN)Installing shell completions...$(RESET)"
	@if [ -d "/etc/bash_completion.d" ]; then \
		cp completion/devproxy.bash /etc/bash_completion.d/devproxy; \
		chmod 644 /etc/bash_completion.d/devproxy; \
		echo "$(GREEN)✓ Bash → /etc/bash_completion.d/devproxy$(RESET)"; \
	fi
	@for d in /usr/local/share/zsh/site-functions /usr/share/zsh/vendor-completions /usr/share/zsh/site-functions; do \
		if [ -d "$$d" ]; then \
			cp completion/_devproxy "$$d/_devproxy"; \
			chmod 644 "$$d/_devproxy"; \
			echo "$(GREEN)✓ Zsh  → $$d/_devproxy$(RESET)"; \
			break; \
		fi; \
	done
	@echo "$(YELLOW)ℹ Fish → devproxy completion fish > ~/.config/fish/completions/devproxy.fish$(RESET)"

uninstall-completions: ## Remove installed shell completions (requires sudo)
	@echo "$(CYAN)Removing shell completions...$(RESET)"
	@rm -f /etc/bash_completion.d/devproxy && echo "$(GREEN)✓ Removed bash completion$(RESET)" || true
	@for d in /usr/local/share/zsh/site-functions /usr/share/zsh/vendor-completions /usr/share/zsh/site-functions; do \
		rm -f "$$d/_devproxy" 2>/dev/null && echo "$(GREEN)✓ Removed zsh completion ($$d/_devproxy)$(RESET)" || true; \
	done
	@echo "$(YELLOW)ℹ Fish: rm ~/.config/fish/completions/devproxy.fish$(RESET)"

##@ Release

release: ## Bump patch version, commit, tag, and push (triggers GitHub Actions release)
	@./scripts/release.sh patch

release-minor: ## Bump minor version and release
	@./scripts/release.sh minor

release-major: ## Bump major version and release
	@./scripts/release.sh major

release-dry: ## Preview what the next patch release would do (no changes)
	@./scripts/release.sh patch --dry-run

##@ CI/CD

ci: setup lint test ## Run CI pipeline locally
	@echo "$(GREEN)✓ CI pipeline completed$(RESET)"

ci-unit: setup test-unit ## Run CI unit tests only
	@echo "$(GREEN)✓ CI unit tests completed$(RESET)"

ci-integration: setup test-integration ## Run CI integration tests only
	@echo "$(GREEN)✓ CI integration tests completed$(RESET)"

ci-e2e: setup test-e2e ## Run CI E2E tests only
	@echo "$(GREEN)✓ CI E2E tests completed$(RESET)"

##@ Coverage

coverage: setup ## Generate test coverage report (requires kcov)
	@echo "$(CYAN)Generating coverage report...$(RESET)"
	@if command -v kcov >/dev/null 2>&1; then \
		mkdir -p $(TEST_DIR)/coverage; \
		kcov --include-path=lib $(TEST_DIR)/coverage $(BATS) $(TEST_DIR)/unit/*.bats; \
		kcov --include-path=lib $(TEST_DIR)/coverage $(BATS) $(TEST_DIR)/integration/*.bats; \
		echo "$(GREEN)✓ Coverage report generated in $(TEST_DIR)/coverage$(RESET)"; \
	else \
		echo "$(YELLOW)! kcov not installed$(RESET)"; \
		echo "Install: apt-get install kcov (Linux) or brew install kcov (macOS)"; \
	fi

##@ Development

watch: setup ## Watch and run tests on file changes (requires entr)
	@if command -v entr >/dev/null 2>&1; then \
		echo "$(CYAN)Watching for changes...$(RESET)"; \
		find lib tests -name "*.sh" -o -name "*.bats" | entr -c make test; \
	else \
		echo "$(RED)✗ entr not installed$(RESET)"; \
		echo "Install: apt-get install entr (Linux) or brew install entr (macOS)"; \
	fi

debug: setup ## Run tests in debug mode
	@echo "$(CYAN)Running tests in debug mode...$(RESET)"
	@$(BATS) -x $(TEST_DIR)/unit/*.bats

##@ Information

info: ## Display test environment information
	@echo "$(CYAN)Test Environment Information$(RESET)"
	@echo ""
	@echo "OS: $$(uname -s)"
	@echo "Shell: $$SHELL"
	@echo "Bash Version: $$BASH_VERSION"
	@echo ""
	@echo "BATS: $$([ -x $(BATS) ] && echo '✓ Installed' || echo '✗ Not installed')"
	@echo "Docker: $$(command -v docker >/dev/null 2>&1 && echo '✓ Available' || echo '✗ Not available')"
	@echo "OpenSSL: $$(command -v openssl >/dev/null 2>&1 && echo '✓ Available' || echo '✗ Not available')"
	@echo "ShellCheck: $$(command -v shellcheck >/dev/null 2>&1 && echo '✓ Available' || echo '✗ Not available')"
	@echo ""
	@echo "Test Directories:"
	@echo "  Unit: $(UNIT_DIR)"
	@echo "  Integration: $(INTEGRATION_DIR)"
	@echo "  E2E: $(E2E_DIR)"
	@echo ""
	@echo "Test Files:"
	@echo "  Unit: $$(ls -1 $(UNIT_DIR)/*.bats 2>/dev/null | wc -l)"
	@echo "  Integration: $$(ls -1 $(INTEGRATION_DIR)/*.bats 2>/dev/null | wc -l)"
	@echo "  E2E: $$(ls -1 $(E2E_DIR)/*.bats 2>/dev/null | wc -l)"

list: ## List all available tests
	@echo "$(CYAN)Available Tests$(RESET)"
	@echo ""
	@echo "$(YELLOW)Unit Tests:$(RESET)"
	@find $(UNIT_DIR) -name "*.bats" -exec basename {} \; 2>/dev/null | sed 's/^/  - /'
	@echo ""
	@echo "$(YELLOW)Integration Tests:$(RESET)"
	@find $(INTEGRATION_DIR) -name "*.bats" -exec basename {} \; 2>/dev/null | sed 's/^/  - /'
	@echo ""
	@echo "$(YELLOW)E2E Tests:$(RESET)"
	@find $(E2E_DIR) -name "*.bats" -exec basename {} \; 2>/dev/null | sed 's/^/  - /'
