#!/usr/bin/env bash
#
# STUDIO Test Runner
# ==================
#
# Runs all or specific test suites for STUDIO infrastructure.
#
# Usage:
#   ./run-tests.sh              Run all tests
#   ./run-tests.sh orchestrator Run orchestrator tests only
#   ./run-tests.sh --quick      Run quick validation tests only
#   ./run-tests.sh --help       Show help
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[FAIL]${NC} $*"; }

# Check for bats
check_bats() {
    if ! command -v bats &> /dev/null; then
        log_error "bats-core is not installed"
        echo ""
        echo "Install with:"
        echo "  macOS:  brew install bats-core"
        echo "  Linux:  sudo apt install bats (or equivalent)"
        echo "  npm:    npm install -g bats"
        echo ""
        exit 1
    fi
}

# Show help
show_help() {
    cat << 'EOF'
STUDIO Test Runner
==================

Runs bats tests for STUDIO infrastructure.

Usage:
  ./run-tests.sh [options] [test_suite...]

Options:
  --quick       Run only validation tests (fast, no state changes)
  --verbose     Show verbose output
  --help        Show this help message

Test Suites:
  orchestrator     Tests for scripts/orchestrator.sh
  context-manager  Tests for scripts/context-manager.sh
  skills           Tests for scripts/skills.sh (requires yq)
  validation       Static validation tests
  integration      Full workflow integration tests
  all              Run all test suites (default)

Examples:
  ./run-tests.sh                    # Run all tests
  ./run-tests.sh orchestrator       # Run orchestrator tests only
  ./run-tests.sh --quick            # Run quick validation only
  ./run-tests.sh orchestrator integration  # Run multiple suites

EOF
}

# Run a single test file
run_test_file() {
    local test_file="$1"
    local name
    name=$(basename "$test_file" .bats)

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Running: ${name}${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if bats "$test_file"; then
        log_success "$name: All tests passed"
        return 0
    else
        log_error "$name: Some tests failed"
        return 1
    fi
}

# Main
main() {
    local quick=false
    local verbose=false
    local suites=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quick)
                quick=true
                shift
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                suites+=("$1")
                shift
                ;;
        esac
    done

    check_bats

    cd "$PROJECT_ROOT"

    echo ""
    echo -e "${BOLD}${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║           STUDIO Infrastructure Test Suite                 ║${NC}"
    echo -e "${BOLD}${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"

    local failed=0
    local passed=0

    # Determine which suites to run
    if [[ "$quick" == "true" ]]; then
        suites=("validation")
    elif [[ ${#suites[@]} -eq 0 ]]; then
        suites=("validation" "orchestrator" "context-manager" "skills" "integration")
    fi

    # Check for yq and warn if missing
    if ! command -v yq &> /dev/null; then
        log_warn "yq not installed - skills tests will be skipped"
    fi

    # Run each suite
    for suite in "${suites[@]}"; do
        local test_file="$SCRIPT_DIR/${suite}.bats"

        if [[ ! -f "$test_file" ]]; then
            log_warn "Test suite not found: $suite"
            continue
        fi

        if run_test_file "$test_file"; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    # Summary
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Test Summary${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Suites passed: ${GREEN}$passed${NC}"
    echo -e "  Suites failed: ${RED}$failed${NC}"
    echo ""

    if [[ $failed -gt 0 ]]; then
        log_error "Some test suites failed"
        exit 1
    else
        log_success "All test suites passed!"
        exit 0
    fi
}

main "$@"
