# STUDIO Makefile
# ================
#
# Common tasks for development and testing

.PHONY: test test-quick test-validation test-orchestrator test-skills test-integration
.PHONY: install-deps check-deps lint validate help

# Default target
help:
	@echo "STUDIO Development Tasks"
	@echo "========================"
	@echo ""
	@echo "Testing:"
	@echo "  make test              Run all tests"
	@echo "  make test-quick        Run quick validation tests only"
	@echo "  make test-orchestrator Run orchestrator tests"
	@echo "  make test-skills       Run skills tests (requires yq)"
	@echo "  make test-integration  Run integration tests"
	@echo ""
	@echo "Setup:"
	@echo "  make install-deps      Install test dependencies (bats, yq)"
	@echo "  make check-deps        Check if dependencies are installed"
	@echo ""
	@echo "Validation:"
	@echo "  make lint              Check bash scripts for errors"
	@echo "  make validate          Validate JSON/YAML files"
	@echo ""

# Install test dependencies
install-deps:
	@echo "Installing test dependencies..."
	@if command -v brew >/dev/null 2>&1; then \
		brew install bats-core yq; \
	elif command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update && sudo apt-get install -y bats; \
		echo "Note: Install yq manually from https://github.com/mikefarah/yq"; \
	else \
		echo "Please install bats-core and yq manually:"; \
		echo "  bats: https://github.com/bats-core/bats-core"; \
		echo "  yq: https://github.com/mikefarah/yq"; \
	fi

# Check dependencies
check-deps:
	@echo "Checking dependencies..."
	@printf "  bats-core: " && (command -v bats >/dev/null 2>&1 && echo "installed" || echo "NOT INSTALLED")
	@printf "  yq: " && (command -v yq >/dev/null 2>&1 && echo "installed" || echo "NOT INSTALLED (optional)")
	@printf "  jq: " && (command -v jq >/dev/null 2>&1 && echo "installed" || echo "NOT INSTALLED")

# Run all tests
test:
	@./tests/run-tests.sh

# Run quick validation tests
test-quick:
	@./tests/run-tests.sh --quick

# Run specific test suites
test-validation:
	@./tests/run-tests.sh validation

test-orchestrator:
	@./tests/run-tests.sh orchestrator

test-context-manager:
	@./tests/run-tests.sh context-manager

test-skills:
	@./tests/run-tests.sh skills

test-integration:
	@./tests/run-tests.sh integration

# Lint bash scripts
lint:
	@echo "Checking bash syntax..."
	@for script in scripts/*.sh; do \
		echo "  Checking $$script"; \
		bash -n "$$script" || exit 1; \
	done
	@echo "All scripts have valid syntax"

# Validate configuration files
validate:
	@echo "Validating JSON files..."
	@for json in hooks/hooks.json schemas/*.json; do \
		echo "  Checking $$json"; \
		jq . "$$json" >/dev/null || exit 1; \
	done
	@echo "All JSON files are valid"
	@if command -v yq >/dev/null 2>&1; then \
		echo "Validating YAML files..."; \
		for yaml in skills/*.yaml agents/*.yaml; do \
			echo "  Checking $$yaml"; \
			yq . "$$yaml" >/dev/null || exit 1; \
		done; \
		echo "All YAML files are valid"; \
	fi
