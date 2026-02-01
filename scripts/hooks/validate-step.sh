#!/usr/bin/env bash
#
# STUDIO PostToolUse Step Validator
# ================================
#
# Runs validation_commands from the current plan step after Write/Edit.
# Implements automatic reflexion - if validation fails, provides fix hints.
#
# Exit codes:
#   0 - Allow (validation passed or no active task)
#   2 - Block (validation failed, triggers retry behavior)
#

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
TASKS_DIR="${STUDIO_DIR}/tasks"

# Read hook input from stdin
INPUT=$(cat)

# Extract info
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // empty')

# Find active task
find_active_task() {
    if [[ ! -d "$TASKS_DIR" ]]; then
        return 1
    fi

    local task_dir
    for task_dir in "$TASKS_DIR"/task_*/; do
        if [[ -d "$task_dir" ]]; then
            local state_file="${task_dir}state.json"
            if [[ -f "$state_file" ]]; then
                local status
                status=$(jq -r '.status // empty' "$state_file" 2>/dev/null)
                if [[ "$status" == "BUILDING" || "$status" == "in_progress" || "$status" == "BUILDING" ]]; then
                    echo "${task_dir%/}"
                    return 0
                fi
            fi
        fi
    done

    return 1
}

main() {
    # Find active task
    local task_dir
    if ! task_dir=$(find_active_task); then
        # No active task, allow
        exit 0
    fi

    local plan_file="${task_dir}/plan.json"
    local state_file="${task_dir}/state.json"

    # If no plan, allow
    if [[ ! -f "$plan_file" ]]; then
        exit 0
    fi

    # Get current step
    local current_step
    current_step=$(jq -r '.current_step // empty' "$state_file" 2>/dev/null)

    if [[ -z "$current_step" || "$current_step" == "null" ]]; then
        # No current step, allow
        exit 0
    fi

    # Get validation commands for current step
    local validations
    validations=$(jq -c ".steps[] | select(.id == \"$current_step\") | .success_criteria[]?" "$plan_file" 2>/dev/null)

    if [[ -z "$validations" ]]; then
        # No validations defined, allow
        exit 0
    fi

    # Track failures
    local failed=0
    local failed_criterion=""
    local failed_expected=""
    local failed_actual=""

    # Run each validation
    while IFS= read -r validation; do
        if [[ -z "$validation" ]]; then
            continue
        fi

        local cmd
        local expected
        local criterion

        cmd=$(echo "$validation" | jq -r '.validation_command // empty')
        expected=$(echo "$validation" | jq -r '.expected_output // empty')
        criterion=$(echo "$validation" | jq -r '.criterion // empty')

        if [[ -z "$cmd" ]]; then
            continue
        fi

        # Execute validation command
        local result
        result=$(eval "$cmd" 2>&1 || true)

        # Check if result matches expected
        if [[ -n "$expected" && "$result" != *"$expected"* ]]; then
            failed=1
            failed_criterion="$criterion"
            failed_expected="$expected"
            failed_actual="$result"
            break
        fi
    done <<< "$validations"

    if [[ $failed -eq 1 ]]; then
        # Get retry behavior
        local max_attempts
        local fix_hints
        local escalation
        local current_attempts

        max_attempts=$(jq -r ".steps[] | select(.id == \"$current_step\") | .retry_behavior.max_attempts // 3" "$plan_file" 2>/dev/null)
        fix_hints=$(jq -r ".steps[] | select(.id == \"$current_step\") | .retry_behavior.fix_hints | join(\"; \") // \"Check the error and try again\"" "$plan_file" 2>/dev/null)
        escalation=$(jq -r ".steps[] | select(.id == \"$current_step\") | .retry_behavior.escalation // \"halt_with_context\"" "$plan_file" 2>/dev/null)

        # Get current attempts from state (default 1)
        current_attempts=$(jq -r ".steps.\"$current_step\".attempts // 1" "$state_file" 2>/dev/null)

        if [[ $current_attempts -lt $max_attempts ]]; then
            # Trigger retry with fix hints
            local new_attempts=$((current_attempts + 1))

            # Update state with new attempt count
            local tmp_state
            tmp_state=$(mktemp)
            jq ".steps.\"$current_step\".attempts = $new_attempts" "$state_file" > "$tmp_state" && mv "$tmp_state" "$state_file"

            # Return block with retry guidance
            cat << EOF
{
  "decision": "block",
  "reason": "Step validation failed: $failed_criterion. Attempt $new_attempts/$max_attempts.",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "VALIDATION FAILED\\n\\nCriterion: $failed_criterion\\nExpected: $failed_expected\\nActual: $failed_actual\\n\\nFix hints: $fix_hints\\n\\nApply the fix hints and retry the step. Attempt $new_attempts of $max_attempts."
  }
}
EOF
            exit 0
        else
            # Max attempts reached, escalate
            if [[ "$escalation" == "skip_if_optional" ]]; then
                # Mark as skipped and allow
                local tmp_state
                tmp_state=$(mktemp)
                jq ".steps.\"$current_step\".status = \"skipped\"" "$state_file" > "$tmp_state" && mv "$tmp_state" "$state_file"
                exit 0
            else
                # Halt with context
                cat << EOF
{
  "decision": "block",
  "reason": "Step validation failed after $max_attempts attempts. Task halted.",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "TASK HALTED\\n\\nStep: $current_step\\nCriterion: $failed_criterion\\nExpected: $failed_expected\\nActual: $failed_actual\\nAttempts: $max_attempts/$max_attempts (exhausted)\\nFix hints tried: $fix_hints\\n\\nManual intervention required. Review the failure and either fix the issue manually or modify the plan."
  }
}
EOF
                exit 0
            fi
        fi
    fi

    # All validations passed
    exit 0
}

main "$@"
