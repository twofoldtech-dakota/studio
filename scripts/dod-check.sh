#!/usr/bin/env bash
# ============================================================================
# dod-check.sh - Definition of Done Checker
# ============================================================================
# Executes DoD criteria from templates to verify build completion.
# Supports multiple templates: universal, frontend, backend, api-endpoint
#
# Usage:
#   ./scripts/dod-check.sh --template universal
#   ./scripts/dod-check.sh --template frontend --task-id <id>
#   ./scripts/dod-check.sh --auto-detect
#
# Exit codes:
#   0 - All blocking criteria pass
#   1 - One or more blocking criteria failed
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-.studio}"
TEMPLATES_DIR="${SCRIPT_DIR}/../data/dod-templates"

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
dod-check.sh - Definition of Done Checker

USAGE:
    ./scripts/dod-check.sh --template universal
    ./scripts/dod-check.sh --template frontend --task-id <id>
    ./scripts/dod-check.sh --auto-detect

OPTIONS:
    --template <name>    Template to use: universal, frontend, backend, api-endpoint
    --auto-detect        Auto-detect template based on changed files
    --task-id <id>       Task ID for context (optional)
    --blocking-only      Only run blocking criteria
    --json               Output JSON only
    --skip <id>          Skip specific criterion (can repeat)
    --help               Show this help

TEMPLATES:
    universal      Base criteria for all tasks (lint, typecheck, tests, security)
    frontend       Extends universal + accessibility, performance, responsive
    backend        Extends universal + API docs, error handling, logging
    api-endpoint   Extends universal + contract tests, rate limiting, versioning

EXAMPLES:
    # Run universal DoD checks
    ./scripts/dod-check.sh --template universal

    # Auto-detect and run appropriate template
    ./scripts/dod-check.sh --auto-detect

    # Skip specific checks
    ./scripts/dod-check.sh --template universal --skip DoD-U-5 --skip DoD-U-6
EOF
}

# ============================================================================
# TEMPLATE LOADING
# ============================================================================

load_template() {
    local template_name="$1"
    local template_file="${TEMPLATES_DIR}/${template_name}.json"
    
    if [[ ! -f "$template_file" ]]; then
        echo "Error: Template not found: $template_name" >&2
        echo "Available templates: universal, frontend, backend, api-endpoint" >&2
        exit 1
    fi
    
    cat "$template_file"
}

# Auto-detect template based on changed files
auto_detect_template() {
    local changed_files
    changed_files=$(git diff --name-only HEAD~1 2>/dev/null || find . -name "*.ts" -o -name "*.tsx" -o -name "*.py" | head -20)
    
    # Count file types
    local tsx_count ts_count py_count go_count
    tsx_count=$(echo "$changed_files" | grep -c '\.tsx$' || echo "0")
    ts_count=$(echo "$changed_files" | grep -c '\.ts$' || echo "0")
    py_count=$(echo "$changed_files" | grep -c '\.py$' || echo "0")
    go_count=$(echo "$changed_files" | grep -c '\.go$' || echo "0")
    
    # Check for API routes
    local api_count
    api_count=$(echo "$changed_files" | grep -cE '(api/|routes/|endpoints/)' || echo "0")
    
    # Decide template
    if [[ "$api_count" -gt 0 ]]; then
        echo "api-endpoint"
    elif [[ "$tsx_count" -gt 0 ]] || echo "$changed_files" | grep -qE '(components/|pages/)'; then
        echo "frontend"
    elif [[ "$py_count" -gt 0 ]] || [[ "$go_count" -gt 0 ]] || echo "$changed_files" | grep -qE '(services/|handlers/)'; then
        echo "backend"
    else
        echo "universal"
    fi
}

# ============================================================================
# CRITERION VERIFICATION
# ============================================================================

verify_command() {
    local command="$1"
    local expected_exit="${2:-0}"
    local timeout_ms="${3:-60000}"
    
    local timeout_sec=$((timeout_ms / 1000))
    local start_time end_time duration
    local output exit_code
    
    start_time=$(get_timestamp_ms)
    
    set +e
    if command -v timeout &> /dev/null; then
        output=$(timeout "$timeout_sec" bash -c "$command" 2>&1)
        exit_code=$?
    else
        # macOS fallback
        output=$(bash -c "$command" 2>&1)
        exit_code=$?
    fi
    set -e
    
    end_time=$(get_timestamp_ms)
    duration=$((end_time - start_time))
    
    local status="passed"
    if [[ "$exit_code" -ne "$expected_exit" ]]; then
        status="failed"
    fi
    
    jq -n \
        --arg status "$status" \
        --argjson exit_code "$exit_code" \
        --argjson expected "$expected_exit" \
        --argjson duration "$duration" \
        --arg output "$(echo "$output" | tail -30)" \
        '{status: $status, exit_code: $exit_code, expected: $expected, duration_ms: $duration, output: $output}'
}

verify_pattern() {
    local pattern="$1"
    local file_glob="$2"
    local must_exist="${3:-true}"
    
    local matches
    matches=$(grep -rlE "$pattern" $file_glob 2>/dev/null | wc -l | tr -d ' ')
    
    local status="passed"
    if [[ "$must_exist" == "true" && "$matches" -eq 0 ]]; then
        status="failed"
    elif [[ "$must_exist" == "false" && "$matches" -gt 0 ]]; then
        status="failed"
    fi
    
    jq -n --arg status "$status" --argjson matches "$matches" '{status: $status, matches: $matches}'
}

verify_file() {
    local path="$1"
    local must_exist="${2:-true}"
    
    local exists="false"
    [[ -e "$path" ]] && exists="true"
    
    local status="passed"
    if [[ "$must_exist" == "true" && "$exists" == "false" ]]; then
        status="failed"
    elif [[ "$must_exist" == "false" && "$exists" == "true" ]]; then
        status="failed"
    fi
    
    jq -n --arg status "$status" --arg exists "$exists" '{status: $status, exists: $exists}'
}

verify_manual() {
    # Manual checks are skipped in automated runs
    jq -n '{status: "skipped", reason: "Manual verification required"}'
}

# Run a single criterion
run_criterion() {
    local criterion_json="$1"
    
    local id criterion blocking verification_type
    id=$(echo "$criterion_json" | jq -r '.id')
    criterion=$(echo "$criterion_json" | jq -r '.criterion')
    blocking=$(echo "$criterion_json" | jq -r '.blocking')
    verification_type=$(echo "$criterion_json" | jq -r '.verification.type // "manual"')
    
    local result
    case "$verification_type" in
        command)
            local cmd expected timeout
            cmd=$(echo "$criterion_json" | jq -r '.verification.command')
            expected=$(echo "$criterion_json" | jq -r '.verification.expected_exit_code // 0')
            timeout=$(echo "$criterion_json" | jq -r '.verification.timeout_ms // 60000')
            result=$(verify_command "$cmd" "$expected" "$timeout")
            ;;
        pattern)
            local pattern glob must_exist
            pattern=$(echo "$criterion_json" | jq -r '.verification.pattern')
            glob=$(echo "$criterion_json" | jq -r '.verification.file_glob // "src/**/*"')
            must_exist=$(echo "$criterion_json" | jq -r '.verification.must_exist // true')
            result=$(verify_pattern "$pattern" "$glob" "$must_exist")
            ;;
        file)
            local path must_exist
            path=$(echo "$criterion_json" | jq -r '.verification.path')
            must_exist=$(echo "$criterion_json" | jq -r '.verification.must_exist // true')
            result=$(verify_file "$path" "$must_exist")
            ;;
        manual)
            result=$(verify_manual)
            ;;
        *)
            result='{"status": "skipped", "reason": "Unknown verification type"}'
            ;;
    esac
    
    # Add criterion metadata
    echo "$result" | jq \
        --arg id "$id" \
        --arg criterion "$criterion" \
        --argjson blocking "$blocking" \
        --arg type "$verification_type" \
        '. + {id: $id, criterion: $criterion, blocking: $blocking, type: $type}'
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local template_name=""
    local task_id=""
    local auto_detect="false"
    local blocking_only="false"
    local json_only="false"
    local skip_ids=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --template) template_name="$2"; shift 2 ;;
            --task-id) task_id="$2"; shift 2 ;;
            --auto-detect) auto_detect="true"; shift ;;
            --blocking-only) blocking_only="true"; shift ;;
            --json) json_only="true"; shift ;;
            --skip) skip_ids+=("$2"); shift 2 ;;
            --help|-h) show_help; exit 0 ;;
            *) echo "Unknown option: $1" >&2; show_help; exit 1 ;;
        esac
    done
    
    # Auto-detect template if needed
    if [[ "$auto_detect" == "true" ]]; then
        template_name=$(auto_detect_template)
        [[ "$json_only" != "true" ]] && echo -e "${BLUE}Auto-detected template:${NC} $template_name"
    fi
    
    if [[ -z "$template_name" ]]; then
        echo "Error: Must specify --template or --auto-detect" >&2
        show_help
        exit 1
    fi
    
    # Load template
    local template
    template=$(load_template "$template_name")
    
    # Get criteria (include parent if extends)
    local extends
    extends=$(echo "$template" | jq -r '.extends // empty')
    local all_criteria
    
    if [[ -n "$extends" ]]; then
        local parent_template
        parent_template=$(load_template "$extends")
        all_criteria=$(echo "$parent_template" | jq '.criteria')
        # Merge child criteria
        all_criteria=$(echo "$all_criteria" | jq --argjson child "$(echo "$template" | jq '.criteria')" '. + $child')
    else
        all_criteria=$(echo "$template" | jq '.criteria')
    fi
    
    local criteria_count
    criteria_count=$(echo "$all_criteria" | jq 'length')
    
    [[ "$json_only" != "true" ]] && echo -e "${BLUE}Running $criteria_count DoD checks (${template_name})...${NC}"
    
    local results=()
    local passed=0 failed=0 skipped=0
    local blocking_failed=0
    
    for ((i=0; i<criteria_count; i++)); do
        local criterion
        criterion=$(echo "$all_criteria" | jq ".[$i]")
        
        local id blocking
        id=$(echo "$criterion" | jq -r '.id')
        blocking=$(echo "$criterion" | jq -r '.blocking')
        
        # Check if skipped
        local is_skipped="false"
        for skip_id in "${skip_ids[@]:-}"; do
            [[ "$id" == "$skip_id" ]] && is_skipped="true"
        done
        
        # Skip non-blocking if blocking_only
        if [[ "$blocking_only" == "true" && "$blocking" == "false" ]]; then
            is_skipped="true"
        fi
        
        if [[ "$is_skipped" == "true" ]]; then
            local skip_result
            skip_result=$(jq -n --arg id "$id" '{id: $id, status: "skipped", reason: "Explicitly skipped"}')
            results+=("$skip_result")
            ((skipped++))
            [[ "$json_only" != "true" ]] && echo -e "  ${BLUE}○${NC} $id: SKIPPED"
            continue
        fi
        
        [[ "$json_only" != "true" ]] && echo -ne "  Running $id..."
        
        local result
        result=$(run_criterion "$criterion")
        results+=("$result")
        
        local status
        status=$(echo "$result" | jq -r '.status')
        
        case "$status" in
            passed)
                ((passed++))
                [[ "$json_only" != "true" ]] && echo -e "\r  ${GREEN}✓${NC} $id: PASSED"
                ;;
            failed)
                ((failed++))
                [[ "$blocking" == "true" ]] && ((blocking_failed++))
                [[ "$json_only" != "true" ]] && echo -e "\r  ${RED}✗${NC} $id: FAILED"
                # Show fix hints
                if [[ "$json_only" != "true" ]]; then
                    local hints
                    hints=$(echo "$criterion" | jq -r '.fix_hints[]? // empty' 2>/dev/null)
                    if [[ -n "$hints" ]]; then
                        echo "    Fix hints:"
                        echo "$hints" | sed 's/^/      - /'
                    fi
                fi
                ;;
            skipped)
                ((skipped++))
                [[ "$json_only" != "true" ]] && echo -e "\r  ${YELLOW}○${NC} $id: SKIPPED"
                ;;
        esac
    done
    
    # Build results JSON
    local results_json="[]"
    for r in "${results[@]:-}"; do
        [[ -z "$r" ]] && continue
        results_json=$(echo "$results_json" | jq --argjson r "$r" '. + [$r]')
    done
    
    local overall_status="passed"
    [[ "$blocking_failed" -gt 0 ]] && overall_status="failed"
    
    local final_result
    final_result=$(jq -n \
        --arg template "$template_name" \
        --arg status "$overall_status" \
        --argjson total "$criteria_count" \
        --argjson passed "$passed" \
        --argjson failed "$failed" \
        --argjson skipped "$skipped" \
        --argjson blocking_failed "$blocking_failed" \
        --argjson results "$results_json" \
        '{
            template: $template,
            status: $status,
            summary: {
                total: $total,
                passed: $passed,
                failed: $failed,
                skipped: $skipped,
                blocking_failed: $blocking_failed
            },
            results: $results
        }')
    
    if [[ "$json_only" != "true" ]]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}Passed:${NC} $passed  ${RED}Failed:${NC} $failed  ${BLUE}Skipped:${NC} $skipped"
        
        if [[ "$blocking_failed" -gt 0 ]]; then
            echo -e "${RED}✗ DoD FAILED - $blocking_failed blocking criteria not met${NC}"
        else
            echo -e "${GREEN}✓ DoD PASSED${NC}"
        fi
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
    
    echo "$final_result"
    
    [[ "$blocking_failed" -eq 0 ]]
}

main "$@"
