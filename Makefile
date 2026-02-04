# STUDIO Makefile
# ================
#
# Common tasks for development and testing

.PHONY: test test-quick test-validation test-orchestrator test-skills test-integration
.PHONY: install-deps check-deps lint validate validate-docs generate-docs ci help

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
	@echo "  make validate-docs     Check docs reference real files"
	@echo ""
	@echo "Documentation:"
	@echo "  make generate-docs     Generate file listings for docs"
	@echo ""
	@echo "CI:"
	@echo "  make ci                Run full CI pipeline locally"
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

# Validate documentation references real files
validate-docs:
	@echo "Checking documentation accuracy..."
	@ERRORS=0; \
	echo "  Checking script references..."; \
	for script in $$(grep -roh 'scripts/[a-z_-]*.sh' docs/*.md AGENTS.md 2>/dev/null | sort -u); do \
		if [ ! -f "$$script" ]; then \
			echo "    MISSING: $$script"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	done; \
	echo "  Checking schema references..."; \
	for schema in $$(grep -roh 'schemas/[a-z_-]*.schema.json' docs/*.md AGENTS.md 2>/dev/null | sort -u); do \
		if [ ! -f "$$schema" ]; then \
			echo "    MISSING: $$schema"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	done; \
	echo "  Checking command references..."; \
	for cmd in $$(grep -roh 'commands/[a-z_-]*.md' docs/*.md AGENTS.md 2>/dev/null | sort -u); do \
		if [ ! -f "$$cmd" ]; then \
			echo "    MISSING: $$cmd"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	done; \
	if [ $$ERRORS -gt 0 ]; then \
		echo "Found $$ERRORS documentation errors"; \
		exit 1; \
	else \
		echo "All documentation references are valid"; \
	fi

# Generate file listings for documentation
generate-docs:
	@./scripts/generate-docs.sh

# Run full CI pipeline locally
ci: lint validate validate-docs test-quick
	@echo ""
	@echo "CI pipeline passed!"
