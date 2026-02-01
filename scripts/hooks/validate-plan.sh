#!/usr/bin/env bash
#
# STUDIO Blueprint Validator
# =========================
#
# Validates that the Architect agent has produced a complete,
# CAST-READY blueprint before allowing it to stop.
#
# Exit codes:
#   0 - Approved (blueprint is complete and valid)
#   Returns JSON with decision:block if invalid
#

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
CASTS_DIR="${STUDIO_DIR}/casts"

# Find active cast
find_active_cast() {
    if [[ ! -d "$CASTS_DIR" ]]; then
        return 1
    fi

    local cast_dir
    for cast_dir in "$CASTS_DIR"/cast_*/; do
        if [[ -d "$cast_dir" ]]; then
            local state_file="${cast_dir}state.json"
            if [[ -f "$state_file" ]]; then
                local status
                status=$(jq -r '.status // empty' "$state_file" 2>/dev/null)
                if [[ "$status" == "READY_TO_CAST" || "$status" == "BLUEPRINTING" ]]; then
                    echo "${cast_dir%/}"
                    return 0
                fi
            fi
        fi
    done

    return 1
}

validate_blueprint() {
    local blueprint_file="$1"
    local errors=()

    # Check required top-level fields
    local has_id has_cast_id has_goal has_steps

    has_id=$(jq -r '.id // empty' "$blueprint_file" 2>/dev/null)
    has_cast_id=$(jq -r '.cast_id // empty' "$blueprint_file" 2>/dev/null)
    has_goal=$(jq -r '.goal // empty' "$blueprint_file" 2>/dev/null)
    has_steps=$(jq -r '.steps | length' "$blueprint_file" 2>/dev/null)

    if [[ -z "$has_id" ]]; then
        errors+=("Missing blueprint id")
    fi

    if [[ -z "$has_cast_id" ]]; then
        errors+=("Missing cast_id")
    fi

    if [[ -z "$has_goal" ]]; then
        errors+=("Missing goal")
    fi

    if [[ "$has_steps" == "0" || -z "$has_steps" ]]; then
        errors+=("No steps defined")
    fi

    # Check embedded_context (CAST-READY requirement)
    local has_embedded_context
    has_embedded_context=$(jq -r '.embedded_context // empty' "$blueprint_file" 2>/dev/null)

    if [[ -z "$has_embedded_context" || "$has_embedded_context" == "null" ]]; then
        errors+=("Missing embedded_context - blueprint not CAST-READY")
    fi

    # Check each step has required fields
    local step_count
    step_count=$(jq -r '.steps | length' "$blueprint_file" 2>/dev/null)

    for ((i=0; i<step_count; i++)); do
        local step_id
        local has_action
        local has_success_criteria

        step_id=$(jq -r ".steps[$i].id // empty" "$blueprint_file" 2>/dev/null)
        has_action=$(jq -r ".steps[$i].action // empty" "$blueprint_file" 2>/dev/null)
        has_success_criteria=$(jq -r ".steps[$i].success_criteria | length" "$blueprint_file" 2>/dev/null)

        if [[ -z "$step_id" ]]; then
            errors+=("Step $i missing id")
        fi

        if [[ -z "$has_action" || "$has_action" == "null" ]]; then
            errors+=("Step $step_id missing action")
        fi

        if [[ "$has_success_criteria" == "0" || -z "$has_success_criteria" ]]; then
            errors+=("Step $step_id has no success_criteria - not self-validating")
        fi

        # Check success_criteria have validation_commands
        local criteria_count
        criteria_count=$(jq -r ".steps[$i].success_criteria | length" "$blueprint_file" 2>/dev/null)

        for ((j=0; j<criteria_count; j++)); do
            local has_validation_cmd
            has_validation_cmd=$(jq -r ".steps[$i].success_criteria[$j].validation_command // empty" "$blueprint_file" 2>/dev/null)

            if [[ -z "$has_validation_cmd" ]]; then
                errors+=("Step $step_id criterion $j missing validation_command - not executable")
            fi
        done

        # Check retry_behavior exists
        local has_retry
        has_retry=$(jq -r ".steps[$i].retry_behavior // empty" "$blueprint_file" 2>/dev/null)

        if [[ -z "$has_retry" || "$has_retry" == "null" ]]; then
            errors+=("Step $step_id missing retry_behavior")
        fi
    done

    # Check validation_hooks exist (CAST-READY requirement)
    local has_quality_gate
    has_quality_gate=$(jq -r '.validation_hooks.quality_gate // empty' "$blueprint_file" 2>/dev/null)

    if [[ -z "$has_quality_gate" || "$has_quality_gate" == "null" ]]; then
        errors+=("Missing validation_hooks.quality_gate - no quality assurance defined")
    fi

    # Return errors if any
    if [[ ${#errors[@]} -gt 0 ]]; then
        local error_list
        error_list=$(printf '%s\\n' "${errors[@]}")
        echo "$error_list"
        return 1
    fi

    return 0
}

main() {
    # Find active cast
    local cast_dir
    if ! cast_dir=$(find_active_cast); then
        # No active cast, allow
        exit 0
    fi

    local blueprint_file="${cast_dir}/blueprint.json"

    # Check if blueprint.json exists
    if [[ ! -f "$blueprint_file" ]]; then
        cat << EOF
{
  "decision": "block",
  "reason": "Blueprint JSON not written: blueprint.json is missing. The Architect must write the blueprint to studio/casts/[cast_id]/blueprint.json before stopping."
}
EOF
        exit 0
    fi

    # Validate blueprint
    local validation_errors
    if ! validation_errors=$(validate_blueprint "$blueprint_file"); then
        cat << EOF
{
  "decision": "block",
  "reason": "Blueprint validation failed. The blueprint is not CAST-READY.",
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": "BLUEPRINT VALIDATION ERRORS:\\n\\n$validation_errors\\n\\nFix these issues before the blueprint can be approved."
  }
}
EOF
        exit 0
    fi

    # Blueprint is valid
    exit 0
}

main "$@"
