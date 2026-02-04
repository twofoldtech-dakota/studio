#!/usr/bin/env bash
# ============================================================================
# verify-ac.sh - Acceptance Criteria Verification Runner
# ============================================================================
# Verifies acceptance criteria from plans and returns structured JSON report.
# Supports: command, file_exists, file_contains, test_passes, playwright
#
# Usage:
#   ./scripts/verify-ac.sh --plan-file <path>           # Verify all ACs in plan
#   ./scripts/verify-ac.sh --plan-file <path> --ac AC-1 # Verify specific AC
#   ./scripts/verify-ac.sh --json '<ac_json>'           # Verify single AC from JSON
#   ./scripts/verify-ac.sh --task-id <id>               # Verify task's plan ACs
#
# Output: JSON report with pass/fail status per criterion
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-.studio}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cross-platform millisecond timestamp
get_timestamp_ms() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: use perl for milliseconds
        perl -MTime::HiRes=time -e 'printf "%d", time * 1000' 2>/dev/null || echo $(($(date +%s) * 1000))
    else
        # Linux: date supports %N
        echo $(($(date +%s%N) / 1000000))
    fi
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << 'EOF'
verify-ac.sh - Acceptance Criteria Verification Runner

USAGE:
    ./scripts/verify-ac.sh --plan-file <path>           # Verify all ACs in plan
    ./scripts/verify-ac.sh --plan-file <path> --ac AC-1 # Verify specific AC
    ./scripts/verify-ac.sh --json '<ac_json>'           # Verify single AC from JSON
    ./scripts/verify-ac.sh --task-id <id>               # Verify task's plan ACs

OPTIONS:
    --plan-file <path>    Path to plan.json file
    --task-id <id>        Task ID (looks for .studio/tasks/<id>/plan.json)
    --ac <id>             Specific acceptance criteria ID to verify
    --json <json>         Single AC definition as JSON
    --quiet               Only output JSON, no progress messages
    --must-only           Only verify 'must' priority criteria
    --help                Show this help message

VERIFICATION TYPES:
    command       - Run shell command, check exit code 0
    file_exists   - Check if path exists
    file_contains - Check if file contains regex pattern
    test_passes   - Run test command, check exit code 0
    playwright    - Browser automation (outputs MCP instructions)

OUTPUT:
    JSON report with structure:
    {
        "summary": { "total": N, "passed": N, "failed": N, "skipped": N },
        "results": [
            {
                "id": "AC-1",
                "criterion": "...",
                "priority": "must",
                "status": "passed|failed|skipped",
                "type": "command",
                "duration_ms": 123,
                "output": "...",
                "error": "..."
            }
        ]
    }

EXAMPLES:
    # Verify all ACs in a plan
    ./scripts/verify-ac.sh --plan-file .studio/tasks/task_123/plan.json

    # Verify only must-have criteria
    ./scripts/verify-ac.sh --task-id task_123 --must-only

    # Verify single AC from JSON
    ./scripts/verify-ac.sh --json '{"id":"AC-1","criterion":"File exists","verification":{"type":"file_exists","path":"./README.md"},"priority":"must"}'
EOF
}

# ============================================================================
# VERIFICATION FUNCTIONS
# ============================================================================

# Verify command type
verify_command() {
    local command="$1"
    local start_time end_time duration
    local output exit_code
    
    start_time=$(get_timestamp_ms)
    
    # Run command and capture output
    set +e
    output=$(eval "$command" 2>&1)
    exit_code=$?
    set -e
    
    end_time=$(get_timestamp_ms)
    duration=$((end_time - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        echo "{\"status\":\"passed\",\"duration_ms\":$duration,\"output\":$(echo "$output" | jq -Rs .)}"
    else
        echo "{\"status\":\"failed\",\"duration_ms\":$duration,\"output\":$(echo "$output" | jq -Rs .),\"error\":\"Command exited with code $exit_code\"}"
    fi
}

# Verify file_exists type
verify_file_exists() {
    local path="$1"
    local start_time end_time duration
    
    start_time=$(get_timestamp_ms)
    
    if [[ -e "$path" ]]; then
        end_time=$(get_timestamp_ms)
        duration=$((end_time - start_time))
        echo "{\"status\":\"passed\",\"duration_ms\":$duration,\"output\":\"Path exists: $path\"}"
    else
        end_time=$(get_timestamp_ms)
        duration=$((end_time - start_time))
        echo "{\"status\":\"failed\",\"duration_ms\":$duration,\"error\":\"Path does not exist: $path\"}"
    fi
}

# Verify file_contains type
verify_file_contains() {
    local path="$1"
    local pattern="$2"
    local start_time end_time duration
    local output
    
    start_time=$(get_timestamp_ms)
    
    if [[ ! -f "$path" ]]; then
        end_time=$(get_timestamp_ms)
        duration=$((end_time - start_time))
        echo "{\"status\":\"failed\",\"duration_ms\":$duration,\"error\":\"File does not exist: $path\"}"
        return
    fi
    
    set +e
    output=$(grep -E "$pattern" "$path" 2>&1)
    local exit_code=$?
    set -e
    
    end_time=$(get_timestamp_ms)
    duration=$((end_time - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        # Truncate output if too long
        local truncated_output
        truncated_output=$(echo "$output" | head -5)
        echo "{\"status\":\"passed\",\"duration_ms\":$duration,\"output\":$(echo "$truncated_output" | jq -Rs .)}"
    else
        echo "{\"status\":\"failed\",\"duration_ms\":$duration,\"error\":\"Pattern not found in $path: $pattern\"}"
    fi
}

# Verify test_passes type
verify_test_passes() {
    local test_command="$1"
    local start_time end_time duration
    local output exit_code
    
    start_time=$(get_timestamp_ms)
    
    set +e
    output=$(eval "$test_command" 2>&1)
    exit_code=$?
    set -e
    
    end_time=$(get_timestamp_ms)
    duration=$((end_time - start_time))
    
    # Truncate output if too long (tests can be verbose)
    local truncated_output
    truncated_output=$(echo "$output" | tail -50)
    
    if [[ $exit_code -eq 0 ]]; then
        echo "{\"status\":\"passed\",\"duration_ms\":$duration,\"output\":$(echo "$truncated_output" | jq -Rs .)}"
    else
        echo "{\"status\":\"failed\",\"duration_ms\":$duration,\"output\":$(echo "$truncated_output" | jq -Rs .),\"error\":\"Test failed with exit code $exit_code\"}"
    fi
}

# Verify playwright type - outputs MCP instructions
verify_playwright() {
    local url="$1"
    local actions="$2"
    local assertions="$3"
    
    # Playwright requires MCP integration - output instructions for the agent
    local mcp_instructions=""
    
    mcp_instructions+="PLAYWRIGHT_MCP_VERIFICATION:\n"
    mcp_instructions+="1. Call browser_navigate with url: $url\n"
    
    # Parse actions
    if [[ -n "$actions" && "$actions" != "null" ]]; then
        local action_count
        action_count=$(echo "$actions" | jq 'length')
        for ((i=0; i<action_count; i++)); do
            local action selector value
            action=$(echo "$actions" | jq -r ".[$i].action")
            selector=$(echo "$actions" | jq -r ".[$i].selector // empty")
            value=$(echo "$actions" | jq -r ".[$i].value // empty")
            
            case "$action" in
                click)
                    mcp_instructions+="2.$i. Call browser_click with ref matching: $selector\n"
                    ;;
                fill)
                    mcp_instructions+="2.$i. Call browser_type with ref matching: $selector, text: $value\n"
                    ;;
                check)
                    mcp_instructions+="2.$i. Call browser_click with ref matching checkbox: $selector\n"
                    ;;
                wait)
                    mcp_instructions+="2.$i. Wait for element: $selector\n"
                    ;;
            esac
        done
    fi
    
    # Parse assertions
    if [[ -n "$assertions" && "$assertions" != "null" ]]; then
        mcp_instructions+="3. Call browser_snapshot and verify:\n"
        local assertion_count
        assertion_count=$(echo "$assertions" | jq 'length')
        for ((i=0; i<assertion_count; i++)); do
            local type selector value
            type=$(echo "$assertions" | jq -r ".[$i].type")
            selector=$(echo "$assertions" | jq -r ".[$i].selector // empty")
            value=$(echo "$assertions" | jq -r ".[$i].value // empty")
            
            case "$type" in
                visible)
                    mcp_instructions+="   - Element '$selector' is visible in snapshot\n"
                    ;;
                hidden)
                    mcp_instructions+="   - Element '$selector' is NOT in snapshot\n"
                    ;;
                text_contains)
                    mcp_instructions+="   - Text '$value' appears in page content\n"
                    ;;
                url_contains)
                    mcp_instructions+="   - URL contains '$value'\n"
                    ;;
                screenshot)
                    mcp_instructions+="4. Call browser_take_screenshot for evidence\n"
                    ;;
            esac
        done
    fi
    
    # Return as skipped with instructions (requires agent to execute MCP)
    echo "{\"status\":\"skipped\",\"duration_ms\":0,\"output\":$(echo -e "$mcp_instructions" | jq -Rs .),\"mcp_required\":true}"
}

# ============================================================================
# MAIN VERIFICATION LOGIC
# ============================================================================

# Verify single acceptance criterion
verify_single_ac() {
    local ac_json="$1"
    local quiet="${2:-false}"
    
    local id criterion priority verification_type
    id=$(echo "$ac_json" | jq -r '.id // "AC-?"')
    criterion=$(echo "$ac_json" | jq -r '.criterion // "Unknown criterion"')
    priority=$(echo "$ac_json" | jq -r '.priority // "should"')
    verification_type=$(echo "$ac_json" | jq -r '.verification.type // "unknown"')
    
    [[ "$quiet" != "true" ]] && echo -e "${BLUE}Verifying $id:${NC} $criterion" >&2
    
    local result
    case "$verification_type" in
        command)
            local command
            command=$(echo "$ac_json" | jq -r '.verification.command')
            result=$(verify_command "$command")
            ;;
        file_exists)
            local path
            path=$(echo "$ac_json" | jq -r '.verification.path')
            result=$(verify_file_exists "$path")
            ;;
        file_contains)
            local path pattern
            path=$(echo "$ac_json" | jq -r '.verification.path')
            pattern=$(echo "$ac_json" | jq -r '.verification.pattern')
            result=$(verify_file_contains "$path" "$pattern")
            ;;
        test_passes)
            local test_command
            test_command=$(echo "$ac_json" | jq -r '.verification.test_command')
            result=$(verify_test_passes "$test_command")
            ;;
        playwright)
            local url actions assertions
            url=$(echo "$ac_json" | jq -r '.verification.url')
            actions=$(echo "$ac_json" | jq '.verification.actions // null')
            assertions=$(echo "$ac_json" | jq '.verification.assertions // null')
            result=$(verify_playwright "$url" "$actions" "$assertions")
            ;;
        *)
            result="{\"status\":\"skipped\",\"duration_ms\":0,\"error\":\"Unknown verification type: $verification_type\"}"
            ;;
    esac
    
    # Add AC metadata to result
    local status
    status=$(echo "$result" | jq -r '.status')
    
    if [[ "$quiet" != "true" ]]; then
        case "$status" in
            passed) echo -e "  ${GREEN}✓ PASSED${NC}" >&2 ;;
            failed) echo -e "  ${RED}✗ FAILED${NC}" >&2 ;;
            skipped) echo -e "  ${YELLOW}○ SKIPPED${NC}" >&2 ;;
        esac
    fi
    
    echo "$result" | jq --arg id "$id" --arg criterion "$criterion" --arg priority "$priority" --arg type "$verification_type" \
        '. + {id: $id, criterion: $criterion, priority: $priority, type: $type}'
}

# Verify all ACs in a plan file
verify_plan_acs() {
    local plan_file="$1"
    local target_ac="${2:-}"
    local quiet="${3:-false}"
    local must_only="${4:-false}"
    
    if [[ ! -f "$plan_file" ]]; then
        echo "{\"error\":\"Plan file not found: $plan_file\"}"
        return 1
    fi
    
    local ac_count
    ac_count=$(jq '.acceptance_criteria | length // 0' "$plan_file")
    
    if [[ "$ac_count" -eq 0 ]]; then
        echo "{\"summary\":{\"total\":0,\"passed\":0,\"failed\":0,\"skipped\":0},\"results\":[],\"warning\":\"No acceptance criteria defined in plan\"}"
        return 0
    fi
    
    local results=()
    local passed=0 failed=0 skipped=0
    
    for ((i=0; i<ac_count; i++)); do
        local ac_json ac_id priority
        ac_json=$(jq ".acceptance_criteria[$i]" "$plan_file")
        ac_id=$(echo "$ac_json" | jq -r '.id')
        priority=$(echo "$ac_json" | jq -r '.priority // "should"')
        
        # Filter by target AC if specified
        if [[ -n "$target_ac" && "$ac_id" != "$target_ac" ]]; then
            continue
        fi
        
        # Filter by must-only if specified
        if [[ "$must_only" == "true" && "$priority" != "must" ]]; then
            continue
        fi
        
        local result
        result=$(verify_single_ac "$ac_json" "$quiet")
        results+=("$result")
        
        local status
        status=$(echo "$result" | jq -r '.status')
        case "$status" in
            passed) ((passed++)) ;;
            failed) ((failed++)) ;;
            skipped) ((skipped++)) ;;
        esac
    done
    
    local total=$((passed + failed + skipped))
    
    # Build JSON output
    local results_json="[]"
    for r in "${results[@]}"; do
        results_json=$(echo "$results_json" | jq --argjson r "$r" '. + [$r]')
    done
    
    jq -n \
        --argjson total "$total" \
        --argjson passed "$passed" \
        --argjson failed "$failed" \
        --argjson skipped "$skipped" \
        --argjson results "$results_json" \
        '{
            summary: {total: $total, passed: $passed, failed: $failed, skipped: $skipped},
            results: $results
        }'
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

main() {
    local plan_file=""
    local task_id=""
    local target_ac=""
    local single_json=""
    local quiet="false"
    local must_only="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --plan-file)
                plan_file="$2"
                shift 2
                ;;
            --task-id)
                task_id="$2"
                shift 2
                ;;
            --ac)
                target_ac="$2"
                shift 2
                ;;
            --json)
                single_json="$2"
                shift 2
                ;;
            --quiet)
                quiet="true"
                shift
                ;;
            --must-only)
                must_only="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
    
    # Handle single JSON AC
    if [[ -n "$single_json" ]]; then
        verify_single_ac "$single_json" "$quiet"
        exit 0
    fi
    
    # Resolve plan file from task ID
    if [[ -n "$task_id" ]]; then
        plan_file="$STUDIO_DIR/tasks/$task_id/plan.json"
    fi
    
    # Validate we have a plan file
    if [[ -z "$plan_file" ]]; then
        echo "Error: Must specify --plan-file, --task-id, or --json" >&2
        show_help
        exit 1
    fi
    
    # Run verification
    local result
    result=$(verify_plan_acs "$plan_file" "$target_ac" "$quiet" "$must_only")
    
    echo "$result"
    
    # Exit with error if any must criteria failed
    local must_failed
    must_failed=$(echo "$result" | jq '[.results[] | select(.priority == "must" and .status == "failed")] | length')
    if [[ "$must_failed" -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
