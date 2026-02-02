#!/usr/bin/env bash
# =============================================================================
# SICVF Task Validation Script
# =============================================================================
# Validates tasks against SICVF atomic task criteria:
# - Single-pass: Completable in one session (< 8 hours, < 15 micro-actions)
# - Independent: No concurrent dependencies (depends_on items all COMPLETE)
# - Clear boundaries: Explicit inputs/outputs (No UNDEFINED sources)
# - Verifiable: Executable success criteria (All criteria have commands)
# - Fits context: Within token budget (< 80K tokens)
#
# Usage:
#   ./sicvf-validate.sh <task_json_file>
#   ./sicvf-validate.sh --task-id <task_id>
#   ./sicvf-validate.sh --all  # Validate all pending tasks
#
# Output:
#   JSON object with validation results for each criterion
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_ROOT="${SCRIPT_DIR}/.."

# Source output utilities if available
if [[ -f "${SCRIPT_DIR}/output.sh" ]]; then
    # shellcheck source=./output.sh
    source "${SCRIPT_DIR}/output.sh"
fi

# =============================================================================
# Configuration
# =============================================================================

MAX_HOURS=8
MAX_MICRO_ACTIONS=15
MAX_TOKENS=80000
BACKLOG_FILE=".studio/backlog.json"

# =============================================================================
# Helper Functions
# =============================================================================

json_get() {
    local json="$1"
    local path="$2"
    echo "$json" | jq -r "$path // empty"
}

json_get_array_length() {
    local json="$1"
    local path="$2"
    echo "$json" | jq -r "$path | length // 0"
}

estimate_tokens() {
    local text="$1"
    # Rough estimate: ~4 characters per token
    local chars=${#text}
    echo $(( chars / 4 ))
}

# =============================================================================
# SICVF Validation Functions
# =============================================================================

validate_single_pass() {
    local task_json="$1"
    local result="{}"
    local passes=true
    local violation_reason=""

    # Get effort estimates
    local size
    size=$(json_get "$task_json" '.effort.size // "M"')
    local estimated_hours
    estimated_hours=$(json_get "$task_json" '.effort.estimated_hours // 4')
    local estimated_actions
    estimated_actions=$(json_get "$task_json" '.effort.estimated_micro_actions // 10')

    # Map size to hours if not specified
    if [[ -z "$estimated_hours" || "$estimated_hours" == "null" ]]; then
        case "$size" in
            XS) estimated_hours=1 ;;
            S)  estimated_hours=2 ;;
            M)  estimated_hours=4 ;;
            L)  estimated_hours=6 ;;
            XL) estimated_hours=10 ;;
            *)  estimated_hours=4 ;;
        esac
    fi

    # Map size to micro-actions if not specified
    if [[ -z "$estimated_actions" || "$estimated_actions" == "null" ]]; then
        case "$size" in
            XS) estimated_actions=3 ;;
            S)  estimated_actions=6 ;;
            M)  estimated_actions=10 ;;
            L)  estimated_actions=12 ;;
            XL) estimated_actions=20 ;;
            *)  estimated_actions=10 ;;
        esac
    fi

    # Validate thresholds
    if (( $(echo "$estimated_hours > $MAX_HOURS" | bc -l) )); then
        passes=false
        violation_reason="Estimated ${estimated_hours} hours exceeds ${MAX_HOURS} hour limit"
    fi

    if (( estimated_actions > MAX_MICRO_ACTIONS )); then
        passes=false
        if [[ -n "$violation_reason" ]]; then
            violation_reason="$violation_reason; "
        fi
        violation_reason="${violation_reason}Estimated ${estimated_actions} micro-actions exceeds ${MAX_MICRO_ACTIONS} limit"
    fi

    # Build result
    result=$(jq -n \
        --argjson passes "$passes" \
        --argjson hours "$estimated_hours" \
        --argjson actions "$estimated_actions" \
        --arg reason "$violation_reason" \
        '{
            passes: $passes,
            estimated_hours: $hours,
            estimated_micro_actions: $actions,
            violation_reason: (if $reason == "" then null else $reason end)
        }')

    echo "$result"
}

validate_independent() {
    local task_json="$1"
    local backlog_json="${2:-}"
    local result="{}"
    local passes=true
    local violation_reason=""
    local concurrent_deps="[]"

    # Get dependencies
    local depends_on
    depends_on=$(json_get "$task_json" '.depends_on // []')
    local dep_count
    dep_count=$(echo "$depends_on" | jq 'length')

    if [[ "$dep_count" -gt 0 && -n "$backlog_json" ]]; then
        # Check status of each dependency
        local incomplete_deps="[]"

        while IFS= read -r dep_id; do
            [[ -z "$dep_id" ]] && continue

            # Find task in backlog and check status
            local dep_status
            dep_status=$(echo "$backlog_json" | jq -r --arg id "$dep_id" '
                .epics[].features[].tasks[]
                | select(.id == $id or .short_id == $id)
                | .status // "UNKNOWN"
            ' | head -1)

            if [[ "$dep_status" != "COMPLETE" ]]; then
                incomplete_deps=$(echo "$incomplete_deps" | jq --arg id "$dep_id" '. + [$id]')
                passes=false
            fi
        done < <(echo "$depends_on" | jq -r '.[]')

        concurrent_deps="$incomplete_deps"

        if [[ "$passes" == "false" ]]; then
            local count
            count=$(echo "$concurrent_deps" | jq 'length')
            violation_reason="$count dependencies not yet COMPLETE"
        fi
    fi

    result=$(jq -n \
        --argjson passes "$passes" \
        --argjson deps "$concurrent_deps" \
        --arg reason "$violation_reason" \
        '{
            passes: $passes,
            concurrent_dependencies: $deps,
            violation_reason: (if $reason == "" then null else $reason end)
        }')

    echo "$result"
}

validate_clear_boundaries() {
    local task_json="$1"
    local result="{}"
    local passes=true
    local violation_reason=""
    local undefined_sources="[]"

    # Check inputs
    local inputs
    inputs=$(json_get "$task_json" '.inputs // []')
    local inputs_defined=true
    local input_count
    input_count=$(echo "$inputs" | jq 'length')

    if [[ "$input_count" -eq 0 ]]; then
        # Check if task description mentions inputs without explicit definition
        local description
        description=$(json_get "$task_json" '.description // ""')
        if echo "$description" | grep -qiE "from|using|with|based on"; then
            inputs_defined=false
            undefined_sources=$(echo "$undefined_sources" | jq '. + ["inputs not explicitly defined"]')
        fi
    fi

    # Check for undefined or TBD in inputs
    while IFS= read -r input; do
        [[ -z "$input" ]] && continue
        if echo "$input" | grep -qiE "undefined|tbd|todo|unknown|\?"; then
            inputs_defined=false
            undefined_sources=$(echo "$undefined_sources" | jq --arg src "$input" '. + [$src]')
        fi
    done < <(echo "$inputs" | jq -r '.[]')

    # Check outputs
    local outputs
    outputs=$(json_get "$task_json" '.outputs // []')
    local outputs_defined=true
    local output_count
    output_count=$(echo "$outputs" | jq 'length')

    if [[ "$output_count" -eq 0 ]]; then
        local description
        description=$(json_get "$task_json" '.description // ""')
        if [[ -n "$description" ]]; then
            outputs_defined=false
            undefined_sources=$(echo "$undefined_sources" | jq '. + ["outputs not explicitly defined"]')
        fi
    fi

    # Check for undefined or TBD in outputs
    while IFS= read -r output; do
        [[ -z "$output" ]] && continue
        if echo "$output" | grep -qiE "undefined|tbd|todo|unknown|\?"; then
            outputs_defined=false
            undefined_sources=$(echo "$undefined_sources" | jq --arg src "$output" '. + [$src]')
        fi
    done < <(echo "$outputs" | jq -r '.[]')

    # Determine overall pass
    if [[ "$inputs_defined" == "false" || "$outputs_defined" == "false" ]]; then
        passes=false
        violation_reason="Inputs or outputs not clearly defined"
    fi

    result=$(jq -n \
        --argjson passes "$passes" \
        --argjson inputs_def "$inputs_defined" \
        --argjson outputs_def "$outputs_defined" \
        --argjson undefined "$undefined_sources" \
        --arg reason "$violation_reason" \
        '{
            passes: $passes,
            inputs_defined: $inputs_def,
            outputs_defined: $outputs_def,
            undefined_sources: $undefined,
            violation_reason: (if $reason == "" then null else $reason end)
        }')

    echo "$result"
}

validate_verifiable() {
    local task_json="$1"
    local result="{}"
    local passes=true
    local violation_reason=""
    local non_executable="[]"

    # Get acceptance criteria or success criteria
    local criteria
    criteria=$(json_get "$task_json" '.acceptance_criteria // .success_criteria // []')
    local criteria_count
    criteria_count=$(echo "$criteria" | jq 'length')
    local executable_count=0

    while IFS= read -r criterion; do
        [[ -z "$criterion" || "$criterion" == "null" ]] && continue

        # Check if criterion has verification method
        local has_verification
        has_verification=$(echo "$criterion" | jq 'has("verification") and .verification != null')

        if [[ "$has_verification" == "true" ]]; then
            local ver_type
            ver_type=$(echo "$criterion" | jq -r '.verification.type // empty')

            # Check if verification is executable (has command or specific check)
            case "$ver_type" in
                command|test_passes|file_exists|file_contains|playwright)
                    (( executable_count++ ))
                    ;;
                manual)
                    # Manual is acceptable but warn
                    (( executable_count++ ))
                    ;;
                *)
                    local id
                    id=$(echo "$criterion" | jq -r '.id // "unknown"')
                    non_executable=$(echo "$non_executable" | jq --arg id "$id" '. + [$id + ": no verification type"]')
                    ;;
            esac
        else
            local id
            id=$(echo "$criterion" | jq -r '.id // .criterion // "unknown"')
            non_executable=$(echo "$non_executable" | jq --arg id "$id" '. + [$id + ": no verification"]')
        fi
    done < <(echo "$criteria" | jq -c '.[]')

    # Check if all criteria are executable
    local non_exec_count
    non_exec_count=$(echo "$non_executable" | jq 'length')

    if [[ "$non_exec_count" -gt 0 ]]; then
        passes=false
        violation_reason="$non_exec_count criteria lack executable verification"
    fi

    result=$(jq -n \
        --argjson passes "$passes" \
        --argjson total "$criteria_count" \
        --argjson executable "$executable_count" \
        --argjson non_exec "$non_executable" \
        --arg reason "$violation_reason" \
        '{
            passes: $passes,
            criteria_count: $total,
            executable_criteria_count: $executable,
            non_executable_criteria: $non_exec,
            violation_reason: (if $reason == "" then null else $reason end)
        }')

    echo "$result"
}

validate_fits_context() {
    local task_json="$1"
    local result="{}"
    local passes=true
    local violation_reason=""

    # Estimate token usage for the task
    local task_text
    task_text=$(echo "$task_json" | jq -r 'tostring')
    local estimated_tokens
    estimated_tokens=$(estimate_tokens "$task_text")

    # Add buffer for context (invariants, learnings, adjacent tasks)
    # Rough estimate: task content + ~30K context overhead
    local context_overhead=30000
    local total_estimated=$(( estimated_tokens + context_overhead ))

    if [[ "$total_estimated" -gt "$MAX_TOKENS" ]]; then
        passes=false
        violation_reason="Estimated ${total_estimated} tokens exceeds ${MAX_TOKENS} token budget"
    fi

    result=$(jq -n \
        --argjson passes "$passes" \
        --argjson tokens "$estimated_tokens" \
        --argjson budget "$MAX_TOKENS" \
        --arg reason "$violation_reason" \
        '{
            passes: $passes,
            estimated_tokens: $tokens,
            token_budget: $budget,
            violation_reason: (if $reason == "" then null else $reason end)
        }')

    echo "$result"
}

# =============================================================================
# Main Validation Function
# =============================================================================

validate_task() {
    local task_json="$1"
    local backlog_json="${2:-}"

    # Run all validations
    local single_pass
    single_pass=$(validate_single_pass "$task_json")

    local independent
    independent=$(validate_independent "$task_json" "$backlog_json")

    local clear_boundaries
    clear_boundaries=$(validate_clear_boundaries "$task_json")

    local verifiable
    verifiable=$(validate_verifiable "$task_json")

    local fits_context
    fits_context=$(validate_fits_context "$task_json")

    # Determine overall pass
    local all_pass=true
    for check in "$single_pass" "$independent" "$clear_boundaries" "$verifiable" "$fits_context"; do
        local check_passes
        check_passes=$(echo "$check" | jq -r '.passes')
        if [[ "$check_passes" != "true" ]]; then
            all_pass=false
            break
        fi
    done

    # Build full result
    local task_id
    task_id=$(json_get "$task_json" '.id // "unknown"')

    local result
    result=$(jq -n \
        --arg id "$task_id" \
        --argjson single_pass "$single_pass" \
        --argjson independent "$independent" \
        --argjson clear "$clear_boundaries" \
        --argjson verifiable "$verifiable" \
        --argjson fits "$fits_context" \
        --argjson passes "$all_pass" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            task_id: $id,
            single_pass: $single_pass,
            independent: $independent,
            clear_boundaries: $clear,
            verifiable: $verifiable,
            fits_context: $fits,
            passes: $passes,
            validation_timestamp: $timestamp
        }')

    echo "$result"
}

# =============================================================================
# CLI Interface
# =============================================================================

usage() {
    cat << EOF
SICVF Task Validation Script

Usage:
    $(basename "$0") <task_json_file>        Validate task from JSON file
    $(basename "$0") --task-id <task_id>     Validate task from backlog by ID
    $(basename "$0") --all                   Validate all pending tasks
    $(basename "$0") --help                  Show this help message

SICVF Criteria:
    S - Single-pass:     < ${MAX_HOURS} hours, < ${MAX_MICRO_ACTIONS} micro-actions
    I - Independent:     No concurrent dependencies
    C - Clear boundaries: Explicit inputs/outputs
    V - Verifiable:      Executable success criteria
    F - Fits context:    < ${MAX_TOKENS} tokens

Exit Codes:
    0 - All validations passed
    1 - One or more validations failed
    2 - Error in execution
EOF
}

main() {
    local task_json=""
    local backlog_json=""
    local validate_all=false
    local task_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                usage
                exit 0
                ;;
            --all)
                validate_all=true
                shift
                ;;
            --task-id)
                task_id="$2"
                shift 2
                ;;
            *)
                if [[ -f "$1" ]]; then
                    task_json=$(cat "$1")
                else
                    echo "Error: File not found: $1" >&2
                    exit 2
                fi
                shift
                ;;
        esac
    done

    # Load backlog if exists
    if [[ -f "$BACKLOG_FILE" ]]; then
        backlog_json=$(cat "$BACKLOG_FILE")
    fi

    # Handle --all
    if [[ "$validate_all" == "true" ]]; then
        if [[ -z "$backlog_json" ]]; then
            echo "Error: No backlog found at $BACKLOG_FILE" >&2
            exit 2
        fi

        local results="[]"
        local any_failed=false

        while IFS= read -r task; do
            [[ -z "$task" || "$task" == "null" ]] && continue

            local result
            result=$(validate_task "$task" "$backlog_json")
            results=$(echo "$results" | jq --argjson r "$result" '. + [$r]')

            local passes
            passes=$(echo "$result" | jq -r '.passes')
            if [[ "$passes" != "true" ]]; then
                any_failed=true
            fi
        done < <(echo "$backlog_json" | jq -c '.epics[].features[].tasks[] | select(.status == "PENDING")')

        echo "$results" | jq '.'

        if [[ "$any_failed" == "true" ]]; then
            exit 1
        fi
        exit 0
    fi

    # Handle --task-id
    if [[ -n "$task_id" ]]; then
        if [[ -z "$backlog_json" ]]; then
            echo "Error: No backlog found at $BACKLOG_FILE" >&2
            exit 2
        fi

        task_json=$(echo "$backlog_json" | jq -c --arg id "$task_id" '
            .epics[].features[].tasks[]
            | select(.id == $id or .short_id == $id)
        ' | head -1)

        if [[ -z "$task_json" || "$task_json" == "null" ]]; then
            echo "Error: Task not found: $task_id" >&2
            exit 2
        fi
    fi

    # Validate provided task
    if [[ -n "$task_json" ]]; then
        local result
        result=$(validate_task "$task_json" "$backlog_json")
        echo "$result" | jq '.'

        local passes
        passes=$(echo "$result" | jq -r '.passes')
        if [[ "$passes" != "true" ]]; then
            exit 1
        fi
        exit 0
    fi

    # No input provided
    usage
    exit 2
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
