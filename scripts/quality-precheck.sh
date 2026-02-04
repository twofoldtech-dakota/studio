#!/usr/bin/env bash
# ============================================================================
# quality-precheck.sh - Quality Gate Pre-Check
# ============================================================================
# Runs lint and typecheck BEFORE build starts to catch issues early.
# Detects project type and runs appropriate quality commands.
#
# Usage:
#   ./scripts/quality-precheck.sh                    # Run all checks
#   ./scripts/quality-precheck.sh --lint-only        # Only lint
#   ./scripts/quality-precheck.sh --typecheck-only   # Only typecheck
#   ./scripts/quality-precheck.sh --skip-fix         # Don't auto-fix
#   ./scripts/quality-precheck.sh --json             # JSON output
#
# Exit codes:
#   0 - All checks passed
#   1 - Errors found (should block build)
#   2 - Warnings only (can proceed with confirmation)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-.studio}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Cross-platform millisecond timestamp
get_timestamp_ms() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        perl -MTime::HiRes=time -e 'printf "%d", time * 1000' 2>/dev/null || echo $(($(date +%s) * 1000))
    else
        echo $(($(date +%s%N) / 1000000))
    fi
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << 'EOF'
quality-precheck.sh - Quality Gate Pre-Check

USAGE:
    ./scripts/quality-precheck.sh                    # Run all checks
    ./scripts/quality-precheck.sh --lint-only        # Only lint
    ./scripts/quality-precheck.sh --typecheck-only   # Only typecheck
    ./scripts/quality-precheck.sh --skip-fix         # Don't auto-fix
    ./scripts/quality-precheck.sh --json             # JSON output only

OPTIONS:
    --lint-only       Only run linting checks
    --typecheck-only  Only run type checking
    --skip-fix        Don't attempt auto-fix for lint errors
    --json            Output results as JSON only
    --quiet           Suppress progress output
    --help            Show this help message

EXIT CODES:
    0 - All checks passed
    1 - Errors found (should block build)
    2 - Warnings only (can proceed)

SUPPORTED PROJECTS:
    - Node.js/TypeScript (eslint, tsc)
    - Python (ruff, mypy, pyright)
    - Go (go vet, staticcheck)
    - Rust (cargo clippy, cargo check)

EXAMPLES:
    # Run full pre-check before build
    ./scripts/quality-precheck.sh

    # Quick lint check only
    ./scripts/quality-precheck.sh --lint-only

    # Get JSON report for automation
    ./scripts/quality-precheck.sh --json
EOF
}

# ============================================================================
# PROJECT DETECTION
# ============================================================================

detect_project_type() {
    local types=()
    
    # Node.js / TypeScript
    if [[ -f "package.json" ]]; then
        types+=("node")
        if [[ -f "tsconfig.json" ]]; then
            types+=("typescript")
        fi
    fi
    
    # Python
    if [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
        types+=("python")
    fi
    
    # Go
    if [[ -f "go.mod" ]]; then
        types+=("go")
    fi
    
    # Rust
    if [[ -f "Cargo.toml" ]]; then
        types+=("rust")
    fi
    
    echo "${types[@]:-unknown}"
}

# ============================================================================
# LINT CHECKS
# ============================================================================

run_node_lint() {
    local auto_fix="$1"
    local start_time end_time duration
    local output exit_code
    local lint_cmd=""
    
    # Detect lint command
    if [[ -f "package.json" ]]; then
        # Check for lint script in package.json
        if jq -e '.scripts.lint' package.json > /dev/null 2>&1; then
            if [[ "$auto_fix" == "true" ]]; then
                lint_cmd="npm run lint -- --fix 2>&1 || npm run lint 2>&1"
            else
                lint_cmd="npm run lint 2>&1"
            fi
        elif command -v eslint &> /dev/null; then
            if [[ "$auto_fix" == "true" ]]; then
                lint_cmd="npx eslint . --fix 2>&1 || npx eslint . 2>&1"
            else
                lint_cmd="npx eslint . 2>&1"
            fi
        fi
    fi
    
    if [[ -z "$lint_cmd" ]]; then
        echo '{"tool":"eslint","status":"skipped","reason":"No lint command found"}'
        return 0
    fi
    
    start_time=$(get_timestamp_ms)
    set +e
    output=$(eval "$lint_cmd")
    exit_code=$?
    set -e
    end_time=$(get_timestamp_ms)
    duration=$((end_time - start_time))
    
    # Count errors and warnings
    local error_count warning_count
    error_count=$(echo "$output" | grep -c " error" || echo "0")
    warning_count=$(echo "$output" | grep -c " warning" || echo "0")
    
    local status="passed"
    if [[ $exit_code -ne 0 ]]; then
        if [[ "$error_count" -gt 0 ]]; then
            status="failed"
        else
            status="warnings"
        fi
    fi
    
    jq -n \
        --arg tool "eslint" \
        --arg status "$status" \
        --argjson exit_code "$exit_code" \
        --argjson duration "$duration" \
        --argjson errors "$error_count" \
        --argjson warnings "$warning_count" \
        --arg output "$(echo "$output" | tail -20)" \
        '{tool: $tool, status: $status, exit_code: $exit_code, duration_ms: $duration, errors: $errors, warnings: $warnings, output: $output}'
}

run_python_lint() {
    local auto_fix="$1"
    local start_time end_time duration
    local output exit_code
    
    # Try ruff first, then flake8
    if command -v ruff &> /dev/null; then
        local ruff_cmd="ruff check . 2>&1"
        if [[ "$auto_fix" == "true" ]]; then
            ruff_cmd="ruff check . --fix 2>&1"
        fi
        
        start_time=$(get_timestamp_ms)
        set +e
        output=$(eval "$ruff_cmd")
        exit_code=$?
        set -e
        end_time=$(get_timestamp_ms)
        duration=$((end_time - start_time))
        
        local error_count
        error_count=$(echo "$output" | grep -cE "^[^:]+:[0-9]+:" || echo "0")
        
        local status="passed"
        [[ $exit_code -ne 0 ]] && status="failed"
        
        jq -n \
            --arg tool "ruff" \
            --arg status "$status" \
            --argjson exit_code "$exit_code" \
            --argjson duration "$duration" \
            --argjson errors "$error_count" \
            --arg output "$(echo "$output" | tail -20)" \
            '{tool: $tool, status: $status, exit_code: $exit_code, duration_ms: $duration, errors: $errors, output: $output}'
    else
        echo '{"tool":"ruff","status":"skipped","reason":"ruff not installed"}'
    fi
}

run_go_lint() {
    local auto_fix="$1"
    local start_time end_time duration
    local output exit_code
    
    if ! command -v go &> /dev/null; then
        echo '{"tool":"go vet","status":"skipped","reason":"go not installed"}'
        return 0
    fi
    
    start_time=$(get_timestamp_ms)
    set +e
    output=$(go vet ./... 2>&1)
    exit_code=$?
    set -e
    end_time=$(get_timestamp_ms)
    duration=$((end_time - start_time))
    
    local status="passed"
    [[ $exit_code -ne 0 ]] && status="failed"
    
    jq -n \
        --arg tool "go vet" \
        --arg status "$status" \
        --argjson exit_code "$exit_code" \
        --argjson duration "$duration" \
        --arg output "$(echo "$output" | tail -20)" \
        '{tool: $tool, status: $status, exit_code: $exit_code, duration_ms: $duration, output: $output}'
}

run_rust_lint() {
    local auto_fix="$1"
    local start_time end_time duration
    local output exit_code
    
    if ! command -v cargo &> /dev/null; then
        echo '{"tool":"clippy","status":"skipped","reason":"cargo not installed"}'
        return 0
    fi
    
    local clippy_cmd="cargo clippy -- -D warnings 2>&1"
    if [[ "$auto_fix" == "true" ]]; then
        clippy_cmd="cargo clippy --fix --allow-dirty 2>&1 || cargo clippy -- -D warnings 2>&1"
    fi
    
    start_time=$(get_timestamp_ms)
    set +e
    output=$(eval "$clippy_cmd")
    exit_code=$?
    set -e
    end_time=$(get_timestamp_ms)
    duration=$((end_time - start_time))
    
    local status="passed"
    [[ $exit_code -ne 0 ]] && status="failed"
    
    jq -n \
        --arg tool "clippy" \
        --arg status "$status" \
        --argjson exit_code "$exit_code" \
        --argjson duration "$duration" \
        --arg output "$(echo "$output" | tail -30)" \
        '{tool: $tool, status: $status, exit_code: $exit_code, duration_ms: $duration, output: $output}'
}

# ============================================================================
# TYPE CHECKS
# ============================================================================

run_typescript_check() {
    local start_time end_time duration
    local output exit_code
    
    if [[ ! -f "tsconfig.json" ]]; then
        echo '{"tool":"tsc","status":"skipped","reason":"No tsconfig.json"}'
        return 0
    fi
    
    # Check for typecheck script or use tsc directly
    local tsc_cmd=""
    if jq -e '.scripts.typecheck' package.json > /dev/null 2>&1; then
        tsc_cmd="npm run typecheck 2>&1"
    elif jq -e '.scripts["type-check"]' package.json > /dev/null 2>&1; then
        tsc_cmd="npm run type-check 2>&1"
    else
        tsc_cmd="npx tsc --noEmit 2>&1"
    fi
    
    start_time=$(get_timestamp_ms)
    set +e
    output=$(eval "$tsc_cmd")
    exit_code=$?
    set -e
    end_time=$(get_timestamp_ms)
    duration=$((end_time - start_time))
    
    local error_count
    error_count=$(echo "$output" | grep -c "error TS" || echo "0")
    
    local status="passed"
    [[ $exit_code -ne 0 ]] && status="failed"
    
    jq -n \
        --arg tool "tsc" \
        --arg status "$status" \
        --argjson exit_code "$exit_code" \
        --argjson duration "$duration" \
        --argjson errors "$error_count" \
        --arg output "$(echo "$output" | tail -30)" \
        '{tool: $tool, status: $status, exit_code: $exit_code, duration_ms: $duration, errors: $errors, output: $output}'
}

run_python_typecheck() {
    local start_time end_time duration
    local output exit_code
    
    # Try pyright first, then mypy
    if command -v pyright &> /dev/null; then
        start_time=$(get_timestamp_ms)
        set +e
        output=$(pyright 2>&1)
        exit_code=$?
        set -e
        end_time=$(get_timestamp_ms)
        duration=$((end_time - start_time))
        
        local error_count
        error_count=$(echo "$output" | grep -c " error:" || echo "0")
        
        local status="passed"
        [[ $exit_code -ne 0 ]] && status="failed"
        
        jq -n \
            --arg tool "pyright" \
            --arg status "$status" \
            --argjson exit_code "$exit_code" \
            --argjson duration "$duration" \
            --argjson errors "$error_count" \
            --arg output "$(echo "$output" | tail -20)" \
            '{tool: $tool, status: $status, exit_code: $exit_code, duration_ms: $duration, errors: $errors, output: $output}'
    elif command -v mypy &> /dev/null; then
        start_time=$(get_timestamp_ms)
        set +e
        output=$(mypy . 2>&1)
        exit_code=$?
        set -e
        end_time=$(get_timestamp_ms)
        duration=$((end_time - start_time))
        
        local status="passed"
        [[ $exit_code -ne 0 ]] && status="failed"
        
        jq -n \
            --arg tool "mypy" \
            --arg status "$status" \
            --argjson exit_code "$exit_code" \
            --argjson duration "$duration" \
            --arg output "$(echo "$output" | tail -20)" \
            '{tool: $tool, status: $status, exit_code: $exit_code, duration_ms: $duration, output: $output}'
    else
        echo '{"tool":"pyright/mypy","status":"skipped","reason":"No type checker installed"}'
    fi
}

run_rust_check() {
    local start_time end_time duration
    local output exit_code
    
    if ! command -v cargo &> /dev/null; then
        echo '{"tool":"cargo check","status":"skipped","reason":"cargo not installed"}'
        return 0
    fi
    
    start_time=$(get_timestamp_ms)
    set +e
    output=$(cargo check 2>&1)
    exit_code=$?
    set -e
    end_time=$(get_timestamp_ms)
    duration=$((end_time - start_time))
    
    local error_count
    error_count=$(echo "$output" | grep -c "^error" || echo "0")
    
    local status="passed"
    [[ $exit_code -ne 0 ]] && status="failed"
    
    jq -n \
        --arg tool "cargo check" \
        --arg status "$status" \
        --argjson exit_code "$exit_code" \
        --argjson duration "$duration" \
        --argjson errors "$error_count" \
        --arg output "$(echo "$output" | tail -30)" \
        '{tool: $tool, status: $status, exit_code: $exit_code, duration_ms: $duration, errors: $errors, output: $output}'
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local lint_only="false"
    local typecheck_only="false"
    local auto_fix="true"
    local json_only="false"
    local quiet="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lint-only) lint_only="true"; shift ;;
            --typecheck-only) typecheck_only="true"; shift ;;
            --skip-fix) auto_fix="false"; shift ;;
            --json) json_only="true"; shift ;;
            --quiet) quiet="true"; shift ;;
            --help|-h) show_help; exit 0 ;;
            *) echo "Unknown option: $1" >&2; show_help; exit 1 ;;
        esac
    done
    
    local project_types
    project_types=$(detect_project_type)
    
    [[ "$quiet" != "true" && "$json_only" != "true" ]] && echo -e "${BLUE}Detected project types:${NC} $project_types"
    
    local results=()
    local has_errors="false"
    local has_warnings="false"
    
    # Run lint checks
    if [[ "$typecheck_only" != "true" ]]; then
        [[ "$quiet" != "true" && "$json_only" != "true" ]] && echo -e "\n${CYAN}Running lint checks...${NC}"
        
        for ptype in $project_types; do
            case "$ptype" in
                node|typescript)
                    local result
                    result=$(run_node_lint "$auto_fix")
                    results+=("$result")
                    [[ $(echo "$result" | jq -r '.status') == "failed" ]] && has_errors="true"
                    [[ $(echo "$result" | jq -r '.status') == "warnings" ]] && has_warnings="true"
                    ;;
                python)
                    result=$(run_python_lint "$auto_fix")
                    results+=("$result")
                    [[ $(echo "$result" | jq -r '.status') == "failed" ]] && has_errors="true"
                    ;;
                go)
                    result=$(run_go_lint "$auto_fix")
                    results+=("$result")
                    [[ $(echo "$result" | jq -r '.status') == "failed" ]] && has_errors="true"
                    ;;
                rust)
                    result=$(run_rust_lint "$auto_fix")
                    results+=("$result")
                    [[ $(echo "$result" | jq -r '.status') == "failed" ]] && has_errors="true"
                    ;;
            esac
        done
    fi
    
    # Run type checks
    if [[ "$lint_only" != "true" ]]; then
        [[ "$quiet" != "true" && "$json_only" != "true" ]] && echo -e "\n${CYAN}Running type checks...${NC}"
        
        for ptype in $project_types; do
            case "$ptype" in
                typescript)
                    local result
                    result=$(run_typescript_check)
                    results+=("$result")
                    [[ $(echo "$result" | jq -r '.status') == "failed" ]] && has_errors="true"
                    ;;
                python)
                    result=$(run_python_typecheck)
                    results+=("$result")
                    [[ $(echo "$result" | jq -r '.status') == "failed" ]] && has_errors="true"
                    ;;
                rust)
                    result=$(run_rust_check)
                    results+=("$result")
                    [[ $(echo "$result" | jq -r '.status') == "failed" ]] && has_errors="true"
                    ;;
            esac
        done
    fi
    
    # Build results JSON
    local results_json="[]"
    for r in "${results[@]:-}"; do
        [[ -z "$r" ]] && continue
        results_json=$(echo "$results_json" | jq --argjson r "$r" '. + [$r]')
    done
    
    local overall_status="passed"
    local exit_code=0
    if [[ "$has_errors" == "true" ]]; then
        overall_status="failed"
        exit_code=1
    elif [[ "$has_warnings" == "true" ]]; then
        overall_status="warnings"
        exit_code=2
    fi
    
    local final_result
    final_result=$(jq -n \
        --arg status "$overall_status" \
        --arg project_types "$project_types" \
        --argjson checks "$results_json" \
        '{
            status: $status,
            project_types: ($project_types | split(" ")),
            checks: $checks,
            summary: {
                total: ($checks | length),
                passed: ([$checks[] | select(.status == "passed")] | length),
                failed: ([$checks[] | select(.status == "failed")] | length),
                skipped: ([$checks[] | select(.status == "skipped")] | length)
            }
        }')
    
    if [[ "$json_only" == "true" ]]; then
        echo "$final_result"
    else
        # Display results
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        for r in "${results[@]:-}"; do
            [[ -z "$r" ]] && continue
            local tool status
            tool=$(echo "$r" | jq -r '.tool')
            status=$(echo "$r" | jq -r '.status')
            
            case "$status" in
                passed) echo -e "${GREEN}✓${NC} $tool: PASSED" ;;
                failed) echo -e "${RED}✗${NC} $tool: FAILED" ;;
                warnings) echo -e "${YELLOW}⚠${NC} $tool: WARNINGS" ;;
                skipped) echo -e "${BLUE}○${NC} $tool: SKIPPED" ;;
            esac
        done
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        case "$overall_status" in
            passed) echo -e "${GREEN}Pre-check PASSED${NC} - ready to build" ;;
            warnings) echo -e "${YELLOW}Pre-check has WARNINGS${NC} - review before proceeding" ;;
            failed) echo -e "${RED}Pre-check FAILED${NC} - fix errors before building" ;;
        esac
        
        echo ""
        echo "$final_result"
    fi
    
    exit $exit_code
}

main "$@"
